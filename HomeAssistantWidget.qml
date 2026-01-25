import QtQuick
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

    Component.onCompleted: {
        console.log(HomeAssistantService.pluginId, "loaded.");
        cleanupPinnedEntities();
    }

    Connections {
        target: globalEntities
        function onValueChanged() {
            cleanupPinnedEntities();
        }
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
            console.log("HomeAssistant: Cleaned up pinned entities");
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
        id: globalAllEntities
        varName: "allEntities"
        defaultValue: []
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

    readonly property var entityDomains: {
        const entities = globalAllEntities.value || [];
        const searchLower = entitySearchText.toLowerCase().trim();

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


    horizontalBarPill: Row {
        spacing: Theme.spacingS

        HaIcon {
            barThickness: root.barThickness
            haAvailable: globalHaAvailable.value
            entityCount: globalEntityCount.value
            showHomeIcon: pluginData.showHomeIcon !== undefined ? pluginData.showHomeIcon : true
            anchors.verticalCenter: parent.verticalCenter
            visible: root.pinnedEntities.length === 0
        }

        Repeater {
            model: root.pinnedEntitiesData

            Row {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: root.getEntityIcon(modelData.entityId, modelData.domain)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: HassConstants.getStateColor(
                        modelData.domain || "",
                        modelData.state || "",
                        Theme
                    )
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: HassConstants.formatStateValue(
                        modelData.state,
                        modelData.unitOfMeasurement
                    )
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor || Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        HaCount {
            entityCount: globalEntityCount.value
            anchors.verticalCenter: parent.verticalCenter
            visible: root.pinnedEntities.length === 0
        }
    }

    verticalBarPill: Column {
        spacing: Theme.spacingXS

        HaIcon {
            barThickness: root.barThickness
            haAvailable: globalHaAvailable.value
            entityCount: globalEntityCount.value
            showHomeIcon: pluginData.showHomeIcon !== undefined ? pluginData.showHomeIcon : true
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.pinnedEntities.length === 0
        }

        Repeater {
            model: root.pinnedEntitiesData

            Column {
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: root.getEntityIcon(modelData.entityId, modelData.domain)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: HassConstants.getStateColor(
                        modelData.domain || "",
                        modelData.state || "",
                        Theme
                    )
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: HassConstants.formatStateValue(
                        modelData.state,
                        modelData.unitOfMeasurement
                    )
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor || Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        HaCount {
            entityCount: globalEntityCount.value
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.pinnedEntities.length === 0
        }
    }

    popoutContent: Component {
        FocusScope {
            implicitWidth: 420
            implicitHeight: 600
            focus: true

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

                        StyledText {
                            text: globalHaAvailable.value ? I18n.tr("Monitoring", "Home Assistant status") + ` ${globalEntityCount.value} ` + I18n.tr("entities", "Home Assistant entity count") : I18n.tr("Home Assistant unavailable", "Home Assistant connection error")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
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
                Rectangle {
                    width: parent.width
                    height: root.showEntityBrowser ? 400 : 0
                    color: "transparent"
                    clip: true
                    visible: height > 0

                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Column {
                        width: parent.width
                        height: parent.height
                        spacing: 0

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            opacity: 0.3
                        }

                        Column {
                            width: parent.width
                            spacing: 0

                            StyledText {
                                width: parent.width
                                text: I18n.tr("Browse All Entities", "Entity browser title")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                leftPadding: Theme.spacingM
                                topPadding: Theme.spacingS
                                bottomPadding: Theme.spacingXS
                            }

                            Rectangle {
                                width: parent.width - Theme.spacingM * 2
                                height: 36
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.width: searchInput.activeFocus ? 2 : 1
                                border.color: searchInput.activeFocus ? Theme.primary : Theme.outline

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "search"
                                        size: 18
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    TextInput {
                                        id: searchInput
                                        width: parent.width - 50
                                        height: parent.height
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: root.entitySearchText
                                        onTextChanged: root.entitySearchText = text

                                        Text {
                                            anchors.fill: parent
                                            text: I18n.tr("Search entities...", "Entity browser search placeholder")
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeMedium
                                            verticalAlignment: Text.AlignVCenter
                                            visible: !searchInput.text && !searchInput.activeFocus
                                        }
                                    }

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: clearMouse.containsMouse ? Theme.surfaceVariantText : "transparent"
                                        visible: root.entitySearchText.length > 0
                                        anchors.verticalCenter: parent.verticalCenter

                                        DankIcon {
                                            name: "close"
                                            size: 14
                                            color: clearMouse.containsMouse ? Theme.surface : Theme.surfaceVariantText
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: clearMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.entitySearchText = "";
                                                searchInput.focus = false;
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: Theme.spacingS
                                color: "transparent"
                            }
                        }

                        DankListView {
                            width: parent.width
                            height: parent.height - 95
                            leftMargin: Theme.spacingM
                            rightMargin: Theme.spacingM
                            spacing: 4
                            clip: true
                            model: root.entityDomains

                            delegate: Column {
                                width: (parent ? parent.width : root.width) - Theme.spacingM * 2
                                spacing: 2

                                StyledText {
                                    text: modelData.name.toUpperCase()
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                    topPadding: Theme.spacingS
                                    bottomPadding: Theme.spacingXS
                                }

                                Repeater {
                                    model: modelData.entities

                                    StyledRect {
                                        width: parent.width
                                        height: Math.max(40, contentRow.height + Theme.spacingS * 2)
                                        radius: Theme.cornerRadius
                                        color: entityBrowserMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                                        property bool isMonitored: root.isEntityMonitored(modelData.entityId)

                                        Row {
                                            id: contentRow
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.rightMargin: Theme.spacingM
                                            spacing: Theme.spacingS

                                            Rectangle {
                                                width: 20
                                                height: 20
                                                radius: 4
                                                color: parent.parent.isMonitored ? Theme.primary : "transparent"
                                                border.width: 2
                                                border.color: parent.parent.isMonitored ? Theme.primary : Theme.outline
                                                anchors.verticalCenter: parent.verticalCenter

                                                DankIcon {
                                                    name: "check"
                                                    size: 14
                                                    color: Theme.onPrimary
                                                    anchors.centerIn: parent
                                                    visible: parent.parent.parent.isMonitored
                                                }
                                            }

                                            DankIcon {
                                                name: HassConstants.getIconForDomain(modelData.domain)
                                                size: 18
                                                color: Theme.surfaceVariantText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Column {
                                                width: parent.width - 60
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter

                                                StyledText {
                                                    text: modelData.friendlyName
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Theme.surfaceText
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                    wrapMode: Text.NoWrap
                                                }

                                                StyledText {
                                                    text: {
                                                        const val = modelData.state || "";
                                                        const unit = modelData.unitOfMeasurement || "";
                                                        return unit ? `${val}${unit}` : val;
                                                    }
                                                    font.pixelSize: Theme.fontSizeSmall - 1
                                                    color: Theme.primary
                                                    width: parent.width
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                    visible: text !== ""
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: entityBrowserMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleMonitorEntity(modelData.entityId)
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                    model: globalEntities.value
                    currentIndex: root.keyboardNavigationActive ? globalEntities.value.findIndex(e => e.entityId === root.selectedEntityId) : -1

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
                            entityData: modelData
                            isExpanded: root.expandedEntities[modelData.entityId] || false
                            isCurrentItem: root.keyboardNavigationActive && root.selectedEntityId === modelData.entityId
                            isPinned: root.isPinned(modelData.entityId)
                            detailsExpanded: root.showEntityDetails[modelData.entityId] || false
                            showAttributes: root.showAttributes
                            customIcons: root.customIcons

                            onToggleExpand: root.toggleEntity(modelData.entityId)
                            onTogglePin: root.togglePinEntity(modelData.entityId)
                            onToggleDetails: root.toggleEntityDetails(modelData.entityId)
                            onRemoveEntity: {
                                HomeAssistantService.removeEntityFromMonitor(modelData.entityId);
                                ToastService.showInfo(I18n.tr("Entity removed from monitoring", "Entity monitoring notification"));
                            }
                            onOpenIconPicker: root.openIconPicker(modelData.entityId)
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
