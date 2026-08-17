pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "../components" as Components

Singleton {
    id: root

    readonly property string pluginId: "homeAssistantMonitor"

    property bool haAvailable: false
    property string connectionStatus: "offline"
    property string connectionMessage: ""
    property string hassUrl: ""
    property string hassTokenPath: ""
    property string _tokenFromFile: ""
    property string _tokenFromSettings: ""
    property string hassToken: hassTokenPath !== "" ? _tokenFromFile : _tokenFromSettings
    readonly property string defaultTokenPath: {
        const configHome = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        return configHome + "/DankMaterialShell/secrets/home-assistant.token";
    }
    property string entityIds: ""
    property int refreshInterval: 3
    property bool showAttributes: false
    property bool settingsReloadQueued: false
    property bool statesRequestInFlight: false
    property bool statesRefreshPending: false
    property bool statesPendingRefreshCompletion: false
    property int statesFailureBackoffMs: 0
    
    readonly property bool isConfigured: hassUrl !== "" && hassToken !== ""

    property var historyCache: ({})
    property var historyRequests: ({})

    readonly property int historyCacheDuration: Components.HassConstants.historyCacheDuration

    // Services cache for dynamic controls
    property var servicesCache: ({})
    property bool servicesLoaded: false
    property var translationsCache: ({})
    property var translationDomainsLoaded: ({})
    property var translationDomainsLoading: ({})
    property int translationsVersion: 0

    // Entity Overrides (Friendly Name)
    property var entityOverrides: ({})

    function loadPersistentPluginValue(key, fallbackValue) {
        if (PluginService.loadPluginState) {
            const stateValue = PluginService.loadPluginState(pluginId, key, undefined);
            if (stateValue !== undefined) {
                return stateValue;
            }
        }

        const dataValue = PluginService.loadPluginData(pluginId, key, undefined);
        return dataValue !== undefined ? dataValue : fallbackValue;
    }

    function savePersistentPluginValue(key, value) {
        if (PluginService.savePluginState) {
            PluginService.savePluginState(pluginId, key, value);
            return;
        }
        PluginService.savePluginData(pluginId, key, value);
    }

    function normalizeBaseUrl(url) {
        return url.toString().trim().replace(/\/+$/, "");
    }

    function loadEntityOverrides() {
        var data = loadPersistentPluginValue("entityOverrides", {});
        entityOverrides = data || {};
    }

    function findCachedEntityIndex(entityId) {
        const index = cachedEntityIndexes[entityId];
        return index === undefined ? -1 : index;
    }

    function getCachedEntity(entityId) {
        return cachedEntityById[entityId] || null;
    }

    function rebuildCachedEntityIndexes() {
        const byId = {};
        const indexes = {};
        for (let i = 0; i < cachedAllEntities.length; i++) {
            const entity = cachedAllEntities[i];
            byId[entity.entityId] = entity;
            indexes[entity.entityId] = i;
        }
        cachedEntityById = byId;
        cachedEntityIndexes = indexes;
    }

    function upsertCachedEntity(entity) {
        if (!entity) return;
        const index = findCachedEntityIndex(entity.entityId);
        if (index >= 0) {
            cachedAllEntities[index] = entity;
        } else {
            cachedEntityIndexes[entity.entityId] = cachedAllEntities.length;
            cachedAllEntities.push(entity);
            allEntitiesStructureDirty = true;
        }
        cachedEntityById[entity.entityId] = entity;
        if (!allEntitiesPublishTimer.running)
            allEntitiesPublishTimer.start();
    }

    function applyOptimisticState(entity) {
        if (!entity) return null;
        const overrides = optimisticStates[entity.entityId];
        if (!overrides) return entity;

        const nextEntity = Object.assign({}, entity);
        for (const key in overrides) {
            if (key === "state") {
                nextEntity.state = overrides[key];
            } else {
                nextEntity.attributes = Object.assign({}, nextEntity.attributes || {});
                nextEntity.attributes[key] = overrides[key];
            }
        }
        return nextEntity;
    }

    function buildMonitoredEntities(entityIdsList, entityMap) {
        const monitoredEntities = [];
        for (const id of entityIdsList) {
            if (entityMap[id]) {
                monitoredEntities.push(applyOptimisticState(entityMap[id]));
            }
        }
        return monitoredEntities;
    }

    function persistMonitoredEntityIds() {
        if (PluginService.savePluginState) {
            PluginService.savePluginState(pluginId, "entityIds", entityIds);
        } else {
            PluginService.savePluginData(pluginId, "entityIds", entityIds);
        }
    }

    function renameEntity(entityId, newName) {
        var overrides = Object.assign({}, entityOverrides);
        if (newName && newName.trim() !== "") {
            overrides[entityId] = newName;
        } else {
            delete overrides[entityId];
        }
        entityOverrides = overrides;
        savePersistentPluginValue("entityOverrides", overrides);

        // Update cached entity immediately
        if (cachedAllEntities) {
            const cachedEntity = getCachedEntity(entityId);
            if (cachedEntity) {
                upsertCachedEntity(Object.assign({}, cachedEntity, { friendlyName: newName }));
            }
            reprocessMonitoredEntities(); // This pushes changes to global "entities" var
        }
        
        // If we really want to reset to original, we might need to fetch the entity again or store original name.
        if (!newName) fetchEntity(entityId); 
    }

    // Devices cache for entity grouping by device
    property var devicesCache: ({})
    property var entityToDeviceCache: ({})
    property bool devicesLoaded: false
    property bool devicesLoading: false
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
    property int currentReconnectInterval: Components.HassConstants.initialReconnectInterval
    readonly property int maxReconnectInterval: Components.HassConstants.maxReconnectInterval
    property bool wsAuthenticated: false
    property bool suppressReconnect: false
    property var entityActionStates: ({})

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

    function setConnectionState(status, message) {
        connectionStatus = status;
        connectionMessage = message || "";
        PluginService.setGlobalVar(pluginId, "haConnectionStatus", connectionStatus);
        PluginService.setGlobalVar(pluginId, "haConnectionMessage", connectionMessage);
    }

    function setEntityActionState(entityId, status, action, message, phase) {
        if (!entityId) return;

        var nextStates = Object.assign({}, entityActionStates);
        nextStates[entityId] = {
            status: status,
            action: action || "",
            message: message || "",
            phase: phase || "",
            updatedAt: Date.now()
        };
        entityActionStates = nextStates;
        PluginService.setGlobalVar(pluginId, "haEntityActionStates", entityActionStates);
        entityActionStateChanged(entityId);
        entityDataChanged(entityId);

        if (status === "success" || status === "error") {
            actionStateCleanupTimer.start();
        }
    }

    function clearEntityActionState(entityId) {
        if (!entityId || !entityActionStates[entityId]) return;

        var nextStates = Object.assign({}, entityActionStates);
        delete nextStates[entityId];
        entityActionStates = nextStates;
        PluginService.setGlobalVar(pluginId, "haEntityActionStates", entityActionStates);
        entityActionStateChanged(entityId);
        entityDataChanged(entityId);
    }

    function getEntityActionState(entityId) {
        if (!entityId || !entityActionStates[entityId]) {
            return {
                status: "idle",
                action: "",
                message: "",
                phase: "",
                updatedAt: 0
            };
        }
        return entityActionStates[entityId];
    }

    function formatServiceError(response, fallbackMessage) {
        if (response && response.error) {
            if (response.error.message) return response.error.message;
            if (response.error.code) return String(response.error.code);
        }
        if (typeof response === "string" && response !== "") return response;
        return fallbackMessage || "Request failed";
    }

    function canUseWebSocketApi() {
        return socket && socket.status === root.wsOpen && wsAuthenticated;
    }

    function canAssumeImmediateSuccess(domain) {
        return ["button", "scene", "script", "automation"].indexOf(domain) >= 0;
    }

    // WebSocket Constants (mapped to QtWebSockets values)
    readonly property int wsConnecting: 0
    readonly property int wsOpen: 1
    readonly property int wsClosing: 2
    readonly property int wsClosed: 3
    readonly property int wsError: 4

    property bool missingDependency: false
    property var socket: wsLoader.item

    FileView {
        id: tokenFileView
        path: root.hassTokenPath
        onTextChanged: {
            root._tokenFromFile = tokenFileView.text().trim();
            if (root.hassTokenPath !== "" && root._tokenFromFile === "") {
                console.warn("HomeAssistantMonitor: Token file is empty or could not be read:", root.hassTokenPath);
                root.hassTokenPath = "";
            }
        }
    }

    Timer {
        id: callbackGcTimer
        interval: Components.HassConstants.callbackGcInterval
        running: socket && socket.active
        repeat: true
        onTriggered: {
            const now = Date.now();
            const timeout = Components.HassConstants.callbackTimeout;
            var idsToRemove = [];
            for (var id in wsCallbacks) {
                if (wsCallbacks[id] && (now - wsCallbacks[id].ts > timeout)) {
                    try {
                        if (wsCallbacks[id].cb) wsCallbacks[id].cb({success: false, error: "Timeout"});
                    } catch(e) {
                        console.error("HomeAssistantMonitor: Error in timeout callback:", e);
                    }
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
                    wsAuthenticated = false;
                    haAvailable = false;
                    latency = -1;
                    PluginService.setGlobalVar(pluginId, "latency", -1);
                    PluginService.setGlobalVar(pluginId, "haAvailable", false);  // Notify UI immediately
                    clearCallbacks("WebSocket Error: " + wsLoader.item.errorString);
                    if (suppressReconnect) {
                        setConnectionState("auth_error", connectionMessage || wsLoader.item.errorString);
                    } else {
                        setConnectionState("offline", wsLoader.item.errorString || I18n.tr("WebSocket error", "Home Assistant connection error"));
                        if (!wsLoader.item.reconnectPending)
                            reconnectTimer.start();
                    }
                } else if (status === root.wsClosed) {
                    wsAuthenticated = false;
                    haAvailable = false;
                    latency = -1;
                    PluginService.setGlobalVar(pluginId, "latency", -1);
                    PluginService.setGlobalVar(pluginId, "haAvailable", false);  // Notify UI immediately
                    clearCallbacks("WebSocket Closed");
                    if (suppressReconnect) {
                        setConnectionState("auth_error", connectionMessage || I18n.tr("Authentication failed", "Home Assistant authentication error"));
                        suppressReconnect = false;
                    } else {
                        setConnectionState("offline", I18n.tr("Disconnected from Home Assistant", "Home Assistant connection error"));
                        if (!wsLoader.item.reconnectPending)
                            reconnectTimer.start();
                    }
                } else if (status === root.wsOpen) {
                    currentReconnectInterval = 5000;
                    haAvailable = false;
                    PluginService.setGlobalVar(pluginId, "haAvailable", false);
                    setConnectionState("connecting", I18n.tr("Authenticating with Home Assistant", "Home Assistant connecting state"));
                    reconnectTimer.stop();
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
                // Use the reconnect() method which handles the reconnection properly
                socket.reconnect();

                // Exponential backoff
                root.currentReconnectInterval = Math.min(root.maxReconnectInterval, root.currentReconnectInterval * 1.5);
            }
        }
    }

    Timer {
        id: pingTimer
        interval: Components.HassConstants.wsPingInterval
        repeat: true
        running: false
        onTriggered: {
            if (socket && socket.status === root.wsOpen) {
                root.lastPingTime = Date.now();
                sendWsMessage({ type: "ping" }, (response) => {
                    if (response.type === "pong") {
                        root.latency = Date.now() - root.lastPingTime;
                        PluginService.setGlobalVar(pluginId, "latency", root.latency);
                        setConnectionState(root.latency >= 1000 ? "degraded" : "online",
                                           root.latency >= 1000 ? I18n.tr("Home Assistant connection is slow", "Home Assistant degraded connection") : "");
                    } else if (response && response.success === false) {
                        setConnectionState("degraded", I18n.tr("Home Assistant ping timed out", "Home Assistant degraded connection"));
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

    Timer {
        id: registryRefreshTimer
        interval: 250
        repeat: false
        onTriggered: fetchDevices(true)
    }

    Timer {
        id: allEntitiesPublishTimer
        interval: 100
        repeat: false
        onTriggered: {
            PluginService.setGlobalVar(pluginId, "allEntities", Array.from(cachedAllEntities || []));
            if (allEntitiesStructureDirty) {
                allEntitiesStructureDirty = false;
                allEntitiesStructureChanged();
            }
        }
    }

    Timer {
        id: statesRetryTimer
        interval: root.statesFailureBackoffMs
        repeat: false
        onTriggered: {
            const shouldEmitRefreshCompletion = root.statesPendingRefreshCompletion;
            root.statesRefreshPending = false;
            root.statesPendingRefreshCompletion = false;
            fetchEntities(shouldEmitRefreshCompletion);
        }
    }

    function loadSettings(shouldRefresh) {
        const load = (key, defaultValue) => {
            const val = PluginService.loadPluginData(pluginId, key);
            return val !== undefined ? val : defaultValue;
        }
        const loadState = (key, defaultValue) => {
            if (PluginService.loadPluginState) {
                return PluginService.loadPluginState(pluginId, key, defaultValue);
            }
            return defaultValue;
        }

        hassUrl = normalizeBaseUrl(load("hassUrl", "http://homeassistant.local:8123"));
        _tokenFromSettings = load("hassToken", "").toString().trim();
        hassTokenPath = load("hassTokenPath", "").toString().trim();
        
        entityIds = loadState("entityIds", load("entityIds", ""));
        refreshInterval = load("refreshInterval", 3);
        showAttributes = load("showAttributes", false);

        if (shouldRefresh !== false) {
            refresh();
        }
    }

    function scheduleSettingsReload() {
        if (settingsReloadQueued) {
            return;
        }

        settingsReloadQueued = true;
        Qt.callLater(() => {
            settingsReloadQueued = false;
            loadSettings(true);
        });
    }

    function saveCredentials(url, token) {
        const cleanUrl = normalizeBaseUrl(url);
        const cleanToken = token.toString().trim();
        const tokenPath = hassTokenPath || defaultTokenPath;

        if (!cleanToken) {
            console.warn("HomeAssistantMonitor: Refusing to save an empty token");
            return;
        }

        PluginService.savePluginData(pluginId, "hassUrl", cleanUrl);
        PluginService.savePluginData(pluginId, "hassTokenPath", tokenPath);

        const writeTokenScript = "umask 077; mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1\" && chmod 600 \"$1\"";
        Proc.runCommand(`${pluginId}.saveToken.${Date.now()}`, ["sh", "-c", writeTokenScript, "sh", tokenPath, cleanToken], (stdout, exitCode) => {
            if (exitCode !== 0) {
                console.error("HomeAssistantMonitor: Failed to store the token in", tokenPath);
                return;
            }

            PluginService.savePluginData(pluginId, "hassToken", "");
            scheduleSettingsReload();
        }, 0, 5000);
    }

    // Shortcuts Management
    property var shortcuts: []
    
    ListModel {
        id: shortcutsListModel
    }
    
    property alias shortcutsModel: shortcutsListModel

    function loadShortcuts() {
        var data = loadPersistentPluginValue("shortcuts", []);
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
        savePersistentPluginValue("shortcuts", list);
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
        
        savePersistentPluginValue("shortcuts", list);
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

        savePersistentPluginValue("shortcuts", list);
    }

    function moveShortcut(fromIndex, toIndex) {
        if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return;
        if (fromIndex >= shortcuts.length || toIndex >= shortcuts.length) return;

        var list = Array.from(shortcuts);
        var item = list.splice(fromIndex, 1)[0];
        list.splice(toIndex, 0, item);
        shortcuts = list;

        shortcutsListModel.move(fromIndex, toIndex, 1);

        savePersistentPluginValue("shortcuts", list);
    }

    function isShortcut(entityId) {
        for (var i = 0; i < shortcuts.length; i++) {
            if (shortcuts[i].id === entityId) return true;
        }
        return false;
    }

    Component.onCompleted: {
        loadSettings(false);
        loadShortcuts();
        loadEntityOverrides();
        initialize();
    }

    Connections {
        target: PluginService

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) {
                scheduleSettingsReload();
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

    property var monitoredEntitiesSyncTimer: Timer {
        interval: 16
        running: false
        repeat: false
        onTriggered: {
            persistMonitoredEntityIds();
            reprocessMonitoredEntities();
        }
    }

    onRefreshIntervalChanged: {
        refreshTimer.interval = refreshInterval * 1000;
        if (refreshTimer.running) {
            refreshTimer.restart();
        }
    }

    function initialize() {
        setConnectionState(isConfigured ? "connecting" : "offline",
                           isConfigured
                               ? I18n.tr("Connecting to Home Assistant", "Home Assistant connecting state")
                               : I18n.tr("Configure Home Assistant URL and token", "Home Assistant configuration required"));
        fetchServices();
        fetchDevices();
        refresh(); // Initial fetch via REST to get data immediately
    }

    function refresh() {
        if (canUseWebSocketApi()) {
            // 1. Fetch States
            sendWsMessage({ type: "get_states" }, (response) => {
                if (response.success && Array.isArray(response.result)) {
                    updateAllEntitiesFromWs(response.result);
                    refreshCompleted(true);
                } else {
                    refreshCompleted(false);
                }
            });

            // 2. Refresh metadata together with an explicit state refresh
            if (!servicesLoaded) {
                fetchServices();
            }
            fetchDevices(true);
            fetchTranslations();
        } else {
            fetchEntities(true);
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
            setConnectionState("connecting", I18n.tr("Authenticating with Home Assistant", "Home Assistant connecting state"));
            socket.sendTextMessage(JSON.stringify({
                type: "auth",
                access_token: root.hassToken
            }));
        } else if (data.type === "auth_ok") {
            wsAuthenticated = true;
            haAvailable = true;
            PluginService.setGlobalVar(pluginId, "haAvailable", true);  // Notify UI immediately
            setConnectionState("online", "");
            pingTimer.start();

            // Subscribe to state and registry changes
            sendWsMessage({ type: "subscribe_events", event_type: "state_changed" });
            sendWsMessage({ type: "subscribe_events", event_type: "entity_registry_updated" });
            sendWsMessage({ type: "subscribe_events", event_type: "device_registry_updated" });
            
            // Trigger metadata and state fetch after auth
            Qt.callLater(() => {
                fetchServices();
                fetchTranslations();
                refresh();
                
                // Trigger immediate ping to get initial latency
                root.lastPingTime = Date.now();
                sendWsMessage({ type: "ping" }, (response) => {
                    if (response.type === "pong") {
                        root.latency = Date.now() - root.lastPingTime;
                        PluginService.setGlobalVar(pluginId, "latency", root.latency);
                    } else if (response && response.success === false) {
                        setConnectionState("degraded", I18n.tr("Home Assistant ping timed out", "Home Assistant degraded connection"));
                    }
                });
            });
        } else if (data.type === "auth_invalid") {
            console.error("HomeAssistantMonitor: WebSocket Auth Failed:", data.message);
            wsAuthenticated = false;
            haAvailable = false;
            PluginService.setGlobalVar(pluginId, "haAvailable", false);  // Notify UI immediately
            setConnectionState("auth_error", data.message || I18n.tr("Authentication failed", "Home Assistant authentication error"));
            suppressReconnect = true;
            pingTimer.stop();
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
            } else if (data.event.event_type === "entity_registry_updated"
                       || data.event.event_type === "device_registry_updated") {
                devicesLoaded = false;
                registryRefreshTimer.restart();
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

         for (const entity of allStates) {
             const mapped = mapEntity(entity);
             if (mapped) {
                 allEntities.push(mapped);
             }
         }

         cachedAllEntities = allEntities;
         rebuildCachedEntityIndexes();
         PluginService.setGlobalVar(pluginId, "allEntities", Array.from(allEntities));
         allEntitiesStructureChanged();
         fetchTranslations();
         const monitoredEntities = buildMonitoredEntities(parsedEntityIds, cachedEntityById);

         const newIds = monitoredEntities.map(e => e.entityId).join(",");
         lastMonitoredIdsStr = newIds;

         haAvailable = true;
         setConnectionState("online", "");
         updateEntities(monitoredEntities);
    }

    function processWsEntityUpdate(entity) {
        const mapped = mapEntity(entity);
        if (!mapped) return;

        const entityId = mapped.entityId;
        const actualState = mapped.state;
        clearEntityActionState(entityId);

        // Check if we have a pending confirmation for this entity
        const pendingEntry = pendingConfirmations[entityId];
        if (pendingEntry) {
            upsertCachedEntity(mapped);

            if (String(actualState) === String(pendingEntry.optimisticState)) {
                var resolvedPending = Object.assign({}, pendingConfirmations);
                delete resolvedPending[entityId];
                pendingConfirmations = resolvedPending;

                reconcileOptimisticState(entityId, actualState, mapped.attributes);
                reprocessMonitoredEntities();
                entityDataChanged(entityId);
                return;
            }

            var pending = Object.assign({}, pendingConfirmations);
            pending[entityId].actualState = actualState;
            pending[entityId].actualAttributes = mapped.attributes;
            pendingConfirmations = pending;
            return;
        }

        // No pending confirmation or already confirmed, process normally
        // Check if we have a regular optimistic state for this entity
        const entityOptimisticStates = optimisticStates[entityId];
        const hasOptimisticState = entityOptimisticStates &&
                                  entityOptimisticStates.state !== undefined;

        // Check if the actual state confirms our optimistic state
        if (hasOptimisticState) {
            const optimisticState = entityOptimisticStates.state;
            if (String(actualState) === String(optimisticState)) {
                // Match. Update the cached entity and monitored list first so the UI
                // never briefly falls back to the stale pre-click state.
                upsertCachedEntity(mapped);
                reprocessMonitoredEntities();
                _clearOptimisticState(entityId, "state", false);
                optimisticStateChanged(entityId, "state", optimisticState);
                entityDataChanged(entityId);
                return;
            }
        }

        // Store actual state in cache (not modified by optimistic state)
        upsertCachedEntity(mapped);
        reconcileOptimisticState(entityId, actualState, mapped.attributes);

        // Trigger batch update for monitored list
        batchUpdateTimer.start();
    }

    function reconcileOptimisticState(entityId, actualState, actualAttributes) {
        const entityOptimisticStates = optimisticStates[entityId];
        if (!entityOptimisticStates) {
            return;
        }

        var keysToClear = [];

        if (actualState !== undefined && entityOptimisticStates.state !== undefined) {
            keysToClear.push("state");
        }

        if (actualAttributes !== undefined && actualAttributes !== null) {
            for (var key in actualAttributes) {
                if (entityOptimisticStates[key] !== undefined) {
                    keysToClear.push(key);
                }
            }
        }

        for (var i = 0; i < keysToClear.length; i++) {
            _clearOptimisticState(entityId, keysToClear[i], false);
        }

        if (keysToClear.length > 0) {
            entityDataChanged(entityId);
        }
    }

    function optimisticAttributeMatchesActual(key, optimisticValue, actualAttributes) {
        if (!actualAttributes || optimisticValue === undefined) {
            return false;
        }

        if (actualAttributes[key] !== undefined) {
            return String(actualAttributes[key]) === String(optimisticValue);
        }

        if (key === "color_temp_kelvin" && actualAttributes.color_temp !== undefined) {
            const actualKelvin = Math.round(1000000 / Math.max(1, actualAttributes.color_temp));
            return String(actualKelvin) === String(Math.round(optimisticValue));
        }

        return false;
    }

    // Helper function to clear optimistic state and emit signal
    function _clearOptimisticState(entityId, key, notify) {
        if (!optimisticStates[entityId] || optimisticStates[entityId][key] === undefined) {
            return;
        }

        const shouldNotify = notify !== false;

        var states = Object.assign({}, optimisticStates);
        var timestamps = Object.assign({}, optimisticTimestamps);
        const oldValue = states[entityId][key];

        delete states[entityId][key];
        delete timestamps[entityId][key];

        if (Object.keys(states[entityId]).length === 0) {
            delete states[entityId];
            delete timestamps[entityId];
        }

        optimisticStates = states;
        optimisticTimestamps = timestamps;

        if (shouldNotify) {
            optimisticStateChanged(entityId, key, oldValue);
            entityDataChanged(entityId);  // Unified signal
        }
    }

    function handleWsEntityRemoved(entityId) {
        // Remove from cachedAllEntities
        const oldLen = cachedAllEntities.length;
        cachedAllEntities = cachedAllEntities.filter(e => e.entityId !== entityId);
        
        if (oldLen !== cachedAllEntities.length) {
            rebuildCachedEntityIndexes();
            allEntitiesStructureDirty = true;
            allEntitiesPublishTimer.restart();
            // Trigger batch update to refresh UI lists
            batchUpdateTimer.start();
        }
    }

    // Fetch service definitions for dynamic controls via WebSocket
    function fetchServices() {
        if (servicesLoaded || !canUseWebSocketApi()) return;
        
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

    function hassLanguage() {
        const locale = I18n.currentLocale || Qt.locale().name || "en";
        const normalized = locale.replace("_", "-");
        if (normalized === "zh-CN" || normalized === "zh-Hans-CN" || normalized === "zh")
            return "zh-Hans";
        if (normalized === "zh-TW" || normalized === "zh-HK" || normalized === "zh-Hant")
            return "zh-Hant";
        return normalized;
    }

    function _entityDomains() {
        const domains = [];
        for (let i = 0; i < cachedAllEntities.length; i++) {
            const domain = cachedAllEntities[i].domain || "";
            if (domain && domains.indexOf(domain) < 0)
                domains.push(domain);
        }
        return domains;
    }

    function fetchTranslations(domains) {
        if (!canUseWebSocketApi())
            return;

        const requestedDomains = domains && domains.length > 0 ? domains : _entityDomains();
        const language = hassLanguage();
        for (let i = 0; i < requestedDomains.length; i++) {
            const domain = requestedDomains[i];
            if (!domain || translationDomainsLoaded[domain] || translationDomainsLoading[domain])
                continue;

            var loading = Object.assign({}, translationDomainsLoading);
            loading[domain] = true;
            translationDomainsLoading = loading;

            sendWsMessage({
                type: "frontend/get_translations",
                language: language,
                category: "entity_component",
                integration: domain
            }, (response) => {
                var nextLoading = Object.assign({}, translationDomainsLoading);
                delete nextLoading[domain];
                translationDomainsLoading = nextLoading;

                if (response.success && response.result) {
                    translationsCache = Object.assign({}, translationsCache, response.result.resources || {});
                    var loaded = Object.assign({}, translationDomainsLoaded);
                    loaded[domain] = true;
                    translationDomainsLoaded = loaded;
                    translationsVersion++;
                    translationsChanged();
                    return;
                }
                console.warn("HomeAssistantMonitor: Failed to fetch translations for", domain, response.error ? JSON.stringify(response.error) : "");
            });
        }
    }

    function _translationPath(path) {
        const flatKey = path.join(".");
        if (translationsCache && translationsCache[flatKey] !== undefined)
            return translationsCache[flatKey];

        let node = translationsCache;
        for (let i = 0; i < path.length; i++) {
            if (!node || node[path[i]] === undefined)
                return "";
            node = node[path[i]];
        }
        return typeof node === "string" ? node : "";
    }

    function translateEntityState(domain, state) {
        if (!domain || state === undefined || state === null)
            return state || "";
        fetchTranslations([domain]);
        const value = String(state);
        return _translationPath(["component", domain, "entity_component", "_", "state", value])
            || value;
    }

    function _translationAttributeName(attrName) {
        switch (attrName) {
        case "hvac_modes":
            return "hvac_modes";
        case "fan_modes":
            return "fan_mode";
        case "preset_modes":
            return "preset_mode";
        case "swing_modes":
            return "swing_mode";
        default:
            return attrName;
        }
    }

    function translateAttributeValue(domain, attrName, value) {
        if (!domain || value === undefined || value === null)
            return value || "";
        fetchTranslations([domain]);

        if (domain === "climate" && attrName === "hvac_modes")
            return translateEntityState(domain, value);

        const translated = _translationPath([
            "component",
            domain,
            "entity_component",
            "_",
            "state_attributes",
            _translationAttributeName(attrName),
            "state",
            String(value)
        ]);
        return translated
            || String(value);
    }

    function translateAttributeName(domain, attrName, fallback) {
        fetchTranslations([domain]);
        const translated = _translationPath([
            "component",
            domain,
            "entity_component",
            "_",
            "state_attributes",
            _translationAttributeName(attrName),
            "name"
        ]);
        return translated || fallback || attrName;
    }

    function formatEntityState(domain, state, unitOfMeasurement) {
        const val = state || "?";
        const unit = unitOfMeasurement || "";
        if (unit && val !== "unavailable" && val !== "unknown")
            return val + unit;
        return translateEntityState(domain, val);
    }

    // Get service definition for a specific domain and service
    function getServiceFields(domain, service) {
        if (!servicesCache[domain]) return null;
        const svc = servicesCache[domain][service];
        return svc ? svc.fields : null;
    }

    // Fetch devices and entities registry to build the device mapping via WebSocket
    function fetchDevices(forceRefresh) {
        if (devicesLoading || (!forceRefresh && devicesLoaded) || !canUseWebSocketApi()) return;
        devicesLoading = true;
        
        // 1. Get Device Registry
        sendWsMessage({ type: "config/device_registry/list" }, (devResponse) => {
            if (!devResponse.success) {
                devicesLoading = false;
                console.error("HomeAssistantMonitor: Failed to fetch device registry");
                return;
            }

            // 2. Get Entity Registry
            sendWsMessage({ type: "config/entity_registry/list" }, (entResponse) => {
                if (!entResponse.success) {
                    devicesLoading = false;
                    console.error("HomeAssistantMonitor: Failed to fetch entity registry");
                    return;
                }

                try {
                    const devices = Array.isArray(devResponse.result) ? devResponse.result : [];
                    const entities = Array.isArray(entResponse.result) ? entResponse.result : [];
                    
                    const newDevicesCache = {};
                    devices.forEach(d => {
                        newDevicesCache[d.id] = {
                            name: d.name_by_user || d.name || "Unknown Device",
                            entityIds: []
                        };
                    });

                    const newEntityToDeviceCache = {};

                    entities.forEach(e => {
                        if (e.device_id && newDevicesCache[e.device_id]) {
                            newDevicesCache[e.device_id].entityIds.push(e.entity_id);
                            newEntityToDeviceCache[e.entity_id] = e.device_id;
                        }
                    });

                    devicesCache = newDevicesCache;
                    entityToDeviceCache = newEntityToDeviceCache;
                    devicesLoaded = true;
                    devicesLoading = false;
                    
                } catch (e) {
                    devicesLoading = false;
                    console.error("HomeAssistantMonitor: Failed to process registry data:", e);
                }
            });
        });
    }

    Component {
        id: requestRetryTimerComponent

        Timer {
            repeat: false
        }
    }

    function scheduleRequestRetry(method, endpoint, data, callback, retryCount) {
        const baseDelay = Math.min(10000, 500 * Math.pow(2, retryCount));
        const jitter = Math.floor(Math.random() * 250);
        const retryTimer = requestRetryTimerComponent.createObject(root, {
            interval: baseDelay + jitter
        });

        retryTimer.triggered.connect(() => {
            retryTimer.destroy();
            makeRequest(method, endpoint, data, callback, retryCount + 1);
        });
        retryTimer.start();
    }

    function makeRequest(method, endpoint, data, callback, retryCount = 0) {
        if (!hassUrl || !hassToken) {
            console.warn("HomeAssistantMonitor: Missing URL or Token");
            if (callback) callback(null, -1);
            return;
        }

        const maxRetries = Components.HassConstants.maxRequestRetries;
        var xhr = new XMLHttpRequest();
        var url = hassUrl + endpoint;
        var settled = false;

        function fail(status, statusText) {
            if (settled) {
                return;
            }
            settled = true;

            const retryable = method === "GET" && (status === 0 || status === 408 || status >= 500);
            if (retryCount < maxRetries && retryable) {
                console.warn(`HomeAssistantMonitor: ${method} ${endpoint} failed (${status || "network error"}); retrying ${retryCount + 1}/${maxRetries}`);
                scheduleRequestRetry(method, endpoint, data, callback, retryCount);
                return;
            }

            console.error("HomeAssistantMonitor: Request failed", url, status, statusText || "");
            if (callback) {
                callback(null, status || -1);
            }
        }
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    if (settled) {
                        return;
                    }
                    settled = true;
                    if (callback) callback(xhr.responseText, 0);
                } else {
                    fail(xhr.status, xhr.statusText);
                }
            }
        }
        
        xhr.open(method, url);
        xhr.setRequestHeader("Authorization", "Bearer " + hassToken);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = Components.HassConstants.httpRequestTimeout;
        
        xhr.ontimeout = function() {
            fail(408, "Request timed out");
        }

        xhr.onerror = function() {
            fail(0, "Network error");
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
        if (!hassUrl || !hassToken) {
            if (callback) callback([]);
            return;
        }

        const now = Date.now();
        const cache = historyCache[entityId];

        if (cache && (now - cache.timestamp) < historyCacheDuration) {
            if (callback) callback(cache.data);
            return;
        }

        if (historyRequests[entityId]) {
            if (callback) historyRequests[entityId].push(callback);
            return;
        }
        historyRequests[entityId] = callback ? [callback] : [];

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
                        finishHistoryRequest(entityId, history);
                    } else {
                        console.warn("HomeAssistantMonitor: Unexpected history format from REST API");
                        finishHistoryRequest(entityId, []);
                    }
                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to parse REST history:", e);
                    finishHistoryRequest(entityId, []);
                }
            } else {
                console.error("HomeAssistantMonitor: REST history request failed, exitCode:", exitCode);
                finishHistoryRequest(entityId, []);
            }
        });
    }

    function finishHistoryRequest(entityId, data) {
        const callbacks = historyRequests[entityId] || [];
        delete historyRequests[entityId];
        callbacks.forEach(callback => callback(data));
    }

    // Cache for all entities to avoid re-fetching on local updates
    property var cachedAllEntities: []
    property var cachedEntityById: ({})
    property var cachedEntityIndexes: ({})
    property bool allEntitiesStructureDirty: false

    function parseEntityIds() {
        if (!entityIds || entityIds.trim() === "") {
            return [];
        }
        return entityIds.split(/[,\n]/)
            .map(id => id.trim())
            .filter(id => id.length > 0);
    }

    function fetchEntities(emitRefreshCompletion) {
        const parsedEntityIds = parseEntityIds();
        const shouldEmitRefreshCompletion = emitRefreshCompletion === true;

        if (statesRequestInFlight) {
            statesRefreshPending = true;
            statesPendingRefreshCompletion = statesPendingRefreshCompletion || shouldEmitRefreshCompletion;
            return;
        }

        if (statesRetryTimer.running) {
            statesRefreshPending = true;
            statesPendingRefreshCompletion = statesPendingRefreshCompletion || shouldEmitRefreshCompletion;
            return;
        }

        if (!hassUrl || !hassToken) {
            statesFailureBackoffMs = 0;
            statesRetryTimer.stop();
            updateEntities([]);
            haAvailable = false;
            PluginService.setGlobalVar(pluginId, "haAvailable", false);  // Notify UI immediately
            if (shouldEmitRefreshCompletion) refreshCompleted(false);
            return;
        }

        statesRequestInFlight = true;
        makeRequest("GET", "/api/states", null, (stdout, exitCode) => {
            statesRequestInFlight = false;
            const runPendingRefresh = statesRefreshPending;
            const pendingRefreshCompletion = statesPendingRefreshCompletion;
            statesRefreshPending = false;
            statesPendingRefreshCompletion = false;

            if (exitCode === 0 && stdout) {
                statesFailureBackoffMs = 0;
                statesRetryTimer.stop();
                try {
                    const allStates = JSON.parse(stdout);

                    // Single iteration, process all entities and monitored entities
                    const allEntities = [];

                    for (const entity of allStates) {
                        const mapped = mapEntity(entity);
                        if (mapped) {
                            allEntities.push(mapped);
                        }
                    }

                    cachedAllEntities = allEntities;
                    rebuildCachedEntityIndexes();

                    PluginService.setGlobalVar(pluginId, "allEntities", Array.from(allEntities));
                    allEntitiesStructureChanged();
                    fetchTranslations();
                    const monitoredEntities = buildMonitoredEntities(parsedEntityIds, cachedEntityById);

                    // 2. Only update the "heavy" list model if the structure changed
                    // (length changed or IDs changed)
                    const newIds = monitoredEntities.map(e => e.entityId).join(",");

                    if (lastMonitoredIdsStr !== newIds) {
                        lastMonitoredIdsStr = newIds;
                    }

                    // Always update to ensure data flow, UI ListModel will handle smoothing
                    haAvailable = true;
                    if (!canUseWebSocketApi()) {
                        setConnectionState("degraded", I18n.tr("Using REST fallback", "Home Assistant degraded connection"));
                    }
                    updateEntities(monitoredEntities);
                    if (shouldEmitRefreshCompletion) refreshCompleted(true);

                } catch (e) {
                    console.error("HomeAssistantMonitor: Failed to parse HA response:", e);
                    haAvailable = false;
                    PluginService.setGlobalVar(pluginId, "haAvailable", false);  // Notify UI immediately
                    setConnectionState("offline", I18n.tr("Failed to parse Home Assistant response", "Home Assistant connection error"));
                    // Keep old data, don't clear (consistent with network failure handling)
                    updateEntities(cachedAllEntities);
                    if (shouldEmitRefreshCompletion) refreshCompleted(false);
                }
            } else {
                console.error("HomeAssistantMonitor: Failed to fetch entities");
                // Keep old data, don't clear
                haAvailable = false;
                PluginService.setGlobalVar(pluginId, "haAvailable", false);
                setConnectionState("offline", I18n.tr("Failed to fetch Home Assistant states", "Home Assistant connection error"));
                statesFailureBackoffMs = statesFailureBackoffMs > 0
                    ? Math.min(60000, statesFailureBackoffMs * 2)
                    : 5000;
                statesRetryTimer.restart();
                if (shouldEmitRefreshCompletion) refreshCompleted(false);
            }

            if (runPendingRefresh) {
                if (!statesRetryTimer.running)
                    Qt.callLater(() => fetchEntities(pendingRefreshCompletion));
            }
        });
    }

    function reprocessMonitoredEntities() {
        const parsedEntityIds = parseEntityIds();
        const monitoredEntities = [];

        if (cachedAllEntities && cachedAllEntities.length > 0) {
            monitoredEntities.push(...buildMonitoredEntities(parsedEntityIds, cachedEntityById));
            updateEntities(monitoredEntities);
        } else {
            refresh();
        }
    }

    function updateEntities(entities = []) {
        PluginService.setGlobalVar(pluginId, "entities", entities);
        PluginService.setGlobalVar(pluginId, "entityCount", entities.length);
        PluginService.setGlobalVar(pluginId, "haAvailable", haAvailable);
        PluginService.setGlobalVar(pluginId, "haConnectionStatus", connectionStatus);
        PluginService.setGlobalVar(pluginId, "haConnectionMessage", connectionMessage);
    }

    function scheduleMonitoredEntitiesSync() {
        monitoredEntitiesSyncTimer.restart();
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
            scheduleMonitoredEntitiesSync();
        }
    }

    function removeEntityFromMonitor(entityId) {
        let ids = parseEntityIds();
        const index = ids.indexOf(entityId);
        if (index >= 0) {
            ids.splice(index, 1);
            entityIds = ids.join(", ");

            // Clear history cache for this entity
            const newCache = Object.assign({}, historyCache);
            delete newCache[entityId];
            historyCache = newCache;

            scheduleMonitoredEntitiesSync();
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
        scheduleMonitoredEntitiesSync();
    }

    function moveEntityToTop(entityId) {
        let ids = parseEntityIds();
        const index = ids.indexOf(entityId);
        if (index <= 0) return;

        const item = ids.splice(index, 1)[0];
        ids.unshift(item);

        entityIds = ids.join(", ");
        scheduleMonitoredEntitiesSync();
    }

    function callService(domain, service, entityId, serviceData) {
        if (canUseWebSocketApi()) {
            const msg = {
                type: "call_service",
                domain: domain,
                service: service,
                service_data: serviceData || {}
            };
            
            if (entityId) {
                msg.service_data.entity_id = entityId;
            }

            if (entityId) {
                setEntityActionState(entityId, "pending", service, "", "request");
            }
            
            sendWsMessage(msg, (response) => {
                if (!response || response.success === false) {
                    const errorMessage = formatServiceError(response, "Service call failed");
                    console.error("HomeAssistantMonitor: WebSocket Service call failed:", errorMessage);
                    if (entityId) {
                        setEntityActionState(entityId, "error", service, errorMessage);
                        fetchEntity(entityId);
                    }
                    return;
                }

                if (entityId) {
                    const currentActionState = getEntityActionState(entityId);
                    if (canAssumeImmediateSuccess(domain) || currentActionState.status === "idle") {
                        setEntityActionState(entityId, "success", service, "");
                    } else {
                        setEntityActionState(entityId, "pending", service, "", "sync");
                        // Keep pending until a state_changed event arrives or a later refresh syncs state.
                        actionStateTimeoutTimer.start();
                    }
                }
            });
            return;
        }

        if (!hassUrl || !hassToken) {
            console.error("HomeAssistantMonitor: Cannot call service - HA not configured");
            if (entityId) {
                setEntityActionState(entityId, "error", service, I18n.tr("Home Assistant is not configured", "Entity action error"));
            }
            return;
        }

        const endpoint = `/api/services/${domain}/${service}`;
        const data = serviceData || {};
        data.entity_id = entityId;

        if (entityId) {
            setEntityActionState(entityId, "pending", service, "", "request");
        }

        makeRequest("POST", endpoint, data, (stdout, exitCode) => {
            if (exitCode === 0) {
                if (entityId) {
                    setEntityActionState(entityId, "success", service, "");
                }
                // Refresh only this entity to avoid UI jitter
                fetchEntity(entityId); 
            } else {
                console.error("HomeAssistantMonitor: Service call failed");
                if (entityId) {
                    setEntityActionState(entityId, "error", service, I18n.tr("Service call failed", "Entity action error"));
                    fetchEntity(entityId);
                }
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

    function setColorTemp(entityId, colorTempValue) {
        const cachedEntity = getCachedEntity(entityId);
        const attrs = cachedEntity && cachedEntity.attributes ? cachedEntity.attributes : {};
        const supportsKelvinOnly = (attrs.color_temp_kelvin !== undefined || attrs.min_color_temp_kelvin !== undefined || attrs.max_color_temp_kelvin !== undefined) &&
            (attrs.color_temp === undefined || attrs.color_temp === null);

        if (supportsKelvinOnly) {
            callService("light", "turn_on", entityId, {color_temp_kelvin: Math.round(colorTempValue)});
            return;
        }

        const mireds = Math.round(1000000 / Math.max(1, colorTempValue));
        callService("light", "turn_on", entityId, {color_temp: mireds});
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

    function turnOnClimate(entityId) {
        callService("climate", "turn_on", entityId, {});
    }

    function turnOffClimate(entityId) {
        callService("climate", "turn_off", entityId, {});
    }

    function setPresetMode(entityId, preset) {
        callService("climate", "set_preset_mode", entityId, {preset_mode: preset});
    }

    function setClimateFanMode(entityId, mode) {
        callService("climate", "set_fan_mode", entityId, {fan_mode: mode});
    }

    function setFanSpeed(entityId, percentage) {
        if (percentage > 0) {
            // Use explicit turn_on semantics so HA controls both power state and speed.
            callService("fan", "turn_on", entityId, {percentage: percentage});
            return;
        }

        callService("fan", "turn_off", entityId, {});
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

    // Pending confirmations: entities waiting for a short confirmation window
    // before cached HA values are allowed to override the optimistic state.
    // Structure: { "entityId": { optimisticState: "on", actualState: "off", actualAttributes: {}, timestamp: 123 } }
    property var pendingConfirmations: ({})

    signal optimisticStateChanged(string entityId, string key, var value)
    signal pendingConfirmationResolved(string entityId)  // New signal when 1s passes
    signal entityDataChanged(string entityId)  // Unified signal when any entity data changes
    signal entityActionStateChanged(string entityId)
    signal refreshCompleted(bool success)
    signal translationsChanged()
    signal allEntitiesStructureChanged()

    function setOptimisticState(entityId, key, value) {
        var states = Object.assign({}, optimisticStates);
        var timestamps = Object.assign({}, optimisticTimestamps);

        if (!states[entityId]) states[entityId] = {};
        if (!timestamps[entityId]) timestamps[entityId] = {};

        states[entityId][key] = value;
        timestamps[entityId][key] = Date.now();

        optimisticStates = states;
        optimisticTimestamps = timestamps;

        // For state changes, create or update pending confirmation entry
        if (key === "state") {
            var pending = Object.assign({}, pendingConfirmations);
            var actualState = getActualState(entityId);

            if (pending[entityId]) {
                pending[entityId].optimisticState = value;
                pending[entityId].actualState = actualState;
                pending[entityId].actualAttributes = null;
                pending[entityId].timestamp = Date.now();
            } else {
                pending[entityId] = {
                    optimisticState: value,
                    actualState: actualState,
                    actualAttributes: null,
                    timestamp: Date.now()
                };
            }
            pendingConfirmations = pending;

            // Start the confirmation timer for this entity
            confirmationTimer.start();
        }

        // Emit signal to notify listeners (UI updates immediately with optimistic state)
        optimisticStateChanged(entityId, key, value);
        entityDataChanged(entityId);  // Unified signal
    }

    function getEffectiveValue(entityId, attribute, realValue) {
        // Check pending confirmations first (1s delay period)
        if (pendingConfirmations[entityId]) {
            if (attribute === "state") {
                return pendingConfirmations[entityId].optimisticState;
            }
        }
        // Then check regular optimistic states
        if (optimisticStates[entityId] && optimisticStates[entityId][attribute] !== undefined) {
            return optimisticStates[entityId][attribute];
        }
        return realValue;
    }

    // Get the actual state from cachedAllEntities (without optimistic state)
    function getActualState(entityId) {
        const entity = getCachedEntity(entityId);
        return entity ? entity.state : null;
    }

    // Get complete entity data with all states applied (optimistic, pending confirmation, etc.)
    // This is the unified interface for UI components to get entity data
    function getEntityData(entityId) {
        const base = getCachedEntity(entityId);
        if (!base) return null;

        return {
            entityId: base.entityId,
            state: getEffectiveValue(entityId, "state", base.state),
            domain: base.domain,
            friendlyName: base.friendlyName,
            unitOfMeasurement: base.unitOfMeasurement || "",
            attributes: base.attributes || {},
            lastUpdated: base.lastUpdated
        };
    }

    // Timer to check for pending confirmations that have exceeded the delay
    Timer {
        id: confirmationTimer
        interval: 100  // Check every 100ms
        repeat: true
        running: Object.keys(pendingConfirmations).length > 0

        onTriggered: {
            var now = Date.now();
            var pending = Object.assign({}, pendingConfirmations);
            var changed = false;
            var resolvedEntities = [];
            var overridesToApply = [];

            for (var entityId in pending) {
                var entry = pending[entityId];
                if (now - entry.timestamp >= Components.HassConstants.confirmationDelay) {
                    if (entry.actualState !== undefined &&
                        entry.actualState !== null &&
                        String(entry.actualState) !== String(entry.optimisticState)) {
                        overridesToApply.push({
                            entityId: entityId,
                            actualState: entry.actualState,
                            actualAttributes: entry.actualAttributes
                        });
                    }

                    delete pending[entityId];
                    changed = true;
                    resolvedEntities.push(entityId);
                }
            }

            if (changed) {
                pendingConfirmations = pending;
                for (var j = 0; j < overridesToApply.length; j++) {
                    reconcileOptimisticState(
                        overridesToApply[j].entityId,
                        overridesToApply[j].actualState,
                        overridesToApply[j].actualAttributes
                    );
                }
                if (overridesToApply.length > 0) {
                    reprocessMonitoredEntities();
                }
                // Notify that pending confirmations are resolved
                for (var i = 0; i < resolvedEntities.length; i++) {
                    pendingConfirmationResolved(resolvedEntities[i]);
                }
            }

            if (Object.keys(pendingConfirmations).length === 0) {
                running = false;
                pendingConfirmations = {};
            }
        }
    }

    Timer {
        id: optimisticCleanupTimer
        interval: Components.HassConstants.optimisticCleanupInterval
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
                    if (now - timestamps[id][key] > Components.HassConstants.optimisticStateTimeout) {
                        // Emit signal before clearing
                        const oldValue = states[id][key];
                        optimisticStateChanged(id, key, oldValue);

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

    Timer {
        id: actionStateCleanupTimer
        interval: 300
        repeat: true
        running: false
        onTriggered: {
            const now = Date.now();
            var nextStates = Object.assign({}, entityActionStates);
            var changedIds = [];
            var changed = false;

            for (var entityId in nextStates) {
                const entry = nextStates[entityId];
                if (!entry) continue;
                if ((entry.status === "success" || entry.status === "error") &&
                    now - entry.updatedAt >= 3000) {
                    delete nextStates[entityId];
                    changedIds.push(entityId);
                    changed = true;
                }
            }

            if (changed) {
                entityActionStates = nextStates;
                PluginService.setGlobalVar(pluginId, "haEntityActionStates", entityActionStates);
                for (var i = 0; i < changedIds.length; i++) {
                    entityActionStateChanged(changedIds[i]);
                    entityDataChanged(changedIds[i]);
                }
            }

            if (Object.keys(entityActionStates).length === 0) {
                stop();
            }
        }
    }

    Timer {
        id: actionStateTimeoutTimer
        interval: 500
        repeat: true
        running: false
        onTriggered: {
            const now = Date.now();
            var timedOutIds = [];

            for (var entityId in entityActionStates) {
                const entry = entityActionStates[entityId];
                if (entry && entry.status === "pending" && entry.phase === "sync" && now - entry.updatedAt >= 5000) {
                    timedOutIds.push({
                        entityId: entityId,
                        action: entry.action
                    });
                }
            }

            for (var i = 0; i < timedOutIds.length; i++) {
                setEntityActionState(
                    timedOutIds[i].entityId,
                    "success",
                    timedOutIds[i].action,
                    I18n.tr("Action sent, waiting for Home Assistant state sync", "Entity action status")
                );
            }

            if (Object.keys(entityActionStates).every(function(id) {
                return !(entityActionStates[id].status === "pending" && entityActionStates[id].phase === "sync");
            })) {
                stop();
            }
        }
    }

    // Updates a single entity's state in the local cache and global vars
    // avoiding a full refresh and preventing UI jitter
    function updateEntityState(entityId, newStateStr, newAttributes) {
        const cachedEntity = getCachedEntity(entityId);
        if (cachedEntity) {
            const nextEntity = Object.assign({}, cachedEntity);
            if (newStateStr !== undefined) nextEntity.state = newStateStr;
            if (newAttributes !== undefined) {
                nextEntity.attributes = Object.assign({}, nextEntity.attributes, newAttributes);
            }
            nextEntity.lastUpdated = new Date().toISOString();
            upsertCachedEntity(nextEntity);

            if (optimisticStates[entityId]) {
                if (newStateStr !== undefined && optimisticStates[entityId]["state"] !== undefined) {
                    if (String(optimisticStates[entityId]["state"]) === String(newStateStr)) {
                        _clearOptimisticState(entityId, "state");
                    }
                }

                if (newAttributes !== undefined) {
                    for (var key in newAttributes) {
                        if (optimisticStates[entityId] && optimisticStates[entityId][key] !== undefined) {
                            if (optimisticAttributeMatchesActual(key, optimisticStates[entityId][key], newAttributes)) {
                                _clearOptimisticState(entityId, key);
                            }
                        }
                    }

                    if (optimisticStates[entityId] && optimisticStates[entityId]["color_temp_kelvin"] !== undefined) {
                        if (optimisticAttributeMatchesActual("color_temp_kelvin", optimisticStates[entityId]["color_temp_kelvin"], newAttributes)) {
                            _clearOptimisticState(entityId, "color_temp_kelvin");
                        }
                    }
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
        interval: Components.HassConstants.historyCleanupInterval
        running: true
        repeat: true
        onTriggered: clearOldHistoryCache()
    }
}
