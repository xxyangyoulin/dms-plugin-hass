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

    property string selectedEntityId: ""
    property string iconPickerEntityId: ""
    property string iconSearchText: ""
    property bool keyboardNavigationActive: false
    property var entityListView: null
    property bool showEntityBrowser: false
    property string entitySearchText: ""

    property bool isEditing: false // Global edit mode state

    Ref {
        service: HomeAssistantService
    }

    function cleanupPinnedEntities() {
        var entities = globalEntities.value || [];
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
        
        // Fast path: check if any changes at all (quick hash check)
        const newHash = entities.map(e => `${e.entityId}:${e.state}:${e.lastUpdated}`).join(",");
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
                monitoredListModel.set(i, entities[i]);
            }
            return;
        }
        
        // Full rebuild
        monitoredListModel.clear();
        for (const ent of entities) {
            monitoredListModel.append(ent);
        }
    }

    Connections {
        target: globalEntities
        function onValueChanged() {
            cleanupPinnedEntities();
            syncMonitoredList();
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
                entityListView.positionViewAtIndex(index, ListView.Contain);
            }
        });
    }

    function refreshEntities() {
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
        entityCount: globalEntityCount.value
        pinnedEntitiesData: root.pinnedEntitiesData
        customIcons: root.customIcons
        barThickness: root.barThickness
        showHomeIcon: pluginData.showHomeIcon !== undefined ? pluginData.showHomeIcon : true
    }

    verticalBarPill: StatusBarContent {
        orientation: Qt.Vertical
        haAvailable: globalHaAvailable.value
        entityCount: globalEntityCount.value
        pinnedEntitiesData: root.pinnedEntitiesData
        customIcons: root.customIcons
        barThickness: root.barThickness
        showHomeIcon: pluginData.showHomeIcon !== undefined ? pluginData.showHomeIcon : true
    }

    // Lazy-loaded popout content for better performance
    property bool popoutReady: false
    
    popoutContent: Component {
        FocusScope {
            id: popoutScope
            implicitWidth: 420
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

            // Main Content
            Column {
                id: popoutColumn
                spacing: 0
                width: parent.width
                
                Rectangle {
                    width: parent.width
                    height: 46
                    color: "transparent"

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Row {
                            spacing: Theme.spacingS
                            
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: {
                                    if (!globalHaAvailable.value) return Theme.error;
                                    if (globalLatency.value < 0) return Theme.surfaceVariantText;
                                    if (globalLatency.value < 50) return "#4caf50"; // Green
                                    if (globalLatency.value < 150) return "#ff9800"; // Orange
                                    return Theme.error;
                                }
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }

                            StyledText {
                                text: {
                                    if (!globalHaAvailable.value) return I18n.tr("Home Assistant unavailable", "Home Assistant connection error");
                                    let base = I18n.tr("Monitoring", "Home Assistant status") + ` ${globalEntityCount.value} ` + I18n.tr("entities", "Home Assistant entity count");
                                    if (globalLatency.value >= 0) {
                                        return base + ` (${globalLatency.value}ms)`;
                                    }
                                    return base;
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.surfaceVariantText
                            }
                        }

                        StyledText {
                            text: root.pinnedEntities.length > 0 ? `${root.pinnedEntities.length} ` + I18n.tr("pinned to status bar", "Home Assistant pinned count") : I18n.tr("Click pin icon to pin entities to status bar", "Home Assistant pin hint")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            opacity: 0.7
                            visible: globalEntityCount.value > 0
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        // Edit Shortcuts Toggle
                        Rectangle {
                            width: 36; height: 36; radius: Theme.cornerRadius
                            color: root.isEditing ? Theme.primaryContainer : "transparent"
                            
                            DankIcon {
                                name: root.isEditing ? "check" : "edit"
                                size: 18
                                color: root.isEditing ? Theme.primary : Theme.surfaceText
                                anchors.centerIn: parent
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.isEditing = !root.isEditing
                            }
                        }

                        BrowseEntitiesButton {
                            onClicked: {
                                root.showEntityBrowser = !root.showEntityBrowser;
                                if (!root.showEntityBrowser) {
                                    root.entitySearchText = "";
                                }
                            }
                            isActive: root.showEntityBrowser
                        }

                        RefreshButton {
                            onClicked: root.refreshEntities()
                        }
                    }
                }

                // Entity Browser
                EntityBrowser {
                    id: entityBrowser
                    width: parent.width
                    isOpen: root.showEntityBrowser
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

                // Monitored Entities List
                DankListView {
                    id: entityList
                    width: parent.width
                    height: {
                        const headerHeight = 46;
                        const browserHeight = root.showEntityBrowser ? 400 : 0;
                        const bottomPadding = Theme.spacingXL;
                        return root.popoutHeight - headerHeight - browserHeight - bottomPadding;
                    }
                    topMargin: Theme.spacingS
                    bottomMargin: Theme.spacingM
                    leftMargin: Theme.spacingM
                    rightMargin: Theme.spacingM
                    spacing: Theme.spacingS
                    clip: true
                    cacheBuffer: 150  // Pre-render nearby items
                    model: popoutScope.contentReady ? monitoredListModel : null
                    currentIndex: root.keyboardNavigationActive ? globalEntities.value.findIndex(e => e.entityId === root.selectedEntityId) : -1

                    header: ShortcutsGrid {
                        width: parent.width - entityList.leftMargin - entityList.rightMargin
                        x: entityList.leftMargin
                        isEditing: root.isEditing
                    }

                    // Animations for sorting/adding/removing
                    move: Transition {
                        NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                    }
                    moveDisplaced: Transition {
                        NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                    }
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                        NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 200 }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                    }

                    Behavior on height {
                        enabled: false
                    }

                    Component.onCompleted: {
                        root.entityListView = entityList;
                    }

                    delegate: Item {
                        width: entityList.width - entityList.leftMargin - entityList.rightMargin
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

                // Empty state
                EmptyState {
                    width: parent.width
                    height: {
                        const headerHeight = 46;
                        const browserHeight = root.showEntityBrowser ? 400 : 0;
                        const bottomPadding = Theme.spacingXL;
                        return root.popoutHeight - headerHeight - browserHeight - bottomPadding;
                    }
                    visible: globalEntities.value.length === 0 && !root.showEntityBrowser
                    haAvailable: globalHaAvailable.value
                    entityCount: globalEntityCount.value
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

    popoutWidth: 420
    popoutHeight: 600
}
