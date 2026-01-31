pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
    
    readonly property bool isConfigured: hassUrl !== "" && hassToken !== ""

    property var historyCache: ({})
    readonly property int historyCacheDuration: 300000  // 5 minutes

    // Services cache for dynamic controls
    property var servicesCache: ({})
    property bool servicesLoaded: false

    // Entity Overrides (Friendly Name)
    property var entityOverrides: ({})

    function loadEntityOverrides() {
        var data = PluginService.loadPluginData(pluginId, "entityOverrides");
        entityOverrides = data || {};
    }

    function renameEntity(entityId, newName) {
        var overrides = Object.assign({}, entityOverrides);
        if (newName && newName.trim() !== "") {
            overrides[entityId] = newName;
        } else {
            delete overrides[entityId];
        }
        entityOverrides = overrides;
        PluginService.savePluginData(pluginId, "entityOverrides", overrides);

        // Update cached entity immediately
        if (cachedAllEntities) {
            var newCached = Array.from(cachedAllEntities);
            for (var i = 0; i < newCached.length; i++) {
                if (newCached[i].entityId === entityId) {
                    // Create a new object to ensure property changes are detected
                    newCached[i] = Object.assign({}, newCached[i], { friendlyName: newName });
                    break;
                }
            }
            cachedAllEntities = newCached;
            PluginService.setGlobalVar(pluginId, "allEntities", newCached);
            reprocessMonitoredEntities(); // This pushes changes to global "entities" var
        }
        
        // If we really want to reset to original, we might need to fetch the entity again or store original name.
        if (!newName) fetchEntity(entityId); 
    }

    // Devices cache for entity grouping by device
    property var devicesCache: ({})  // { "Device Name": ["entity_id1", "entity_id2", ...] }
    property var entityToDeviceCache: ({}) // { "entity_id1": "Device Name" }
    property bool devicesLoaded: false
    property string lastMonitoredIdsStr: "" // Tracks structure to avoid jitter
    property string wsUrl: {
        if (!hassUrl) return "";
        let url = hassUrl.toString();
        url = url.replace(/^http/, "ws");
        if (!url.endsWith("/")) url += "/";
        if (!url.endsWith("api/websocket")) url += "api/websocket";
        return url;
    }
    property int nextMsgId: 1
    property var wsCallbacks: ({})
    property int latency: -1
    property var lastPingTime: 0
    property int currentReconnectInterval: 5000 // Start with 5 seconds
    readonly property int maxReconnectInterval: 60000 // Max 1 minute

    function clearCallbacks(reason) {
        for (var id in wsCallbacks) {
            try {
                if (wsCallbacks[id] && wsCallbacks[id].cb) {
                    wsCallbacks[id].cb({success: false, error: reason});
                }
            } catch (e) {
                console.error("HomeAssistantMonitor: Error clearing callback:", e);
            }
        }
        wsCallbacks = ({});
    }

    // WebSocket Constants (mapped to QtWebSockets values)
    readonly property int wsConnecting: 0
    readonly property int wsOpen: 1
    readonly property int wsClosing: 2
    readonly property int wsClosed: 3
    readonly property int wsError: 4

    property bool missingDependency: false
    property var socket: wsLoader.item

    Timer {
        id: callbackGcTimer
        interval: 30000
        running: socket && socket.active
        repeat: true
        onTriggered: {
            const now = Date.now();
            const timeout = 60000;
            var idsToRemove = [];
            for (var id in wsCallbacks) {
                if (wsCallbacks[id] && (now - wsCallbacks[id].ts > timeout)) {
                    try {
                        if (wsCallbacks[id].cb) wsCallbacks[id].cb({success: false, error: "Timeout"});
                    } catch(e) {}
                    idsToRemove.push(id);
                }
            }
            for (var i = 0; i < idsToRemove.length; i++) delete wsCallbacks[idsToRemove[i]];
        }
    }

    Loader {
        id: wsLoader
        source: "WebSocketClient.qml"
        active: true
        
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("HomeAssistantMonitor: Failed to load WebSocketClient. Dependency 'qt6-websockets' likely missing.");
                root.missingDependency = true;
            } else if (status === Loader.Ready) {
                root.missingDependency = false;
            }
        }

        Binding {
            target: wsLoader.item
            property: "url"
            value: root.wsUrl
            when: wsLoader.status === Loader.Ready
        }

        Binding {
            target: wsLoader.item
            property: "active"
            value: !!root.hassUrl && !!root.hassToken
            when: wsLoader.status === Loader.Ready
        }
        
        Connections {
            target: wsLoader.item
            ignoreUnknownSignals: true
            
            function onSocketStatusChanged(status) {
                if (status === root.wsError) {
                    console.error("HomeAssistantMonitor: WebSocket Error:", wsLoader.item.errorString);
                    haAvailable = false;
                    latency = -1;
                    PluginService.setGlobalVar(pluginId, "latency", -1);
                    clearCallbacks("WebSocket Error: " + wsLoader.item.errorString);
                    reconnectTimer.start();
                } else if (status === root.wsClosed) {
                    haAvailable = false;
                    latency = -1;
                    PluginService.setGlobalVar(pluginId, "latency", -1);
                    clearCallbacks("WebSocket Closed");
                    reconnectTimer.start();
                } else if (status === root.wsOpen) {
                    currentReconnectInterval = 5000;
                    reconnectTimer.stop();
                    pingTimer.start();
                }
            }

            function onTextMessageReceived(message) {
                try {
                    const data = JSON.parse(message);
                    handleWsMessage(data);
                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to parse WebSocket message:", e);
                }
            }
        }
    }

    Timer {
        id: reconnectTimer
        interval: root.currentReconnectInterval
        repeat: false
        onTriggered: {
            if (socket && socket.status !== root.wsOpen) {
                // Toggle active to trigger reconnect if supported by Loader binding or manual reset
                // Loader bindings are one-way. Toggling `active` on item directly might not work if bound?
                // Actually `active` property on item is bound to `!!root.hassUrl...`.
                // If we want to force reconnect, maybe we need to reload the Loader or toggle a property?
                // `WebSocket` usually reconnects if `active` is toggled.
                // The binding will keep it true.
                // We might need to force reload loader? No, that's heavy.
                // If `WebSocket` component has `active` property, and we bind it.
                // Toggling `active` on the socket item itself effectively restarts it.
                // But the binding will override it?
                // QML Bindings: if we write to the property, the binding breaks!
                // So we shouldn't write to `socket.active`.
                // Ideally `QtWebSockets` handles reconnect if `active` stays true? No, it often needs a toggle.
                // Let's toggle `wsLoader.active`? No, that destroys the item.
                // Let's add a `reconnect()` method to `WebSocketClient.qml`?
                // `WebSocket` doesn't have `reconnect()`.
                // Toggle `active` is the standard way.
                // Since I bound it: `value: !!root.hassUrl... when: ...`.
                // If I write to `socket.active`, I break the binding.
                // Strategy: Use an internal `reconnectTrigger` property in Service?
                // Or: since `reconnectTimer` is only needed if connection dropped.
                // If I reload the loader, it's clean but heavy.
                // Let's leave the toggle logic but be aware of binding break.
                // Actually, if binding breaks, it stays `true` (since we toggle false then true).
                // It stays true until `hassUrl` changes again.
                // This seems acceptable for now.
                if (socket) {
                    socket.active = false;
                    socket.active = true;
                }
                
                // Exponential backoff
                root.currentReconnectInterval = Math.min(root.maxReconnectInterval, root.currentReconnectInterval * 1.5);
            }
        }
    }

    Timer {
        id: pingTimer
        interval: 30000 // 30 seconds
        repeat: true
        running: false
        onTriggered: {
            if (socket && socket.status === root.wsOpen) {
                root.lastPingTime = Date.now();
                sendWsMessage({ type: "ping" }, (response) => {
                    if (response.type === "pong") {
                        root.latency = Date.now() - root.lastPingTime;
                        PluginService.setGlobalVar(pluginId, "latency", root.latency);
                    }
                });
            } else {
                stop();
            }
        }
    }

    Timer {
        id: batchUpdateTimer
        interval: 100
        repeat: false
        onTriggered: reprocessMonitoredEntities()
    }

    function loadSettings() {
        const load = (key, defaultValue) => {
            const val = PluginService.loadPluginData(pluginId, key);
            return val !== undefined ? val : defaultValue;
        }

        hassUrl = load("hassUrl", "http://homeassistant.local:8123");
        var token = load("hassToken", "");
        hassToken = token ? token.trim() : "";
        
        entityIds = load("entityIds", "");
        refreshInterval = load("refreshInterval", 3);
        showAttributes = load("showAttributes", false);

        refresh();
    }

    function saveCredentials(url, token) {
        // Remove trailing slash from URL if present
        let cleanUrl = url.trim();
        if (cleanUrl.endsWith("/")) {
            cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
        }
        
        PluginService.savePluginData(pluginId, "hassUrl", cleanUrl);
        PluginService.savePluginData(pluginId, "hassToken", token.trim());
        
        // Reload settings immediately
        loadSettings();
    }

    // Shortcuts Management
    property var shortcuts: []
    
    ListModel {
        id: shortcutsListModel
    }
    
    property alias shortcutsModel: shortcutsListModel

    function loadShortcuts() {
        var data = PluginService.loadPluginData(pluginId, "shortcuts");
        shortcuts = data || [];
        _syncShortcutsModel();
    }
    
    function _syncShortcutsModel() {
        shortcutsListModel.clear();
        for (var i = 0; i < shortcuts.length; i++) {
            var s = shortcuts[i];
            shortcutsListModel.append({
                "entityId": s.id,
                "name": s.name,
                "domain": s.domain
            });
        }
    }

    function addShortcut(entity) {
        if (isShortcut(entity.entityId)) return;
        var list = Array.from(shortcuts);
        var newItem = {
            id: entity.entityId,
            name: entity.friendlyName, // Default name
            domain: entity.domain
        };
        list.push(newItem);
        shortcuts = list;
        shortcutsListModel.append({
            "entityId": newItem.id,
            "name": newItem.name,
            "domain": newItem.domain
        });
        PluginService.savePluginData(pluginId, "shortcuts", list);
    }

    function removeShortcut(entityId) {
        var list = shortcuts.filter(s => s.id !== entityId);
        shortcuts = list;
        
        // Sync model efficiently
        for (var i = 0; i < shortcutsListModel.count; i++) {
            if (shortcutsListModel.get(i).entityId === entityId) {
                shortcutsListModel.remove(i);
                break;
            }
        }
        
        PluginService.savePluginData(pluginId, "shortcuts", list);
    }

    function renameShortcut(entityId, newName) {
        var list = Array.from(shortcuts);
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === entityId) {
                list[i].name = newName;
                break;
            }
        }
        shortcuts = list;

        // Sync model
        for (var j = 0; j < shortcutsListModel.count; j++) {
            if (shortcutsListModel.get(j).entityId === entityId) {
                shortcutsListModel.setProperty(j, "name", newName);
                break;
            }
        }

        PluginService.savePluginData(pluginId, "shortcuts", list);
    }

    function moveShortcut(fromIndex, toIndex) {
        if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return;
        if (fromIndex >= shortcuts.length || toIndex >= shortcuts.length) return;

        var list = Array.from(shortcuts);
        var item = list.splice(fromIndex, 1)[0];
        list.splice(toIndex, 0, item);
        shortcuts = list;

        shortcutsListModel.move(fromIndex, toIndex, 1);

        PluginService.savePluginData(pluginId, "shortcuts", list);
    }

    function isShortcut(entityId) {
        for (var i = 0; i < shortcuts.length; i++) {
            if (shortcuts[i].id === entityId) return true;
        }
        return false;
    }

    Component.onCompleted: {
        loadSettings();
        loadShortcuts();
        loadEntityOverrides();
        initialize();
    }

    Connections {
        target: PluginService

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) {
                // Defer loading settings to avoid potential crash/race conditions
                Qt.callLater(loadSettings);
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
        // Only run polling if WebSocket is NOT connected and we are configured
        running: (!socket || socket.status !== root.wsOpen) && root.isConfigured
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
        fetchServices();
        fetchDevices();
        refresh(); // Initial fetch via REST to get data immediately
    }

    function refresh() {
        if (socket && socket.status === root.wsOpen) {
            // 1. Fetch States
            sendWsMessage({ type: "get_states" }, (response) => {
                if (response.success && Array.isArray(response.result)) {
                    updateAllEntitiesFromWs(response.result);
                }
            });

            // 2. Only fetch metadata if not already loaded (avoid unnecessary refreshes)
            if (!servicesLoaded) {
                fetchServices();
            }
            if (!devicesLoaded) {
                fetchDevices();
            }
        } else {
            fetchEntities();
        }
    }

    function sendWsMessage(msg, callback) {
        if (!socket || socket.status !== root.wsOpen) {
            if (callback) callback({success: false, error: "WebSocket not connected"});
            return;
        }
        const id = nextMsgId++;
        msg.id = id;
        if (callback) {
            wsCallbacks[id] = { cb: callback, ts: Date.now() };
        }

        socket.sendTextMessage(JSON.stringify(msg));
    }

    function handleWsMessage(data) {
        if (data.type === "auth_required") {
            socket.sendTextMessage(JSON.stringify({
                type: "auth",
                access_token: root.hassToken
            }));
        } else if (data.type === "auth_ok") {
            haAvailable = true;
            
            // Subscribe to state changes
            sendWsMessage({ type: "subscribe_events", event_type: "state_changed" });
            
            // Trigger metadata and state fetch after auth
            Qt.callLater(() => {
                fetchServices();
                fetchDevices();
                refresh();
                
                // Trigger immediate ping to get initial latency
                root.lastPingTime = Date.now();
                sendWsMessage({ type: "ping" }, (response) => {
                    if (response.type === "pong") {
                        root.latency = Date.now() - root.lastPingTime;
                        PluginService.setGlobalVar(pluginId, "latency", root.latency);
                    }
                });
            });
        } else if (data.type === "auth_invalid") {
            console.error("HomeAssistantMonitor: WebSocket Auth Failed:", data.message);
            haAvailable = false;
            socket.active = false;
        } else if (data.type === "event") {
            if (data.event.event_type === "state_changed") {
                const eventData = data.event.data;
                if (eventData.new_state) {
                    processWsEntityUpdate(eventData.new_state);
                } else if (eventData.old_state) {
                    // new_state is null means entity was removed from HA state machine
                    handleWsEntityRemoved(eventData.entity_id);
                }
            }
        } else if (data.type === "result" || data.type === "pong") {
            if (wsCallbacks[data.id]) {
                if (wsCallbacks[data.id].cb) wsCallbacks[data.id].cb(data);
                delete wsCallbacks[data.id];
            }
        }
    }

    function updateAllEntitiesFromWs(allStates) {
         const parsedEntityIds = parseEntityIds();
         
         const allEntities = [];
         const entityMap = {};

         for (const entity of allStates) {
             const mapped = mapEntity(entity);
             if (mapped) {
                 allEntities.push(mapped);
                 entityMap[mapped.entityId] = mapped;
             }
         }

         cachedAllEntities = allEntities;
         PluginService.setGlobalVar(pluginId, "allEntities", allEntities);
         
         // Build monitored list in order
         const monitoredEntities = [];
         for (const id of parsedEntityIds) {
             if (entityMap[id]) {
                 monitoredEntities.push(entityMap[id]);
             }
         }
         
         const newIds = monitoredEntities.map(e => e.entityId).join(",");
         lastMonitoredIdsStr = newIds;
         
         haAvailable = true;
         updateEntities(monitoredEntities);
    }

    function processWsEntityUpdate(entity) {
        const mapped = mapEntity(entity);
        if (!mapped) return;

        // Update in cachedAllEntities
        let found = false;
        for (let i = 0; i < cachedAllEntities.length; i++) {
            if (cachedAllEntities[i].entityId === mapped.entityId) {
                cachedAllEntities[i] = mapped;
                found = true;
                break;
            }
        }

        if (!found) {
            cachedAllEntities.push(mapped);
        }

        // Trigger batch update for monitored list
        batchUpdateTimer.start();
    }

    function handleWsEntityRemoved(entityId) {
        // Remove from cachedAllEntities
        const oldLen = cachedAllEntities.length;
        cachedAllEntities = cachedAllEntities.filter(e => e.entityId !== entityId);
        
        if (oldLen !== cachedAllEntities.length) {
            // Trigger batch update to refresh UI lists
            batchUpdateTimer.start();
        }
    }

    // Fetch service definitions for dynamic controls via WebSocket
    function fetchServices() {
        if (servicesLoaded || !socket || socket.status !== root.wsOpen) return;
        
        sendWsMessage({ type: "get_services" }, (response) => {
            if (response.success && response.result) {
                try {
                    const data = response.result;
                    const cache = {};
                    for (const domain in data) {
                        cache[domain] = data[domain];
                    }
                    servicesCache = cache;
                    servicesLoaded = true;
                    PluginService.setGlobalVar(pluginId, "servicesCache", cache);
                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to process services:", e);
                }
            } else {
                 console.error("HomeAssistantMonitor: Failed to fetch services via WS");
            }
        });
    }

    // Get service definition for a specific domain and service
    function getServiceFields(domain, service) {
        if (!servicesCache[domain]) return null;
        const svc = servicesCache[domain][service];
        return svc ? svc.fields : null;
    }

    // Fetch devices and entities registry to build the device mapping via WebSocket
    function fetchDevices() {
        if (devicesLoaded || !socket || socket.status !== root.wsOpen) return;
        
        // 1. Get Device Registry
        sendWsMessage({ type: "config/device_registry/list" }, (devResponse) => {
            if (!devResponse.success) {
                console.error("HomeAssistantMonitor: Failed to fetch device registry");
                return;
            }

            // 2. Get Entity Registry
            sendWsMessage({ type: "config/entity_registry/list" }, (entResponse) => {
                if (!entResponse.success) {
                    console.error("HomeAssistantMonitor: Failed to fetch entity registry");
                    return;
                }

                try {
                    const devices = Array.isArray(devResponse.result) ? devResponse.result : [];
                    const entities = Array.isArray(entResponse.result) ? entResponse.result : [];
                    
                    const deviceIdToName = {};
                    devices.forEach(d => {
                        deviceIdToName[d.id] = d.name_by_user || d.name || "Unknown Device";
                    });

                    const newDevicesCache = {};
                    const newEntityToDeviceCache = {};

                    entities.forEach(e => {
                        if (e.device_id && deviceIdToName[e.device_id]) {
                            const deviceName = deviceIdToName[e.device_id];
                            if (!newDevicesCache[deviceName]) {
                                newDevicesCache[deviceName] = [];
                            }
                            newDevicesCache[deviceName].push(e.entity_id);
                            newEntityToDeviceCache[e.entity_id] = deviceName;
                        }
                    });

                    devicesCache = newDevicesCache;
                    entityToDeviceCache = newEntityToDeviceCache;
                    devicesLoaded = true;
                    
                    PluginService.setGlobalVar(pluginId, "devicesCache", newDevicesCache);
                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to process registry data:", e);
                }
            });
        });
    }

    function makeRequest(method, endpoint, data, callback, retryCount = 0) {
        if (!hassUrl || !hassToken) {
            console.warn("HomeAssistantMonitor: Missing URL or Token");
            if (callback) callback(null, -1);
            return;
        }

        const maxRetries = 2;
        var xhr = new XMLHttpRequest();
        var url = hassUrl + endpoint;
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    if (callback) callback(xhr.responseText, 0);
                } else {
                    console.error("HomeAssistantMonitor: Request failed", url, xhr.status, xhr.statusText);
                    // Retry on server errors or connection issues (status 0 or 5xx)
                    // Don't retry on 4xx (client error)
                    if (retryCount < maxRetries && (xhr.status === 0 || xhr.status >= 500)) {
                        console.log(`HomeAssistantMonitor: Retrying... (${retryCount + 1}/${maxRetries})`);
                        Qt.callLater(() => {
                            makeRequest(method, endpoint, data, callback, retryCount + 1);
                        });
                    } else {
                        if (callback) callback(null, xhr.status || -1);
                    }
                }
            }
        }
        
        xhr.open(method, url);
        xhr.setRequestHeader("Authorization", "Bearer " + hassToken);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 10000; // 10 seconds
        
        xhr.ontimeout = function() {
            console.error("HomeAssistantMonitor: Request timed out", url);
            if (retryCount < maxRetries) {
                console.log(`HomeAssistantMonitor: Retrying (timeout)... (${retryCount + 1}/${maxRetries})`);
                Qt.callLater(() => {
                    makeRequest(method, endpoint, data, callback, retryCount + 1);
                });
            } else {
                if (callback) callback(null, 408); // 408 Request Timeout
            }
        }

        if (data) {
            xhr.send(JSON.stringify(data));
        } else {
            xhr.send();
        }
    }

    function mapEntity(entity) {
        if (!entity) return null;

        const attrs = entity.attributes || {};
        const entityId = entity.entity_id || "";
        const overrideName = entityOverrides[entityId];

        return {
            entityId: entityId,
            state: entity.state || "",
            friendlyName: overrideName || attrs.friendly_name || entityId,
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

        const now = Date.now();
        const cache = historyCache[entityId];

        if (cache && (now - cache.timestamp) < historyCacheDuration) {
            if (callback) callback(cache.data);
            return;
        }

        const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
        const endpoint = `/api/history/period/${yesterday}?filter_entity_id=${entityId}&minimal_response`;

        makeRequest("GET", endpoint, null, (stdout, exitCode) => {
            if (exitCode === 0 && stdout) {
                try {
                    const data = JSON.parse(stdout);
                    // REST API returns [[{entry}, {entry}...]]
                    if (data && data.length > 0 && Array.isArray(data[0])) {
                        const history = data[0]
                            .map(item => ({
                                value: parseFloat(item.state),
                                time: new Date(item.last_changed || item.last_updated)
                            }))
                            .filter(item => !isNaN(item.value));

                        const cacheEntry = { data: history, timestamp: now };
                        historyCache = Object.assign({}, historyCache, { [entityId]: cacheEntry });
                        if (callback) callback(history);
                    } else {
                        console.warn("HomeAssistantMonitor: Unexpected history format from REST API");
                        if (callback) callback([]);
                    }
                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to parse REST history:", e);
                    if (callback) callback([]);
                }
            } else {
                console.error("HomeAssistantMonitor: REST history request failed, exitCode:", exitCode);
                if (callback) callback([]);
            }
        });
    }

    // Cache for all entities to avoid re-fetching on local updates
    property var cachedAllEntities: []

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

                    // Single iteration, process all entities and monitored entities
                    const allEntities = [];
                    const entityMap = {};

                    for (const entity of allStates) {
                        const mapped = mapEntity(entity);
                        if (mapped) {
                            allEntities.push(mapped);
                            entityMap[mapped.entityId] = mapped;
                        }
                    }

                    cachedAllEntities = allEntities;
                    
                    PluginService.setGlobalVar(pluginId, "allEntities", allEntities);

                    // Build monitored list in order
                    const monitoredEntities = [];
                    for (const id of parsedEntityIds) {
                        if (entityMap[id]) {
                            monitoredEntities.push(entityMap[id]);
                        }
                    }

                    // 2. Only update the "heavy" list model if the structure changed
                    // (length changed or IDs changed)
                    const newIds = monitoredEntities.map(e => e.entityId).join(",");

                    if (lastMonitoredIdsStr !== newIds) {
                        lastMonitoredIdsStr = newIds;
                    }
                    
                    // Always update to ensure data flow, UI ListModel will handle smoothing
                    haAvailable = true;
                    updateEntities(monitoredEntities);

                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to parse HA response:", e);
                    haAvailable = false;
                    updateEntities([]);
                }
            } else {
                console.error("HomeAssistantMonitor: Failed to fetch entities");
                // Keep old data, don't clear
                haAvailable = false;
                PluginService.setGlobalVar(pluginId, "haAvailable", false);
            }
        });
    }

    function reprocessMonitoredEntities() {
        const parsedEntityIds = parseEntityIds();
        const monitoredEntities = [];
        
        // Use cachedAllEntities if available
        if (cachedAllEntities && cachedAllEntities.length > 0) {
            // Create a map for fast lookup
            const entityMap = {};
            for (const mapped of cachedAllEntities) {
                entityMap[mapped.entityId] = mapped;
            }
            
            // Iterate ids in order
            for (const id of parsedEntityIds) {
                if (entityMap[id]) {
                    monitoredEntities.push(entityMap[id]);
                }
            }
            
            updateEntities(monitoredEntities);
        } else {
            // Fallback if cache is empty
            refresh();
        }
    }

    function updateEntities(entities = []) {
        PluginService.setGlobalVar(pluginId, "entities", entities);
        PluginService.setGlobalVar(pluginId, "entityCount", entities.length);
        PluginService.setGlobalVar(pluginId, "haAvailable", haAvailable);
    }

    function addEntityToMonitor(entityId) {
        addEntitiesToMonitor([entityId]);
    }

    function addEntitiesToMonitor(idList) {
        let ids = parseEntityIds();
        let addedCount = 0;
        
        for (const entityId of idList) {
            if (!ids.includes(entityId)) {
                ids.push(entityId);
                addedCount++;
            }
        }
        
        if (addedCount > 0) {
            entityIds = ids.join(", ");
            PluginService.savePluginData(pluginId, "entityIds", entityIds);
            reprocessMonitoredEntities();
        }
    }

    function removeEntityFromMonitor(entityId) {
        let ids = parseEntityIds();
        const index = ids.indexOf(entityId);
        if (index >= 0) {
            ids.splice(index, 1);
            entityIds = ids.join(", ");
            PluginService.savePluginData(pluginId, "entityIds", entityIds);

            // Clear history cache for this entity
            const newCache = Object.assign({}, historyCache);
            delete newCache[entityId];
            historyCache = newCache;

            reprocessMonitoredEntities();
        }
    }

    function moveEntity(entityId, direction) {
        let ids = parseEntityIds();
        const index = ids.indexOf(entityId);
        if (index < 0) return;

        if (direction === "up" && index > 0) {
            const temp = ids[index];
            ids[index] = ids[index - 1];
            ids[index - 1] = temp;
        } else if (direction === "down" && index < ids.length - 1) {
            const temp = ids[index];
            ids[index] = ids[index + 1];
            ids[index + 1] = temp;
        } else {
            return; // No change needed
        }

        entityIds = ids.join(", ");
        PluginService.savePluginData(pluginId, "entityIds", entityIds);
        reprocessMonitoredEntities();
    }

    function callService(domain, service, entityId, serviceData) {
        if (socket && socket.status === root.wsOpen) {
            const msg = {
                type: "call_service",
                domain: domain,
                service: service,
                service_data: serviceData || {}
            };
            
            if (entityId) {
                // Compatibility Fix: For media_player (and potentially others), 
                // some integrations fail if 'target' is present.
                // We default to 'target' for modern standard, but fallback for specific domains.
                if (domain === "media_player") {
                    msg.service_data.entity_id = entityId;
                } else {
                    msg.target = { entity_id: entityId };
                    // Keep dual injection for others just in case, unless it causes issues
                    msg.service_data.entity_id = entityId; 
                }
            }
            
            sendWsMessage(msg, (response) => {
                if (!response.success) {
                    console.error("HomeAssistantMonitor: WebSocket Service call failed:", response.error ? response.error.message : "unknown error");
                }
                // WebSocket will push state_changed event automatically
            });
            return;
        }

        if (!hassUrl || !hassToken) {
            console.error("HomeAssistantMonitor: Cannot call service - HA not configured");
            return;
        }

        const endpoint = `/api/services/${domain}/${service}`;
        const data = serviceData || {};
        data.entity_id = entityId;

        makeRequest("POST", endpoint, data, (stdout, exitCode) => {
            if (exitCode === 0) {
                // Refresh only this entity to avoid UI jitter
                fetchEntity(entityId); 
            } else {
                console.error("HomeAssistantMonitor: Service call failed");
            }
        });
    }

    function fetchEntity(entityId) {
        makeRequest("GET", "/api/states/" + entityId, null, (stdout, exitCode) => {
             if (exitCode === 0 && stdout) {
                 try {
                     const stateObj = JSON.parse(stdout);
                     const mapped = mapEntity(stateObj);
                     if (mapped) {
                         // Update local cache and notify listeners
                         updateEntityState(entityId, mapped.state, mapped.attributes);
                     }
                 } catch (e) {
                     console.error("HomeAssistantMonitor: Failed to update entity single state:", e);
                 }
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

    function setLightColor(entityId, r, g, b) {
        callService("light", "turn_on", entityId, {rgb_color: [Math.round(r), Math.round(g), Math.round(b)]});
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

    function setClimateFanMode(entityId, mode) {
        callService("climate", "set_fan_mode", entityId, {fan_mode: mode});
    }

    function setFanSpeed(entityId, percentage) {
        // Don't round - HA expects exact step values (e.g., 33.33, 66.66, 100)
        callService("fan", "set_percentage", entityId, {percentage: percentage});
    }

    function setOscillating(entityId, oscillating) {
        callService("fan", "oscillate", entityId, {oscillating: oscillating});
    }

    function setCoverPosition(entityId, position) {
        callService("cover", "set_cover_position", entityId, {position: Math.round(position)});
    }

    function triggerScript(entityId) {
        const domain = entityId.split('.')[0];
        let service = "turn_on";
        
        if (domain === "script" || domain === "automation") {
            service = "trigger";
        } else if (domain === "button") {
            service = "press";
        } else if (domain === "scene") {
            service = "turn_on";
        }
        
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
    
    // Optimistic UI State Management
    property var optimisticStates: ({})
    property var optimisticTimestamps: ({})

    function setOptimisticState(entityId, key, value) {
        var states = Object.assign({}, optimisticStates);
        var timestamps = Object.assign({}, optimisticTimestamps);
        
        if (!states[entityId]) states[entityId] = {};
        if (!timestamps[entityId]) timestamps[entityId] = {};
        
        states[entityId][key] = value;
        timestamps[entityId][key] = Date.now();
        
        optimisticStates = states;
        optimisticTimestamps = timestamps;
    }

    function getEffectiveValue(entityId, attribute, realValue) {
        if (optimisticStates[entityId] && optimisticStates[entityId][attribute] !== undefined) {
            return optimisticStates[entityId][attribute];
        }
        return realValue;
    }

    Timer {
        id: optimisticCleanupTimer
        interval: 2000
        repeat: true
        running: Object.keys(optimisticStates).length > 0
        onTriggered: {
            var now = Date.now();
            var states = Object.assign({}, optimisticStates);
            var timestamps = Object.assign({}, optimisticTimestamps);
            var changed = false;

            for (var id in timestamps) {
                var entityClean = true;
                for (var key in timestamps[id]) {
                    if (now - timestamps[id][key] > 30000) { // 30s timeout
                        delete states[id][key];
                        delete timestamps[id][key];
                        changed = true;
                    } else {
                        entityClean = false;
                    }
                }
                if (entityClean) {
                    delete states[id];
                    delete timestamps[id];
                    changed = true;
                }
            }

            if (changed) {
                optimisticStates = states;
                optimisticTimestamps = timestamps;
            }
        }
    }

    // Updates a single entity's state in the local cache and global vars
    // avoiding a full refresh and preventing UI jitter
    function updateEntityState(entityId, newStateStr, newAttributes) {
        // 1. Update in cachedAllEntities
        if (cachedAllEntities) {
            for (let i = 0; i < cachedAllEntities.length; i++) {
                if (cachedAllEntities[i].entityId === entityId) {
                    let e = cachedAllEntities[i];
                    
                    if (newStateStr !== undefined) e.state = newStateStr;
                    if (newAttributes !== undefined) {
                         e.attributes = Object.assign({}, e.attributes, newAttributes);
                    }
                    e.lastUpdated = new Date().toISOString();
                    
                    // Check and clear optimistic states
                    if (optimisticStates[entityId]) {
                        var states = Object.assign({}, optimisticStates);
                        var timestamps = Object.assign({}, optimisticTimestamps);
                        var changed = false;
                        
                        // Check state
                        if (newStateStr !== undefined && states[entityId]["state"] !== undefined) {
                            if (String(states[entityId]["state"]) === String(newStateStr)) {
                                delete states[entityId]["state"];
                                delete timestamps[entityId]["state"];
                                changed = true;
                            }
                        }
                        
                        // Check attributes
                        if (newAttributes !== undefined) {
                            for (var key in newAttributes) {
                                if (states[entityId][key] !== undefined) {
                                    // Loose equality for numbers/strings match
                                    if (String(states[entityId][key]) === String(newAttributes[key])) {
                                        delete states[entityId][key];
                                        delete timestamps[entityId][key];
                                        changed = true;
                                    }
                                }
                            }
                        }
                        
                        // Clean up empty objects
                        if (changed) {
                            if (Object.keys(states[entityId]).length === 0) {
                                delete states[entityId];
                                delete timestamps[entityId];
                            }
                            optimisticStates = states;
                            optimisticTimestamps = timestamps;
                        }
                    }
                    
                    break;
                }
            }
        }
    }

    function clearHistoryCache() {
        historyCache = {};
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
