import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"

PluginComponent {
    id: root

    property var expandedEntities: ({})
    property var showEntityDetails: ({})
    property bool showAttributes: pluginData.showAttributes !== undefined ? pluginData.showAttributes : true
    property var pinnedEntities: []
    property var customIcons: ({})

    // Cache for status bar - use computed properties to ensure proper scope
    readonly property var cachedGlobalEntities: globalEntities.value || []
    readonly property var cachedPinnedEntities: pinnedEntities

    property string selectedEntityId: ""
    property string iconPickerEntityId: ""
    property string iconSearchText: ""
    property bool keyboardNavigationActive: false
    property var entityListView: null
    property bool showEntityBrowser: false
    property string entitySearchText: ""
    property var pendingMonitorOperations: ({})
    readonly property int compactPopoutWidth: 420
    readonly property int compactContentWidth: compactPopoutWidth - Theme.spacingM * 2
    readonly property int rightColumnWidth: compactContentWidth
    readonly property int browserColumnWidth: 360
    readonly property int expandedPopoutWidth: rightColumnWidth + browserColumnWidth + Theme.spacingS + Theme.spacingM * 2

    property bool isEditing: false // Global edit mode state
    property bool manualRefreshInProgress: false

    Ref {
        service: HomeAssistantService
    }

    function loadPersistentUiValue(key, fallbackValue) {
        if (pluginService && pluginService.loadPluginState) {
            const stateValue = pluginService.loadPluginState("homeAssistantMonitor", key, undefined);
            if (stateValue !== undefined) {
                return stateValue;
            }
        }

        const pluginValue = pluginData[key];
        return pluginValue !== undefined ? pluginValue : fallbackValue;
    }

    function savePersistentUiValue(key, value) {
        if (pluginService && pluginService.savePluginState) {
            pluginService.savePluginState("homeAssistantMonitor", key, value);
            return;
        }
        if (pluginService) {
            pluginService.savePluginData("homeAssistantMonitor", key, value);
        }
    }

    function loadPersistentUiPreference(key, fallbackValue) {
        const pluginValue = pluginData[key];
        if (pluginValue !== undefined) {
            return pluginValue;
        }

        if (pluginService && pluginService.loadPluginState) {
            const stateValue = pluginService.loadPluginState("homeAssistantMonitor", key, undefined);
            if (stateValue !== undefined) {
                pluginService.savePluginData("homeAssistantMonitor", key, stateValue);
                return stateValue;
            }
        }

        return fallbackValue;
    }

    function savePersistentUiPreference(key, value) {
        if (pluginService) {
            pluginService.savePluginData("homeAssistantMonitor", key, value);
        }
    }

    function updatePinnedEntities(nextPinned) {
        pinnedEntities = nextPinned;
        savePersistentUiPreference("pinnedEntities", nextPinned);
    }

    function removePinnedEntity(entityId) {
        const nextPinned = pinnedEntities.filter(id => id !== entityId);
        if (nextPinned.length !== pinnedEntities.length) {
            updatePinnedEntities(nextPinned);
        }
    }

    function buildEntityMap(entities) {
        const entityMap = {};
        for (const entity of entities || []) {
            entityMap[entity.entityId] = entity;
        }
        return entityMap;
    }

    function matchesEntitySearch(entity, searchLower, extraText) {
        if (!searchLower) {
            return true;
        }

        const friendlyName = entity && entity.friendlyName ? entity.friendlyName.toLowerCase() : "";
        const entityId = entity && entity.entityId ? entity.entityId.toLowerCase() : "";
        const supplemental = extraText ? extraText.toLowerCase() : "";

        return friendlyName.includes(searchLower) ||
            entityId.includes(searchLower) ||
            supplemental.includes(searchLower);
    }

    function queueMonitorOperation(entityId, shouldMonitor) {
        const nextOperations = Object.assign({}, pendingMonitorOperations);
        nextOperations[entityId] = shouldMonitor;
        pendingMonitorOperations = nextOperations;
        monitorOperationTimer.restart();
    }

    function cleanupPinnedEntities() {
        // Only cleanup if we actually have entity data
        // Don't cleanup when service is unavailable (empty entities)
        var entities = globalEntities.value || [];

        // Skip cleanup if entities list is empty (service unavailable or still loading)
        if (entities.length === 0) {
            return;
        }

        var entityIds = entities.map(function(e) { return e.entityId; });
        var pinned = pinnedEntities.filter(function(id) {
            return entityIds.indexOf(id) >= 0;
        });

        if (pinned.length !== pinnedEntities.length) {
            updatePinnedEntities(pinned);
        }
    }

    function syncPinnedEntitiesFromStorage() {
        const persistedPinned = loadPersistentUiPreference("pinnedEntities", []);
        if (JSON.stringify(persistedPinned) !== JSON.stringify(pinnedEntities)) {
            pinnedEntities = persistedPinned;
        }
    }

    PluginGlobalVar {
        id: globalHaAvailable
        varName: "haAvailable"
        defaultValue: false
    }

    PluginGlobalVar {
        id: globalEntities
        varName: "entities"
        defaultValue: []
    }

    PluginGlobalVar {
        id: globalEntityCount
        varName: "entityCount"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: globalLatency
        varName: "latency"
        defaultValue: -1
    }

    PluginGlobalVar {
        id: globalConnectionStatus
        varName: "haConnectionStatus"
        defaultValue: "offline"
    }

    PluginGlobalVar {
        id: globalConnectionMessage
        varName: "haConnectionMessage"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: globalAllEntities
        varName: "allEntities"
        defaultValue: []
    }

    Connections {
        target: globalEntities
        function onValueChanged() {
            cleanupPinnedEntities();
            syncSelectionState();
        }
    }

    Connections {
        target: HomeAssistantService
        function onRefreshCompleted(success) {
            root.manualRefreshInProgress = false;
        }
    }

    onPluginDataChanged: {
        syncPinnedEntitiesFromStorage();
    }

    Component.onCompleted: {
        syncPinnedEntitiesFromStorage();
        customIcons = loadPersistentUiValue("customIcons", ({}));
        cleanupPinnedEntities();
        syncSelectionState();
    }

    function toggleEntity(entityId) {
        var expanded = Object.assign({}, root.expandedEntities);
        expanded[entityId] = !expanded[entityId];
        root.expandedEntities = expanded;
    }

    function toggleEntityDetails(entityId) {
        var details = Object.assign({}, root.showEntityDetails);
        details[entityId] = !details[entityId];
        root.showEntityDetails = details;
    }

    function collapseAllEntities() {
        root.expandedEntities = ({});
        root.showEntityDetails = ({});
    }

    function syncSelectionState() {
        const entities = globalEntities.value || [];
        if (!entities.length) {
            selectedEntityId = "";
            keyboardNavigationActive = false;
            return;
        }

        if (!selectedEntityId) {
            return;
        }

        const exists = entities.some(function(entity) {
            return entity.entityId === selectedEntityId;
        });

        if (!exists) {
            selectedEntityId = "";
            keyboardNavigationActive = false;
        }
    }

    function resetPopoutState() {
        root.collapseAllEntities();
        root.closeIconPicker();
        root.isEditing = false;
        root.showEntityBrowser = false;
        root.entitySearchText = "";
        root.selectedEntityId = "";
        root.keyboardNavigationActive = false;
    }

    function toggleEntityBrowser() {
        root.showEntityBrowser = !root.showEntityBrowser;
        if (!root.showEntityBrowser) {
            root.closeIconPicker();
            root.entitySearchText = "";
        }
    }

    function togglePinEntity(entityId) {
        var pinned = Array.from(pinnedEntities);
        var index = pinned.indexOf(entityId);

        if (index < 0) {
            pinned.push(entityId);
        } else {
            pinned.splice(index, 1);
        }

        updatePinnedEntities(pinned);
    }

    function isPinned(entityId) {
        return pinnedEntities.includes(entityId);
    }

    readonly property var pinnedEntitiesData: {
        const entities = globalEntities.value || [];
        const entityMap = buildEntityMap(entities);
        return pinnedEntities.map(id => entityMap[id]).filter(e => e !== undefined);
    }

    readonly property var monitoredEntityIds: {
        const list = globalEntities.value || [];
        return list.map(e => e.entityId);
    }

    // Debounced search text
    property string debouncedSearchText: ""
    
    Timer {
        id: searchDebounceTimer
        interval: 200
        repeat: false
        onTriggered: root.debouncedSearchText = root.entitySearchText
    }

    Timer {
        id: monitorOperationTimer
        interval: 16
        repeat: false
        onTriggered: {
            const operations = pendingMonitorOperations;
            pendingMonitorOperations = ({});

            for (const entityId in operations) {
                const shouldMonitor = !!operations[entityId];

                if (!shouldMonitor) {
                    removePinnedEntity(entityId);
                    HomeAssistantService.removeEntityFromMonitor(entityId);
                } else {
                    HomeAssistantService.addEntityToMonitor(entityId);
                }
            }
        }
    }
    
    onEntitySearchTextChanged: {
        searchDebounceTimer.restart();
    }
    
    readonly property var entityDomains: {
        const entities = globalAllEntities.value || [];
        const searchLower = debouncedSearchText.toLowerCase().trim();
        const filteredEntities = searchLower ? entities.filter(e => matchesEntitySearch(e, searchLower, "")) : entities;

        const domains = {};
        for (let i = 0; i < filteredEntities.length; i++) {
            const entity = filteredEntities[i];
            const domain = entity.domain || "other";
            if (!domains[domain]) {
                domains[domain] = [];
            }
            domains[domain].push(entity);
        }

        return Object.keys(domains).sort().map(domain => {
            return {
                name: domain,
                entities: domains[domain].sort((a, b) => {
                    return a.friendlyName.localeCompare(b.friendlyName);
                })
            };
        });
    }

    // Browse mode: "domain" or "device"
    property string browseMode: "device"

    // Entity grouping by device
    readonly property var entityDevices: {
        const devicesCache = HomeAssistantService.devicesCache || {};
        const allEntities = globalAllEntities.value || [];
        const searchLower = debouncedSearchText.toLowerCase().trim();
        const entityMap = buildEntityMap(allEntities);

        const devices = [];
        const sortedDeviceNames = Object.keys(devicesCache).sort((a, b) => a.localeCompare(b));

        for (const deviceName of sortedDeviceNames) {
            const entityIds = devicesCache[deviceName] || [];
            const deviceEntities = entityIds
                .map(id => entityMap[id])
                .filter(e => e !== undefined)
                .filter(e => matchesEntitySearch(e, searchLower, deviceName))
                .sort((a, b) => a.friendlyName.localeCompare(b.friendlyName));

            if (deviceEntities.length > 0) {
                devices.push({
                    name: deviceName,
                    entities: deviceEntities,
                    entityCount: entityIds.length
                });
            }
        }

        return devices;
    }



    function isEntityMonitored(entityId) {
        const entities = globalEntities.value || [];
        return entities.some(e => e.entityId === entityId);
    }

    function moveSelection(offset) {
        const entities = globalEntities.value || [];
        if (!entities.length) {
            return;
        }

        if (!keyboardNavigationActive || !selectedEntityId) {
            keyboardNavigationActive = true;
            selectedEntityId = entities[0].entityId;
            return;
        }

        const currentIndex = entities.findIndex(function(e) { return e.entityId === selectedEntityId; });
        if (currentIndex < 0) {
            selectedEntityId = entities[0].entityId;
            return;
        }

        const nextIndex = Math.max(0, Math.min(entities.length - 1, currentIndex + offset));
        if (nextIndex !== currentIndex) {
            selectedEntityId = entities[nextIndex].entityId;
            ensureVisible();
        }
    }

    function toggleMonitorEntity(entityId) {
        const isMonitored = isEntityMonitored(entityId);
        queueMonitorOperation(entityId, !isMonitored);
    }

    function selectNext() {
        moveSelection(1);
    }

    function selectPrevious() {
        moveSelection(-1);
    }

    function toggleSelected() {
        if (selectedEntityId) {
            toggleEntity(selectedEntityId);
        }
    }

    function ensureVisible() {
        if (!selectedEntityId || !entityListView) return;

        Qt.callLater(function() {
            var entities = globalEntities.value || [];
            var index = entities.findIndex(function(e) { return e.entityId === selectedEntityId; });
            if (index >= 0) {
                const hasShortcuts = HomeAssistantService.shortcutsModel.count > 0 || root.isEditing;
                const listIndex = hasShortcuts ? index + 1 : index;
                entityListView.positionViewAtIndex(listIndex, ListView.Contain);
            }
        });
    }

    function refreshEntities() {
        if (root.manualRefreshInProgress) return;
        root.manualRefreshInProgress = true;
        // Increment refresh counter to reset entity card expand caches
        var currentCounter = pluginData.haRefreshCounter || 0;
        if (pluginService) {
            pluginService.savePluginData("homeAssistantMonitor", "haRefreshCounter", currentCounter + 1);
        }
        HomeAssistantService.refresh();
        ToastService.showInfo(I18n.tr("Refreshing Home Assistant entities...", "Entity refresh notification"));
    }

    function setEntityIcon(entityId, iconName) {
        var icons = Object.assign({}, customIcons);
        if (iconName) {
            icons[entityId] = iconName;
        } else {
            delete icons[entityId];
        }
        customIcons = icons;
        savePersistentUiValue("customIcons", icons);
    }

    function openIconPicker(entityId) {
        iconPickerEntityId = entityId;
        iconSearchText = "";
    }

    function closeIconPicker() {
        iconPickerEntityId = "";
        iconSearchText = "";
    }

    horizontalBarPill: StatusBarContent {
        orientation: Qt.Horizontal
        haAvailable: globalHaAvailable.value
        connectionStatus: globalConnectionStatus.value
        connectionMessage: globalConnectionMessage.value
        entityCount: globalEntityCount.value
        globalEntities: root.cachedGlobalEntities
        pinnedEntityIds: root.cachedPinnedEntities
        customIcons: root.customIcons
        barThickness: root.barThickness
        showHomeIcon: pluginData.showHomeIcon !== undefined ? pluginData.showHomeIcon : true
        showButtonsOnStatusBar: pluginData.showButtonsOnStatusBar !== undefined ? pluginData.showButtonsOnStatusBar : true
    }

    verticalBarPill: StatusBarContent {
        orientation: Qt.Vertical
        haAvailable: globalHaAvailable.value
        connectionStatus: globalConnectionStatus.value
        connectionMessage: globalConnectionMessage.value
        entityCount: globalEntityCount.value
        globalEntities: root.cachedGlobalEntities
        pinnedEntityIds: root.cachedPinnedEntities
        customIcons: root.customIcons
        barThickness: root.barThickness
        showHomeIcon: pluginData.showHomeIcon !== undefined ? pluginData.showHomeIcon : true
        showButtonsOnStatusBar: pluginData.showButtonsOnStatusBar !== undefined ? pluginData.showButtonsOnStatusBar : true
    }

    popoutContent: Component {
        FocusScope {
            id: popoutScope
            implicitWidth: root.showEntityBrowser ? root.expandedPopoutWidth : root.compactPopoutWidth
            implicitHeight: 600
            focus: true
            
            // Content is immediately ready - no delay to avoid blank screen
            // Performance is handled via ListView cacheBuffer and lazy Loaders
            property bool contentReady: true

            property var parentPopout: null

            Component.onCompleted: {
                Qt.callLater(() => {
                    forceActiveFocus();
                });
            }

            Connections {
                target: parentPopout
                function onShouldBeVisibleChanged() {
                    if (parentPopout && !parentPopout.shouldBeVisible) {
                        root.resetPopoutState();
                    }
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) ||
                    (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier)) {
                    root.selectNext();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) ||
                    (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier)) {
                    root.selectPrevious();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab) {
                    root.selectNext();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab) {
                    root.selectPrevious();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.toggleSelected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_R && event.modifiers & Qt.ControlModifier) {
                    root.refreshEntities();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape && root.iconPickerEntityId) {
                    root.closeIconPicker();
                    event.accepted = true;
                }
            }

            Column {
                id: popoutColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                HomeAssistantOverviewPanel {
                    id: overviewPanel
                    width: contentFrame.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    haAvailable: globalHaAvailable.value
                    connectionStatus: globalConnectionStatus.value
                    connectionMessage: globalConnectionMessage.value
                    isEditing: root.isEditing
                    showEntityBrowser: root.showEntityBrowser
                    manualRefreshInProgress: root.manualRefreshInProgress

                    onRequestToggleEditing: root.isEditing = !root.isEditing
                    onRequestToggleBrowser: root.toggleEntityBrowser()
                    onRequestRefresh: root.refreshEntities()
                }

                Item {
                    id: contentFrame
                    width: root.showEntityBrowser
                        ? root.browserColumnWidth + Theme.spacingS + root.rightColumnWidth
                        : root.compactContentWidth
                    height: parent.height - overviewPanel.height - Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        id: contentRow
                        anchors.fill: parent
                        spacing: Theme.spacingS

                        Item {
                            width: root.showEntityBrowser ? root.browserColumnWidth : 0
                            height: parent.height
                            visible: root.showEntityBrowser

                            HomeAssistantBrowserPane {
                                anchors.fill: parent
                                visiblePane: root.showEntityBrowser
                                contentReady: popoutScope.contentReady
                                browseMode: root.browseMode
                                searchText: root.entitySearchText
                                deviceModel: root.entityDevices
                                domainModel: root.entityDomains
                                monitoredEntityIds: root.monitoredEntityIds

                                onRequestToggleMonitor: entityId => root.toggleMonitorEntity(entityId)
                                onRequestBrowseModeChange: mode => root.browseMode = mode
                                onRequestSearchTextChange: text => root.entitySearchText = text
                            }
                        }

                        HomeAssistantEntityListPane {
                            id: rightColumn
                            width: root.rightColumnWidth
                            height: parent.height
                            entities: globalEntities.value || []
                            haAvailable: !!globalHaAvailable.value
                            globalEntityCount: globalEntityCount.value !== undefined ? globalEntityCount.value : 0
                            connectionStatus: globalConnectionStatus.value || "offline"
                            connectionMessage: globalConnectionMessage.value || ""
                            contentReady: popoutScope.contentReady
                            isEditing: root.isEditing
                            keyboardNavigationActive: root.keyboardNavigationActive
                            selectedEntityId: root.selectedEntityId
                            pinnedEntityIds: root.pinnedEntities
                            expandedEntities: root.expandedEntities
                            showEntityDetails: root.showEntityDetails
                            showAttributes: root.showAttributes
                            customIcons: root.customIcons

                            onRequestListView: listView => root.entityListView = listView
                            onRequestToggleExpand: entityId => root.toggleEntity(entityId)
                            onRequestTogglePin: entityId => root.togglePinEntity(entityId)
                            onRequestToggleDetails: entityId => root.toggleEntityDetails(entityId)
                            onRequestRemoveEntity: entityId => HomeAssistantService.removeEntityFromMonitor(entityId)
                            onRequestOpenIconPicker: entityId => root.openIconPicker(entityId)
                        }
                    }
                }
            }

            HomeAssistantDependencyOverlay {
                missingDependency: HomeAssistantService.missingDependency
            }

            HomeAssistantIconPickerOverlay {
                entityId: root.iconPickerEntityId
                searchText: root.iconSearchText
                customIcons: root.customIcons
                availableIcons: HassConstants.commonIcons

                onSearchTextChanged: root.iconSearchText = searchText
                onRequestSetIcon: (entityId, iconName) => root.setEntityIcon(entityId, iconName)
                onRequestResetIcon: entityId => root.setEntityIcon(entityId, null)
                onRequestClose: root.closeIconPicker()
            }
        }
    }

    popoutWidth: root.showEntityBrowser ? root.expandedPopoutWidth : root.compactPopoutWidth
    popoutHeight: 600
}
