pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: root

    readonly property var defaults: ({
            haUrl: "http://127.0.0.1:8123",
            haToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhZjcxZDk2NGQ2MzI0NzQwYTY2MTA4N2JmYzIwNmY5YiIsImlhdCI6MTc2OTIzNjYxNSwiZXhwIjoyMDg0NTk2NjE1fQ.jj-Bq5xK3wMziR3idi2Evr3iQR4CjyNLEUPI6gPJA_4",
            entityIds: "sensor.miaomiaoc_cn_blt_3_1fih96uc0ck00_t2_temperature_p_2_1, sensor.miaomiaoc_cn_blt_3_1fih96uc0ck00_t2_relative_humidity_p_2_2",
            refreshInterval: 5000,
            showAttributes: true
        })

    readonly property string pluginId: "homeAssistantMonitor"

    property bool haAvailable: false
    property string haUrl: defaults.haUrl
    property string haToken: defaults.haToken
    property string entityIds: defaults.entityIds
    property int refreshInterval: defaults.refreshInterval
    property bool showAttributes: defaults.showAttributes

    function loadSettings() {
        const load = key => PluginService.loadPluginData(pluginId, key) || defaults[key];
        haUrl = load("hassUrl") || defaults.haUrl;
        haToken = load("hassToken") || defaults.haToken;
        entityIds = load("entityIds") || defaults.entityIds;
        refreshInterval = load("refreshInterval") || defaults.refreshInterval;
        const loadedShowAttributes = load("showAttributes");
        showAttributes = loadedShowAttributes !== undefined ? loadedShowAttributes : defaults.showAttributes;

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

    property var refreshTimer: Timer {
        interval: root.refreshInterval
        running: false
        repeat: true
        onTriggered: fetchEntities()
    }

    onRefreshIntervalChanged: {
        refreshTimer.interval = refreshInterval;
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

        if (!haUrl || !haToken) {
            updateEntities([]);
            haAvailable = false;
            return;
        }

        const curlCmd = [
            "curl",
            "-s",
            "-H", `Authorization: Bearer ${haToken}`,
            "-H", "Content-Type: application/json",
            `${haUrl}/api/states`
        ];

        Proc.runCommand(`${pluginId}.fetchEntities`, curlCmd, (stdout, exitCode) => {
            if (exitCode === 0) {
                try {
                    const allStates = JSON.parse(stdout);

                    // Store all available entities
                    const allEntities = allStates.map(entity => ({
                        entityId: entity.entity_id,
                        state: entity.state,
                        friendlyName: entity.attributes && entity.attributes.friendly_name ? entity.attributes.friendly_name : entity.entity_id,
                        unitOfMeasurement: entity.attributes && entity.attributes.unit_of_measurement ? entity.attributes.unit_of_measurement : "",
                        icon: entity.attributes && entity.attributes.icon ? entity.attributes.icon : "sensors",
                        attributes: entity.attributes || {},
                        lastChanged: entity.last_changed || "",
                        lastUpdated: entity.last_updated || "",
                        domain: entity.entity_id.split('.')[0] || ""
                    }));
                    PluginService.setGlobalVar(pluginId, "allEntities", allEntities);

                    // Filter monitored entities
                    const filtered = parsedEntityIds.length > 0
                        ? allStates.filter(entity => parsedEntityIds.includes(entity.entity_id))
                        : [];

                    const mapped = filtered.map(entity => ({
                        entityId: entity.entity_id,
                        state: entity.state,
                        friendlyName: entity.attributes && entity.attributes.friendly_name ? entity.attributes.friendly_name : entity.entity_id,
                        unitOfMeasurement: entity.attributes && entity.attributes.unit_of_measurement ? entity.attributes.unit_of_measurement : "",
                        icon: entity.attributes && entity.attributes.icon ? entity.attributes.icon : "sensors",
                        attributes: entity.attributes || {},
                        lastChanged: entity.last_changed || "",
                        lastUpdated: entity.last_updated || "",
                        domain: entity.entity_id.split('.')[0] || ""
                    }));

                    updateEntities(mapped);
                    haAvailable = true;
                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to parse HA response:", e);
                    updateEntities([]);
                    haAvailable = false;
                }
            } else {
                console.error("HomeAssistantMonitor: Failed to fetch entities, exit code:", exitCode);
                updateEntities([]);
                haAvailable = false;
            }
        }, 100);
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
            console.log("HomeAssistantMonitor: Added entity", entityId, "New list:", entityIds);
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
            console.log("HomeAssistantMonitor: Removed entity", entityId, "New list:", entityIds);
            refresh();
        }
    }

    // Entity control functions
    function callService(domain, service, entityId, serviceData) {
        if (!haUrl || !haToken) {
            console.error("HomeAssistantMonitor: Cannot call service - HA not configured");
            return;
        }

        const url = `${haUrl}/api/services/${domain}/${service}`;
        const data = serviceData || {};
        data.entity_id = entityId;
        const jsonData = JSON.stringify(data);

        const curlCmd = [
            "curl",
            "-s",
            "-X", "POST",
            "-H", `Authorization: Bearer ${haToken}`,
            "-H", "Content-Type: application/json",
            "-d", jsonData,
            url
        ];

        console.log(`HomeAssistantMonitor: Calling service ${domain}.${service} for ${entityId}`);

        Proc.runCommand(`${pluginId}.callService`, curlCmd, (stdout, exitCode) => {
            if (exitCode === 0) {
                console.log(`HomeAssistantMonitor: Service call successful`);
                // Refresh entities after a short delay to get updated state
                Qt.callLater(() => {
                    setTimeout(() => refresh(), 500);
                });
            } else {
                console.error(`HomeAssistantMonitor: Service call failed with code ${exitCode}`);
            }
        }, 100);
    }

    function toggleEntity(entityId, domain, currentState) {
        let service = "toggle";

        // Some entities don't support toggle, use turn_on/turn_off instead
        if (domain === "cover") {
            service = currentState === "open" ? "close_cover" : "open_cover";
        } else if (domain === "lock") {
            service = currentState === "locked" ? "unlock" : "lock";
        }

        callService(domain, service, entityId, {});
    }

    function setBrightness(entityId, brightness) {
        callService("light", "turn_on", entityId, { brightness: Math.round(brightness * 255 / 100) });
    }

    function setTemperature(entityId, temperature) {
        callService("climate", "set_temperature", entityId, { temperature: temperature });
    }

    function setFanSpeed(entityId, percentage) {
        callService("fan", "set_percentage", entityId, { percentage: percentage });
    }

    function setCoverPosition(entityId, position) {
        callService("cover", "set_cover_position", entityId, { position: position });
    }

    function triggerScript(entityId) {
        const domain = entityId.split('.')[0];
        callService(domain, "trigger" in ["script", "automation"] ? "trigger" : "turn_on", entityId, {});
    }

    function activateScene(entityId) {
        callService("scene", "turn_on", entityId, {});
    }
}
