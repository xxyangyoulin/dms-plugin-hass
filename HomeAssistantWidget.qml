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
    property var pinnedEntities: pluginData.pinnedEntities || []
    property var customIcons: pluginData.customIcons || ({})

    // Cache for status bar - use computed properties to ensure proper scope
    readonly property var cachedGlobalEntities: globalEntities.value || []
    readonly property var cachedPinnedEntities: pinnedEntities

    property string selectedEntityId: ""
    property string iconPickerEntityId: ""
    property string iconSearchText: ""
    property bool keyboardNavigationActive: false
    property var entityListView: null
    property var entityListRepeater: null
    property bool showEntityBrowser: false
    property string entitySearchText: ""
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
            pinnedEntities = pinned;
            if (pluginService) {
                pluginService.savePluginData("homeAssistantMonitor", "pinnedEntities", pinned);
            }
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

    ListModel {
        id: monitoredListModel
    }

    // Track last sync state to avoid redundant operations
    property string _lastSyncHash: ""

    function syncMonitoredList() {
        const entities = globalEntities.value || [];

        // Get optimistic states from HomeAssistantService
        const optimisticStates = HomeAssistantService.optimisticStates || {};

        // Fast path: check if any changes at all (quick hash check)
        // Include optimistic states in hash to detect relevant changes
        const optimisticKeys = Object.keys(optimisticStates).sort();
        const optimisticHash = optimisticKeys.map(id => `${id}:${JSON.stringify(optimisticStates[id])}`).join("|");
        const newHash = entities.map(e => `${e.entityId}:${e.state}:${e.friendlyName}:${e.lastUpdated}`).join(",") + "|" + optimisticHash;
        if (newHash === _lastSyncHash && monitoredListModel.count === entities.length) {
            return;
        }
        _lastSyncHash = newHash;
        
        // Use smart diffing for incremental updates
        const currentIds = [];
        for (let i = 0; i < monitoredListModel.count; i++) {
            currentIds.push(monitoredListModel.get(i).entityId);
        }
        
        const newIds = entities.map(e => e.entityId);
        
        // Just update values, no structural change
        if (JSON.stringify(currentIds) === JSON.stringify(newIds)) {
            for (let i = 0; i < entities.length; i++) {
                const entity = entities[i];
                // Apply optimistic state overrides if present
                const entityOptimisticStates = optimisticStates[entity.entityId];
                if (entityOptimisticStates) {
                    // Create a copy with optimistic states applied
                    const updatedEntity = Object.assign({}, entity);
                    for (const key in entityOptimisticStates) {
                        if (key === "state") {
                            updatedEntity.state = entityOptimisticStates[key];
                        } else if (updatedEntity.attributes) {
                            // For attributes, we need to merge them
                            updatedEntity.attributes = Object.assign({}, updatedEntity.attributes);
                            updatedEntity.attributes[key] = entityOptimisticStates[key];
                        }
                    }
                    monitoredListModel.set(i, updatedEntity);
                } else {
                    monitoredListModel.set(i, entity);
                }
            }
            return;
        }
        
        // Full rebuild
        monitoredListModel.clear();
        for (const ent of entities) {
            // Apply optimistic state overrides if present
            const entityOptimisticStates = optimisticStates[ent.entityId];
            if (entityOptimisticStates) {
                // Create a copy with optimistic states applied
                const updatedEntity = Object.assign({}, ent);
                for (const key in entityOptimisticStates) {
                    if (key === "state") {
                        updatedEntity.state = entityOptimisticStates[key];
                    } else if (updatedEntity.attributes) {
                        // For attributes, we need to merge them
                        updatedEntity.attributes = Object.assign({}, updatedEntity.attributes);
                        updatedEntity.attributes[key] = entityOptimisticStates[key];
                    }
                }
                monitoredListModel.append(updatedEntity);
            } else {
                monitoredListModel.append(ent);
            }
        }
    }

    Connections {
        target: globalEntities
        function onValueChanged() {
            cleanupPinnedEntities();
            syncMonitoredList();
        }
    }

    Connections {
        target: HomeAssistantService
        function onEntityDataChanged(entityId) {
            // Get the latest entity data from HomeAssistantService
            const entityData = HomeAssistantService.getEntityData(entityId);
            if (!entityData) return;

            // Update the entity in the ListModel
            for (var i = 0; i < monitoredListModel.count; i++) {
                var current = monitoredListModel.get(i);
                if (current.entityId === entityId) {
                    monitoredListModel.set(i, {
                        entityId: entityData.entityId,
                        domain: entityData.domain,
                        state: entityData.state,
                        friendlyName: entityData.friendlyName,
                        unitOfMeasurement: entityData.unitOfMeasurement || "",
                        attributes: entityData.attributes || {}
                    });
                    break;
                }
            }
        }
    }

    Connections {
        target: HomeAssistantService
        function onPendingConfirmationResolved(entityId) {
            // 1 second passed, sync to ensure UI shows actual state
            syncMonitoredList();
        }
    }

    Connections {
        target: HomeAssistantService
        function onRefreshCompleted(success) {
            root.manualRefreshInProgress = false;
        }
    }

    Component.onCompleted: {
        cleanupPinnedEntities();
        // Initial sync in case globalEntities already has data
        syncMonitoredList();
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

    function togglePinEntity(entityId) {
        var pinned = Array.from(pinnedEntities);
        var index = pinned.indexOf(entityId);
        var isPinning = index < 0;

        if (isPinning) {
            pinned.push(entityId);
        } else {
            pinned.splice(index, 1);
        }

        pinnedEntities = pinned;
        if (pluginService) {
            pluginService.savePluginData("homeAssistantMonitor", "pinnedEntities", pinned);
        }

        ToastService.showInfo(I18n.tr(
            isPinning ? "Pinned to status bar" : "Unpinned from status bar",
            "Entity pin status notification"
        ));
    }

    function isPinned(entityId) {
        return pinnedEntities.includes(entityId);
    }

    readonly property var pinnedEntitiesData: {
        const entities = globalEntities.value || [];
        const entityMap = {};
        for (let i = 0; i < entities.length; i++) {
            entityMap[entities[i].entityId] = entities[i];
        }
        return pinnedEntities.map(id => entityMap[id]).filter(e => e !== undefined);
    }

    // Debounced search text
    property string debouncedSearchText: ""
    
    Timer {
        id: searchDebounceTimer
        interval: 200
        repeat: false
        onTriggered: root.debouncedSearchText = root.entitySearchText
    }
    
    onEntitySearchTextChanged: {
        searchDebounceTimer.restart();
    }
    
    readonly property var entityDomains: {
        const entities = globalAllEntities.value || [];
        const searchLower = debouncedSearchText.toLowerCase().trim();

        const filteredEntities = searchLower
            ? entities.filter(e => {
                return (e.friendlyName && e.friendlyName.toLowerCase().includes(searchLower)) ||
                       (e.entityId && e.entityId.toLowerCase().includes(searchLower));
            })
            : entities;

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

        // Create entity lookup map
        const entityMap = {};
        for (const entity of allEntities) {
            entityMap[entity.entityId] = entity;
        }

        // Build device list with expanded entities
        const devices = [];
        const sortedDeviceNames = Object.keys(devicesCache).sort((a, b) => a.localeCompare(b));

        for (const deviceName of sortedDeviceNames) {
            const entityIds = devicesCache[deviceName] || [];
            const deviceEntities = entityIds
                .map(id => entityMap[id])
                .filter(e => e !== undefined)
                .filter(e => {
                    if (!searchLower) return true;
                    return (e.friendlyName && e.friendlyName.toLowerCase().includes(searchLower)) ||
                           (e.entityId && e.entityId.toLowerCase().includes(searchLower)) ||
                           deviceName.toLowerCase().includes(searchLower);
                })
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

    function toggleMonitorEntity(entityId) {
        const isMonitored = isEntityMonitored(entityId);

        if (isMonitored) {
            const pinned = pinnedEntities.filter(id => id !== entityId);
            if (pinned.length !== pinnedEntities.length) {
                pinnedEntities = pinned;
                if (pluginService) {
                    pluginService.savePluginData("homeAssistantMonitor", "pinnedEntities", pinned);
                }
            }
            HomeAssistantService.removeEntityFromMonitor(entityId);
        } else {
            HomeAssistantService.addEntityToMonitor(entityId);
        }

        ToastService.showInfo(I18n.tr(
            isMonitored ? "Entity removed from monitoring" : "Entity added to monitoring",
            "Entity monitoring notification"
        ));
    }

    function selectNext() {
        var entities = globalEntities.value || [];
        if (!entities.length) return;

        if (!keyboardNavigationActive) {
            keyboardNavigationActive = true;
            selectedEntityId = entities[0].entityId;
            return;
        }

        var currentIndex = entities.findIndex(function(e) { return e.entityId === selectedEntityId; });
        if (currentIndex < entities.length - 1) {
            selectedEntityId = entities[currentIndex + 1].entityId;
            ensureVisible();
        }
    }

    function selectPrevious() {
        var entities = globalEntities.value || [];
        if (!entities.length) return;

        if (!keyboardNavigationActive) {
            keyboardNavigationActive = true;
            selectedEntityId = entities[0].entityId;
            return;
        }

        var currentIndex = entities.findIndex(function(e) { return e.entityId === selectedEntityId; });
        if (currentIndex > 0) {
            selectedEntityId = entities[currentIndex - 1].entityId;
            ensureVisible();
        }
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
                if (entityListView.positionViewAtIndex) {
                    entityListView.positionViewAtIndex(index, ListView.Contain);
                    return;
                }

                if (entityListRepeater && entityListRepeater.itemAt) {
                    var item = entityListRepeater.itemAt(index);
                    if (!item) return;

                    var itemTop = item.y;
                    var itemBottom = item.y + item.height;
                    var viewportTop = entityListView.contentY;
                    var viewportBottom = entityListView.contentY + entityListView.height;

                    if (itemTop < viewportTop) {
                        entityListView.contentY = itemTop;
                    } else if (itemBottom > viewportBottom) {
                        entityListView.contentY = itemBottom - entityListView.height;
                    }
                }
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

    function getEntityIcon(entityId, domain) {
        return customIcons[entityId] || HassConstants.getIconForDomain(domain);
    }

    function setEntityIcon(entityId, iconName) {
        var icons = Object.assign({}, customIcons);
        if (iconName) {
            icons[entityId] = iconName;
        } else {
            delete icons[entityId];
        }
        customIcons = icons;
        if (pluginService) {
            pluginService.savePluginData("homeAssistantMonitor", "customIcons", icons);
        }
    }

    function openIconPicker(entityId) {
        iconPickerEntityId = entityId;
        iconSearchText = "";
    }

    function closeIconPicker() {
        iconPickerEntityId = "";
        iconSearchText = "";
    }

    function isSwitchable(entity) {
        if (!entity) return false;
        const domain = entity.domain;
        const switchableDomains = ["switch", "light", "input_boolean", "fan", "automation", "script", "group", "climate"];
        return switchableDomains.includes(domain);
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

    // Lazy-loaded popout content for better performance
    property bool popoutReady: false
    
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
                        root.collapseAllEntities();
                        root.showEntityBrowser = false;
                        root.entitySearchText = "";
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
                }
            }

            Column {
                id: popoutColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Rectangle {
                    id: overviewPanel
                    width: contentFrame.width
                    height: overviewContent.implicitHeight + Theme.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: Theme.cornerRadius * 1.2
                    color: Theme.surfaceContainerHigh || Theme.surfaceContainer
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.16)

                    readonly property color statusColor: {
                        if (globalConnectionStatus.value === "auth_error" || globalConnectionStatus.value === "offline") return Theme.error;
                        if (globalConnectionStatus.value === "connecting" || globalConnectionStatus.value === "degraded") return Theme.warning;
                        if (!globalHaAvailable.value) return Theme.error;
                        return Theme.primary;
                    }

                    readonly property string titleText: {
                        if (globalConnectionStatus.value === "auth_error") return I18n.tr("Home Assistant authentication failed", "Home Assistant connection error");
                        if (globalConnectionStatus.value === "connecting") return I18n.tr("Connecting to Home Assistant", "Home Assistant status");
                        if (globalConnectionStatus.value === "degraded") return I18n.tr("Home Assistant connection degraded", "Home Assistant status");
                        if (!globalHaAvailable.value) return I18n.tr("Home Assistant unavailable", "Home Assistant connection error");
                        return I18n.tr("Home Assistant", "Home Assistant dashboard title");
                    }

                    readonly property string subtitleText: {
                        if (globalConnectionStatus.value === "auth_error") {
                            return I18n.tr("Update the token in settings to restore entity updates.", "Home Assistant auth subtitle");
                        }
                        if (globalConnectionStatus.value === "connecting") {
                            return I18n.tr("Authenticating and loading your monitored entities.", "Home Assistant connecting subtitle");
                        }
                        if (globalConnectionStatus.value === "degraded") {
                            return I18n.tr("The server is reachable, but syncs are taking longer than expected.", "Home Assistant degraded subtitle");
                        }
                        if (!globalHaAvailable.value) {
                            return I18n.tr("Review your URL and access token if the dashboard stays offline.", "Home Assistant offline subtitle");
                        }
                        return "";
                    }

                    Column {
                        id: overviewContent
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: 0

                        Row {
                            width: parent.width
                            height: Math.max(34, titleBlock.implicitHeight, actionButtons.implicitHeight)
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 34
                                height: 34
                                radius: 17
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(overviewPanel.statusColor.r, overviewPanel.statusColor.g, overviewPanel.statusColor.b, 0.12)

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: globalConnectionStatus.value === "connecting" ? "sync"
                                          : (globalConnectionStatus.value === "degraded" ? "warning"
                                          : (globalConnectionStatus.value === "auth_error" || globalConnectionStatus.value === "offline" ? "error" : "home"))
                                    size: 18
                                    color: overviewPanel.statusColor
                                }
                            }

                            Column {
                                id: titleBlock
                                width: parent.width - actionButtons.implicitWidth - 34 - Theme.spacingM * 2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: overviewPanel.titleText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    width: parent.width
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                StyledText {
                                    text: overviewPanel.subtitleText
                                    visible: text.length > 0
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }
                            }

                            Row {
                                id: actionButtons
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS

                                PanelActionButton {
                                    iconName: root.isEditing ? "check" : "edit"
                                    active: root.isEditing
                                    onClicked: root.isEditing = !root.isEditing
                                }

                                BrowseEntitiesButton {
                                    isActive: root.showEntityBrowser
                                    onClicked: {
                                        root.showEntityBrowser = !root.showEntityBrowser;
                                        if (!root.showEntityBrowser) {
                                            root.entitySearchText = "";
                                        }
                                    }
                                }

                                RefreshButton {
                                    spinning: root.manualRefreshInProgress
                                    onClicked: root.refreshEntities()
                                }
                            }
                        }

                    }
                }

                Rectangle {
                    id: connectionBanner
                    width: contentFrame.width
                    height: visible ? 32 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: ["connecting", "degraded", "offline", "auth_error"].indexOf(globalConnectionStatus.value) >= 0
                    radius: Theme.cornerRadius
                    color: globalConnectionStatus.value === "auth_error" || globalConnectionStatus.value === "offline"
                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                        : Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: globalConnectionStatus.value === "connecting" ? "sync"
                                  : (globalConnectionStatus.value === "degraded" ? "warning" : "error")
                            size: 16
                            color: globalConnectionStatus.value === "auth_error" || globalConnectionStatus.value === "offline" ? Theme.error : Theme.warning
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            text: {
                                if (globalConnectionMessage.value) return globalConnectionMessage.value;
                                if (globalConnectionStatus.value === "connecting") return I18n.tr("Connecting to Home Assistant", "Connection banner");
                                if (globalConnectionStatus.value === "degraded") return I18n.tr("Home Assistant connection is unstable", "Connection banner");
                                if (globalConnectionStatus.value === "auth_error") return I18n.tr("Home Assistant authentication failed", "Connection banner");
                                return I18n.tr("Home Assistant is offline", "Connection banner");
                            }
                        }
                    }
                }

                Item {
                    id: contentFrame
                    width: root.showEntityBrowser
                        ? root.browserColumnWidth + Theme.spacingS + root.rightColumnWidth
                        : root.compactContentWidth
                    height: parent.height - overviewPanel.height - (connectionBanner.visible ? connectionBanner.height : 0) - Theme.spacingS - (connectionBanner.visible ? Theme.spacingS : 0)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        id: contentRow
                        anchors.fill: parent
                        spacing: Theme.spacingS

                        Item {
                            width: root.showEntityBrowser ? root.browserColumnWidth : 0
                            height: parent.height
                            visible: root.showEntityBrowser

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius * 1.2
                                color: Theme.surfaceContainerLow || Theme.surfaceContainer
                                border.width: 1
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingS

                                    StyledText {
                                        id: browserSectionTitle
                                        text: I18n.tr("Entity browser", "Home Assistant browser module title")
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.surfaceVariantText
                                    }

                                    EntityBrowser {
                                        id: entityBrowser
                                        width: parent.width
                                        height: parent.height - browserSectionTitle.height - Theme.spacingS
                                        isOpen: true
                                        browseMode: root.browseMode
                                        searchText: root.entitySearchText
                                        deviceModel: root.entityDevices
                                        domainModel: root.entityDomains
                                        contentReady: popoutScope.contentReady
                                        monitoredEntityIds: {
                                            var list = globalEntities.value || [];
                                            return list.map(e => e.entityId);
                                        }

                                        onRequestToggleMonitor: (entityId) => root.toggleMonitorEntity(entityId)
                                        onRequestBrowseModeChange: (mode) => root.browseMode = mode
                                        onRequestSearchTextChange: (text) => root.entitySearchText = text
                                    }
                                }
                            }
                        }

                        Column {
                            id: rightColumn
                            width: root.rightColumnWidth
                            height: parent.height
                            spacing: Theme.spacingS

                            EmptyState {
                                width: parent.width
                                height: Math.max(260, rightColumn.height)
                                visible: globalEntities.value.length === 0
                                haAvailable: globalHaAvailable.value
                                connectionStatus: globalConnectionStatus.value
                                connectionMessage: globalConnectionMessage.value
                                entityCount: globalEntityCount.value
                            }

                            Flickable {
                                id: entityList
                                width: parent.width
                                height: rightColumn.height
                                visible: globalEntities.value.length > 0
                                clip: true
                                contentWidth: width
                                contentHeight: entityListContent.height
                                boundsBehavior: Flickable.StopAtBounds

                                Component.onCompleted: {
                                    root.entityListView = entityList;
                                    root.entityListRepeater = entityRepeater;
                                }

                                onVisibleChanged: {
                                    if (visible) {
                                        root.entityListView = entityList;
                                        root.entityListRepeater = entityRepeater;
                                    }
                                }

                                Column {
                                    id: entityListContent
                                    width: entityList.width
                                    spacing: Theme.spacingS

                                    ShortcutsGrid {
                                        id: shortcutsHeader
                                        width: parent.width
                                        visible: HomeAssistantService.shortcutsModel.count > 0 || root.isEditing
                                        isEditing: root.isEditing
                                    }

                                    Repeater {
                                        id: entityRepeater
                                        model: popoutScope.contentReady ? monitoredListModel : null

                                        delegate: Item {
                                            required property int index
                                            required property string entityId

                                            width: entityList.width
                                            height: entityCardDelegate.height

                                            EntityCard {
                                                id: entityCardDelegate
                                                width: parent.width
                                                entityData: monitoredListModel.get(index)
                                                isExpanded: root.expandedEntities[entityId] || false
                                                isCurrentItem: root.keyboardNavigationActive && root.selectedEntityId === entityId
                                                isPinned: root.isPinned(entityId)
                                                detailsExpanded: root.showEntityDetails[entityId] || false
                                                showAttributes: root.showAttributes
                                                customIcons: root.customIcons
                                                isEditing: root.isEditing

                                                onToggleExpand: root.toggleEntity(entityId)
                                                onTogglePin: root.togglePinEntity(entityId)
                                                onToggleDetails: root.toggleEntityDetails(entityId)
                                                onRemoveEntity: {
                                                    HomeAssistantService.removeEntityFromMonitor(entityId);
                                                    ToastService.showInfo(I18n.tr("Entity removed from monitoring", "Entity monitoring notification"));
                                                }
                                                onOpenIconPicker: root.openIconPicker(entityId)
                                            }
                                        }
                                    }

                                    Item {
                                        width: 1
                                        height: Theme.spacingS
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Dependency Error Overlay
            Rectangle {
                anchors.fill: parent
                z: 999
                color: Theme.surface
                visible: HomeAssistantService.missingDependency

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "error"
                        size: 48
                        color: Theme.error
                        Layout.alignment: Qt.AlignHCenter
                    }

                    StyledText {
                        text: I18n.tr("Missing Dependency", "Error title")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.error
                        Layout.alignment: Qt.AlignHCenter
                    }

                    StyledText {
                        text: I18n.tr("Please install 'qt6-websockets' package and then RESTART DMS to use this plugin.", "Error description")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: parent.width - Theme.spacingXL * 2
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Icon Picker Overlay
            IconPicker {
                id: iconPickerOverlay
                anchors.fill: parent
                z: 100
                entityId: root.iconPickerEntityId
                searchText: root.iconSearchText
                customIcons: root.customIcons
                commonIcons: HassConstants.commonIcons

                onSearchTextChanged: root.iconSearchText = searchText
                onIconSelected: iconName => {
                    root.setEntityIcon(root.iconPickerEntityId, iconName);
                    root.closeIconPicker();
                }
                onResetIcon: {
                    root.setEntityIcon(root.iconPickerEntityId, null);
                    root.closeIconPicker();
                }
                onClose: root.closeIconPicker()
            }
        }
    }

    popoutWidth: root.showEntityBrowser ? root.expandedPopoutWidth : root.compactPopoutWidth
    popoutHeight: 600
}
