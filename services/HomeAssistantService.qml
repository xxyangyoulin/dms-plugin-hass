pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property string pluginId: "homeAssistantMonitor"

    property bool haAvailable: false
    property string hassUrl: ""
    property string hassToken: ""
    property string entityIds: ""
    property int refreshInterval: 3
    property bool showAttributes: false

    property var historyCache: ({})
    readonly property int historyCacheDuration: 300000  // 5 minutes

    function loadSettings() {
        const load = (key, defaultValue) => {
            const val = PluginService.loadPluginData(pluginId, key);
            return val !== undefined ? val : defaultValue;
        }

        hassUrl = load("hassUrl", "");
        hassToken = load("hassToken", "");
        entityIds = load("entityIds", "");
        refreshInterval = load("refreshInterval", 3);
        showAttributes = load("showAttributes", false);

        refresh();
    }

    Component.onCompleted: {
        loadSettings();
        initialize();
    }

    Connections {
        target: PluginService

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) {
                loadSettings();
            }
        }
    }

    property var delayedRefreshTimer: Timer {
        interval: 500
        running: false
        repeat: false
        onTriggered: refresh()
    }

    property var refreshTimer: Timer {
        interval: root.refreshInterval * 1000
        running: false
        repeat: true
        onTriggered: fetchEntities()
    }

    onRefreshIntervalChanged: {
        refreshTimer.interval = refreshInterval * 1000;
        if (refreshTimer.running) {
            refreshTimer.restart();
        }
    }

    function initialize() {
        refresh();
        refreshTimer.start();
    }

    function refresh() {
        fetchEntities();
    }

    function makeRequest(method, endpoint, data, callback, retryCount = 0) {
        if (!hassUrl || !hassToken) {
            console.warn("HomeAssistantMonitor: Missing URL or Token");
            if (callback) callback(null, -1);
            return;
        }

        const maxRetries = 2;
        const curlCmd = [
            "curl", "-s", "-X", method,
            "-H", `Authorization: Bearer ${hassToken}`,
            "-H", "Content-Type: application/json",
            "--connect-timeout", "10",
            "--max-time", "30"
        ];

        if (data) {
            curlCmd.push("-d", JSON.stringify(data));
        }

        curlCmd.push(`${hassUrl}${endpoint}`);

        const requestId = `${pluginId}.${method}.${endpoint.replace(/\//g, "_")}`;

        Proc.runCommand(requestId, curlCmd, (stdout, exitCode) => {
            if (exitCode === 0) {
                if (callback) callback(stdout, exitCode);
            } else {
                console.error("HomeAssistantMonitor: Request failed, exit code:", exitCode);

                // Retry logic
                if (retryCount < maxRetries) {
                    console.log(`HomeAssistantMonitor: Retrying... (${retryCount + 1}/${maxRetries})`);
                    Qt.callLater(() => {
                        makeRequest(method, endpoint, data, callback, retryCount + 1);
                    });
                } else {
                    if (callback) callback(null, exitCode);
                }
            }
        }, 100);
    }

    function mapEntity(entity) {
        if (!entity) return null;

        const attrs = entity.attributes || {};
        const entityId = entity.entity_id || "";

        return {
            entityId: entityId,
            state: entity.state || "",
            friendlyName: attrs.friendly_name || entityId,
            unitOfMeasurement: attrs.unit_of_measurement || "",
            icon: attrs.icon || "sensors",
            attributes: attrs,
            lastChanged: entity.last_changed || "",
            lastUpdated: entity.last_updated || "",
            domain: entityId.split('.')[0] || ""
        };
    }

    function fetchHistory(entityId, callback) {
        if (!hassUrl || !hassToken) return;

        // Check cache
        const now = Date.now();
        const cache = historyCache[entityId];

        if (cache && (now - cache.timestamp) < historyCacheDuration) {
            console.log("HomeAssistantMonitor: Using cached history for", entityId);
            if (callback) callback(cache.data);
            return;
        }

        const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
        const endpoint = `/api/history/period/${yesterday}?filter_entity_id=${entityId}&minimal_response`;

        makeRequest("GET", endpoint, null, (stdout, exitCode) => {
            if (exitCode === 0 && stdout) {
                try {
                    const data = JSON.parse(stdout);
                    if (data && data.length > 0) {
                        const history = data[0]
                            .map(item => ({
                                value: parseFloat(item.state),
                                time: new Date(item.last_changed)
                            }))
                            .filter(item => !isNaN(item.value));

                        // Save to cache
                        const cacheEntry = { data: history, timestamp: now };
                        historyCache = Object.assign({}, historyCache, {
                            [entityId]: cacheEntry
                        });
                        if (callback) callback(history);
                    }
                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to parse history:", e);
                    if (callback) callback([]);
                }
            } else {
                if (callback) callback([]);
            }
        });
    }

    function parseEntityIds() {
        if (!entityIds || entityIds.trim() === "") {
            return [];
        }
        return entityIds.split(/[,\n]/)
            .map(id => id.trim())
            .filter(id => id.length > 0);
    }

    function fetchEntities() {
        const parsedEntityIds = parseEntityIds();

        if (!hassUrl || !hassToken) {
            updateEntities([]);
            haAvailable = false;
            return;
        }

        makeRequest("GET", "/api/states", null, (stdout, exitCode) => {
            if (exitCode === 0 && stdout) {
                try {
                    const allStates = JSON.parse(stdout);

                    // Use Set for optimized lookup performance O(1)
                    const monitoredIdSet = new Set(parsedEntityIds);

                    // Single iteration, process all entities and monitored entities
                    const allEntities = [];
                    const monitoredEntities = [];

                    for (const entity of allStates) {
                        const mapped = mapEntity(entity);
                        if (mapped) {
                            allEntities.push(mapped);
                            if (monitoredIdSet.has(mapped.entityId)) {
                                monitoredEntities.push(mapped);
                            }
                        }
                    }

                    PluginService.setGlobalVar(pluginId, "allEntities", allEntities);
                    updateEntities(monitoredEntities);
                    haAvailable = true;

                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to parse HA response:", e);
                    updateEntities([]);
                    haAvailable = false;
                }
            } else {
                console.error("HomeAssistantMonitor: Failed to fetch entities");
                // Keep old data, don't clear
                haAvailable = false;
            }
        });
    }

    function updateEntities(entities = []) {
        PluginService.setGlobalVar(pluginId, "entities", entities);
        PluginService.setGlobalVar(pluginId, "entityCount", entities.length);
        PluginService.setGlobalVar(pluginId, "haAvailable", haAvailable);
    }

    function addEntityToMonitor(entityId) {
        let ids = parseEntityIds();
        if (!ids.includes(entityId)) {
            ids.push(entityId);
            entityIds = ids.join(", ");
            PluginService.savePluginData(pluginId, "entityIds", entityIds);
            console.log("HomeAssistantMonitor: Added entity", entityId);
            refresh();
        }
    }

    function removeEntityFromMonitor(entityId) {
        let ids = parseEntityIds();
        const index = ids.indexOf(entityId);
        if (index >= 0) {
            ids.splice(index, 1);
            entityIds = ids.join(", ");
            PluginService.savePluginData(pluginId, "entityIds", entityIds);
            console.log("HomeAssistantMonitor: Removed entity", entityId);

            // Clear history cache for this entity
            const newCache = Object.assign({}, historyCache);
            delete newCache[entityId];
            historyCache = newCache;

            refresh();
        }
    }

    function callService(domain, service, entityId, serviceData) {
        if (!hassUrl || !hassToken) {
            console.error("HomeAssistantMonitor: Cannot call service - HA not configured");
            return;
        }

        const endpoint = `/api/services/${domain}/${service}`;
        const data = serviceData || {};
        data.entity_id = entityId;

        makeRequest("POST", endpoint, data, (stdout, exitCode) => {
            if (exitCode === 0) {
                delayedRefreshTimer.restart();
            } else {
                console.error("HomeAssistantMonitor: Service call failed");
            }
        });
    }

    function fetchDeviceIcon(device) {
        if (!device)
            return "smartphone";

        switch (device.type) {
        case "light":
            return "lightbulb";
        case "switch":
            return "toggle_on";
        default:
            return "sensors";
        }
    }

    function getDeviceIcon(domain) {
        switch (domain) {
        case "light":
            return "lightbulb";
        case "switch":
            return "toggle_on";
        case "sensor":
            return "sensors";
        case "binary_sensor":
            return "motion_sensor_active";
        case "climate":
            return "thermostat";
        case "cover":
            return "roller_shades";
        case "fan":
            return "mode_fan";
        case "lock":
            return "lock";
        case "media_player":
            return "play_circle";
        default:
            return "sensors";
        }
    }

    function toggleEntity(entityId, domain, currentState) {
        let service = "toggle";

        switch (domain) {
        case "cover":
            service = currentState === "open" ? "close_cover" : "open_cover";
            break;
        case "lock":
            service = currentState === "locked" ? "unlock" : "lock";
            break;
        default:
            break;
        }

        callService(domain, service, entityId, {});
    }

    function setBrightness(entityId, brightness) {
        callService("light", "turn_on", entityId, {brightness: Math.round(brightness)});
    }

    function setColorTemp(entityId, colorTempMireds) {
        callService("light", "turn_on", entityId, {color_temp: Math.round(colorTempMireds)});
    }

    function setLightEffect(entityId, effect) {
        callService("light", "turn_on", entityId, {effect: effect});
    }

    function setTemperature(entityId, temperature) {
        callService("climate", "set_temperature", entityId, {
            temperature: parseFloat(temperature.toFixed(1))
        });
    }

    function setHvacMode(entityId, mode) {
        callService("climate", "set_hvac_mode", entityId, {hvac_mode: mode});
    }

    function setPresetMode(entityId, preset) {
        callService("climate", "set_preset_mode", entityId, {preset_mode: preset});
    }

    function setFanSpeed(entityId, percentage) {
        callService("fan", "set_percentage", entityId, {percentage: Math.round(percentage)});
    }

    function setCoverPosition(entityId, position) {
        callService("cover", "set_cover_position", entityId, {position: Math.round(position)});
    }

    function triggerScript(entityId) {
        const domain = entityId.split('.')[0];
        const service = (domain === "script" || domain === "automation") ? "trigger" : "turn_on";
        callService(domain, service, entityId, {});
    }

    function activateScene(entityId) {
        callService("scene", "turn_on", entityId, {});
    }

    function setNumberValue(entityId, value) {
        const domain = entityId.split('.')[0];
        callService(domain, "set_value", entityId, {value: value});
    }

    function selectOption(entityId, domain, option) {
        callService(domain, "select_option", entityId, {option: option});
    }

    function setOption(entityId, domain, attrName, option) {
        let service = "select_option";
        let data = {};

        switch (attrName) {
        case "hvac_modes":
            service = "set_hvac_mode";
            data = { hvac_mode: option };
            break;
        case "preset_modes":
        case "preset_mode":
            service = "set_preset_mode";
            data = { preset_mode: option };
            break;
        case "fan_modes":
        case "fan_mode":
            service = "set_fan_mode";
            data = { fan_mode: option };
            break;
        case "swing_modes":
        case "swing_mode":
            service = "set_swing_mode";
            data = { swing_mode: option };
            break;
        case "effect_list":
            service = domain === "light" ? "turn_on" : "select_effect";
            data = { effect: option };
            break;
        default:
            data = { option: option };
            break;
        }

        callService(domain, service, entityId, data);
    }

    function setTextValue(entityId, domain, text) {
        callService(domain, "set_value", entityId, {value: text});
    }

    function clearHistoryCache() {
        historyCache = {};
        console.log("HomeAssistantMonitor: History cache cleared");
    }

    function clearOldHistoryCache() {
        const now = Date.now();
        let cleared = 0;

        for (const entityId in historyCache) {
            const cache = historyCache[entityId];
            if (cache && (now - cache.timestamp) > historyCacheDuration) {
                delete historyCache[entityId];
                cleared++;
            }
        }
    }

    // 定期清理过期缓存
    Timer {
        interval: 600000  // 10分钟
        running: true
        repeat: true
        onTriggered: clearOldHistoryCache()
    }
}
