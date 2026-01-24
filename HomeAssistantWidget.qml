import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var expandedEntities: ({})
    property bool showAttributes: pluginData.showAttributes !== undefined ? pluginData.showAttributes : true
    property var pinnedEntities: pluginData.pinnedEntities || []

    property string selectedEntityId: ""
    property bool keyboardNavigationActive: false
    property var entityListView: null
    property bool showEntityBrowser: false
    property string entitySearchText: ""

    Component.onCompleted: {
        // Note: the import of HomeAssistantService here is necessary because Singletons are lazy-loaded in QML.
        console.log(HomeAssistantService.pluginId, "loaded.");
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
        const expanded = root.expandedEntities;
        expanded[entityId] = !expanded[entityId];
        root.expandedEntities = expanded;
        root.expandedEntitiesChanged();
    }

    function togglePinEntity(entityId) {
        let pinned = Array.from(pinnedEntities);
        const index = pinned.indexOf(entityId);

        if (index >= 0) {
            // Unpin
            pinned.splice(index, 1);
        } else {
            // Pin - limit to 3 entities max
            if (pinned.length >= 3) {
                ToastService.showWarning("Maximum 3 entities can be pinned to status bar");
                return;
            }
            pinned.push(entityId);
        }

        pinnedEntities = pinned;
        if (pluginService) {
            pluginService.savePluginData("homeAssistantMonitor", "pinnedEntities", pinned);
        }
        ToastService.showInfo(index >= 0 ? "Unpinned from status bar" : "Pinned to status bar");
    }

    function isPinned(entityId) {
        return pinnedEntities.indexOf(entityId) >= 0;
    }

    function getPinnedEntitiesData() {
        const entities = globalEntities.value;
        return pinnedEntities.map(id => entities.find(e => e.entityId === id)).filter(e => e !== undefined);
    }

    function isEntityMonitored(entityId) {
        return globalEntities.value.some(e => e.entityId === entityId);
    }

    function toggleMonitorEntity(entityId) {
        if (isEntityMonitored(entityId)) {
            HomeAssistantService.removeEntityFromMonitor(entityId);
            ToastService.showInfo("Entity removed from monitoring");
        } else {
            HomeAssistantService.addEntityToMonitor(entityId);
            ToastService.showInfo("Entity added to monitoring");
        }
    }

    function getEntityDomains() {
        const entities = globalAllEntities.value;
        const searchLower = entitySearchText.toLowerCase();

        // Filter by search text
        const filteredEntities = searchLower ? entities.filter(entity => {
            const nameMatch = entity.friendlyName.toLowerCase().includes(searchLower);
            const idMatch = entity.entityId.toLowerCase().includes(searchLower);
            return nameMatch || idMatch;
        }) : entities;

        const domains = {};
        filteredEntities.forEach(entity => {
            const domain = entity.domain || "other";
            if (!domains[domain]) {
                domains[domain] = [];
            }
            domains[domain].push(entity);
        });
        return Object.keys(domains).sort().map(domain => {
            return {
                name: domain,
                entities: domains[domain].sort((a, b) => a.friendlyName.localeCompare(b.friendlyName))
            };
        });
    }

    function selectNext() {
        const entities = globalEntities.value;
        if (!entities.length) return;

        if (!keyboardNavigationActive) {
            keyboardNavigationActive = true;
            selectedEntityId = entities[0].entityId;
            return;
        }

        const currentIndex = entities.findIndex(e => e.entityId === selectedEntityId);
        if (currentIndex >= entities.length - 1) return;

        selectedEntityId = entities[currentIndex + 1].entityId;
        ensureVisible();
    }

    function selectPrevious() {
        const entities = globalEntities.value;
        if (!entities.length) return;

        if (!keyboardNavigationActive) {
            keyboardNavigationActive = true;
            selectedEntityId = entities[0].entityId;
            return;
        }

        const currentIndex = entities.findIndex(e => e.entityId === selectedEntityId);
        if (currentIndex <= 0) return;

        selectedEntityId = entities[currentIndex - 1].entityId;
        ensureVisible();
    }

    function toggleSelected() {
        if (!selectedEntityId) return;
        toggleEntity(selectedEntityId);
    }

    function ensureVisible() {
        if (!selectedEntityId || !entityListView) return;

        Qt.callLater(() => {
            const entities = globalEntities.value;
            const index = entities.findIndex(e => e.entityId === selectedEntityId);
            if (index >= 0) {
                entityListView.positionViewAtIndex(index, ListView.Contain);
            }
        });
    }

    function refreshEntities() {
        HomeAssistantService.refresh();
        ToastService.showInfo("Refreshing Home Assistant entities...");
    }

    function getIconForDomain(domain) {
        const iconMap = {
            "light": "lightbulb",
            "switch": "toggle_on",
            "sensor": "sensors",
            "binary_sensor": "motion_sensor_active",
            "climate": "thermostat",
            "cover": "roller_shades",
            "fan": "mode_fan",
            "lock": "lock",
            "media_player": "play_circle",
            "camera": "videocam",
            "weather": "wb_sunny",
            "person": "person",
            "device_tracker": "my_location",
            "automation": "smart_button",
            "script": "code",
            "scene": "palette",
            "input_boolean": "toggle_on",
            "input_number": "pin",
            "input_select": "list",
            "input_text": "text_fields"
        };
        return iconMap[domain] || "sensors";
    }

    function isControllable(domain) {
        return ["light", "switch", "fan", "cover", "climate", "lock",
                "input_boolean", "script", "automation", "scene", "media_player"].includes(domain);
    }

    function hasSliderControl(domain) {
        return ["light", "climate", "fan", "cover"].includes(domain);
    }

    function getEntityControlLabel(domain, state) {
        if (domain === "script" || domain === "automation") return "Run";
        if (domain === "scene") return "Activate";
        if (domain === "cover") return state === "open" ? "Close" : "Open";
        if (domain === "lock") return state === "locked" ? "Unlock" : "Lock";
        return state === "on" ? "Turn Off" : "Turn On";
    }

    component HaIcon: DankIcon {
        name: "home"
        size: Theme.barIconSize(root.barThickness, -4)
        color: {
            if (!globalHaAvailable.value)
                return Theme.error;
            if (globalEntityCount.value > 0)
                return Theme.primary;
            return Theme.widgetIconColor || Theme.surfaceText;
        }
    }

    component HaCount: StyledText {
        text: globalEntityCount.value.toString()
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.widgetTextColor || Theme.surfaceText
        visible: globalEntityCount.value > 0
    }

    component EntityCard: StyledRect {
        id: entityCard
        property var entityData: null
        property bool isExpanded: false
        property bool isCurrentItem: false
        property bool isPinned: root.isPinned(entityData && entityData.entityId ? entityData.entityId : "")

        width: parent.width
        height: baseHeight + (isExpanded && root.showAttributes ? Theme.spacingM + attributesColumn.height : 0) + (isExpanded && hasSlider && isControllable ? Theme.spacingM + controlsColumn.height : 0)
        radius: Theme.cornerRadius * 1.5
        color: isCurrentItem ? Theme.surfaceContainerHighest : Theme.surfaceContainer
        border.width: isCurrentItem ? 2 : 0
        border.color: Theme.primary

        property real baseHeight: 68

        property bool isControllable: root.isControllable(entityData && entityData.domain ? entityData.domain : "")
        property bool hasSlider: root.hasSliderControl(entityData && entityData.domain ? entityData.domain : "")

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.expressiveDurations["expressiveFastSpatial"]
                easing.type: Theme.standardEasing
            }
        }

        // Hover overlay layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#000000"
            opacity: entityMouse.containsMouse ? 0.05 : 0
            z: 2

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Icon with background circle
        Rectangle {
            id: iconContainer
            width: 48
            height: 48
            radius: 24
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.top: parent.top
            anchors.topMargin: (entityCard.baseHeight - height) / 2
            color: {
                const state = entityData && entityData.state ? entityData.state : "";
                const domain = entityData && entityData.domain ? entityData.domain : "";

                if (domain === "light" || domain === "switch") {
                    return (state === "on") ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Theme.surfaceVariant;
                } else if (domain === "binary_sensor") {
                    return (state === "on") ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.15) : Theme.surfaceVariant;
                } else if (domain === "climate") {
                    return (state === "heat" || state === "cool") ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Theme.surfaceVariant;
                }
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1);
            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            DankIcon {
                id: entityIcon
                name: root.getIconForDomain(entityData && entityData.domain ? entityData.domain : "")
                size: 24
                color: {
                    const state = entityData && entityData.state ? entityData.state : "";
                    const domain = entityData && entityData.domain ? entityData.domain : "";

                    if (domain === "light" || domain === "switch") {
                        return (state === "on") ? Theme.primary : Theme.surfaceText;
                    } else if (domain === "binary_sensor") {
                        return (state === "on") ? Theme.warning : Theme.surfaceText;
                    } else if (domain === "climate") {
                        return (state === "heat" || state === "cool") ? Theme.primary : Theme.surfaceText;
                    }
                    return Theme.primary;
                }
                anchors.centerIn: parent

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Column {
            id: entityTextColumn
            anchors.left: iconContainer.right
            anchors.leftMargin: Theme.spacingM
            anchors.right: controlButton.visible ? controlButton.left : pinButton.left
            anchors.rightMargin: Theme.spacingS
            anchors.top: parent.top
            anchors.topMargin: (entityCard.baseHeight - entityTextColumn.height) / 2
            spacing: 4

            StyledText {
                text: entityData && entityData.friendlyName ? entityData.friendlyName : ""
                font.pixelSize: Theme.fontSizeMedium + 1
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                width: parent.width
            }

            Row {
                spacing: Theme.spacingXS

                StyledText {
                    text: entityData && entityData.state ? entityData.state : "unknown"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                }

                StyledText {
                    text: entityData && entityData.unitOfMeasurement ? entityData.unitOfMeasurement : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    visible: entityData && entityData.unitOfMeasurement && entityData.unitOfMeasurement !== ""
                }
            }
        }

        // Attributes with better text handling
        Column {
            id: attributesColumn
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingL + Theme.spacingS
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingL + Theme.spacingS
            anchors.top: parent.top
            anchors.topMargin: entityCard.baseHeight
            spacing: Theme.spacingS
            visible: isExpanded && root.showAttributes
            opacity: isExpanded && root.showAttributes ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.expressiveDurations["expressiveEffects"]
                    easing.type: Theme.standardEasing
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline
                opacity: 0.2
            }

            // Entity ID
            Rectangle {
                width: parent.width
                height: entityIdText.height + Theme.spacingS * 2
                color: Theme.surfaceContainerLowest
                radius: Theme.cornerRadius

                StyledText {
                    id: entityIdText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: entityData && entityData.entityId ? entityData.entityId : ""
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.family: "monospace"
                    color: Theme.surfaceVariantText
                    opacity: 0.9
                    elide: Text.ElideMiddle
                    wrapMode: Text.NoWrap
                }
            }

            Repeater {
                model: {
                    if (!entityData || !entityData.attributes) return [];
                    const attrs = entityData.attributes;
                    const keys = Object.keys(attrs).filter(key =>
                        key !== "friendly_name" &&
                        key !== "icon" &&
                        key !== "unit_of_measurement"
                    );
                    return keys.slice(0, 15);
                }

                Rectangle {
                    width: parent.width
                    height: attrContent.height + Theme.spacingXS * 2
                    color: "transparent"
                    radius: Theme.cornerRadius

                    Row {
                        id: attrContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        StyledText {
                            text: modelData.replace(/_/g, " ") + ":"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            width: Math.min(140, parent.width * 0.35)
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignTop
                            wrapMode: Text.NoWrap
                        }

                        StyledText {
                            text: {
                                const val = entityData.attributes[modelData];
                                if (typeof val === "object") {
                                    return JSON.stringify(val, null, 2);
                                }
                                return String(val);
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            width: parent.width - Math.min(140, parent.width * 0.35) - Theme.spacingS
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Control slider (for lights, climate, etc.)
        Column {
            id: controlsColumn
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingL + Theme.spacingS
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingL + Theme.spacingS
            anchors.top: attributesColumn.visible ? attributesColumn.bottom : (parent.top + entityCard.baseHeight)
            anchors.topMargin: attributesColumn.visible ? 0 : Theme.spacingM
            spacing: Theme.spacingM
            visible: isExpanded && hasSlider && isControllable
            opacity: visible ? 1 : 0
            height: visible ? implicitHeight : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.expressiveDurations["expressiveEffects"]
                    easing.type: Theme.standardEasing
                }
            }

            // Divider (only if no attributes shown)
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline
                opacity: 0.2
                visible: !attributesColumn.visible
            }

            // Brightness slider for lights
            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: entityData && entityData.domain === "light"

                StyledText {
                    text: "Brightness"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceVariantText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "brightness_6"
                        size: 20
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: parent.width - 100
                        height: 12
                        radius: 6
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: {
                                const brightness = entityData && entityData.attributes && entityData.attributes.brightness ? entityData.attributes.brightness : 0;
                                return (brightness / 255) * parent.width;
                            }
                            height: parent.height
                            radius: 6
                            color: Theme.primary

                            Behavior on width {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const brightness = Math.round((mouse.x / width) * 100);
                                HomeAssistantService.setBrightness(entityData.entityId, brightness);
                            }
                        }
                    }

                    StyledText {
                        text: {
                            const brightness = entityData && entityData.attributes && entityData.attributes.brightness ? entityData.attributes.brightness : 0;
                            return Math.round((brightness / 255) * 100) + "%";
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        width: 50
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Temperature for climate
            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: entityData && entityData.domain === "climate"

                StyledText {
                    text: "Temperature"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceVariantText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "thermostat"
                        size: 20
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: {
                            const temp = entityData && entityData.attributes && entityData.attributes.temperature ? entityData.attributes.temperature : 20;
                            return temp.toFixed(1) + "°C";
                        }
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Quick control button (toggle, run, etc.) - Material Design FAB style
        Rectangle {
            id: controlButton
            width: isControllable ? 44 : 0
            height: 44
            radius: 22
            visible: isControllable
            color: {
                const state = entityData && entityData.state ? entityData.state : "";
                return state === "on" ? Theme.primary : Theme.surfaceVariant;
            }
            anchors.right: pinButton.left
            anchors.rightMargin: isControllable ? Theme.spacingS : 0
            anchors.top: parent.top
            anchors.topMargin: (entityCard.baseHeight - controlButton.height) / 2
            z: 10

            // Hover overlay layer
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "#000000"
                opacity: controlMouse.containsMouse ? 0.1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }

            DankIcon {
                name: {
                    const domain = entityData && entityData.domain ? entityData.domain : "";
                    const state = entityData && entityData.state ? entityData.state : "";

                    if (domain === "script" || domain === "automation") return "play_arrow";
                    if (domain === "scene") return "palette";
                    if (domain === "cover") return state === "open" ? "expand_more" : "expand_less";
                    if (domain === "lock") return state === "locked" ? "lock" : "lock_open";
                    return "power_settings_new";
                }
                size: 22
                color: {
                    const state = entityData && entityData.state ? entityData.state : "";
                    return state === "on" ? Theme.onPrimary : Theme.surfaceText;
                }
                anchors.centerIn: parent
            }

            MouseArea {
                id: controlMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: false

                onClicked: {
                    const domain = entityData.domain;
                    const entityId = entityData.entityId;
                    const state = entityData.state;

                    if (domain === "script" || domain === "automation") {
                        HomeAssistantService.triggerScript(entityId);
                        ToastService.showInfo("Executing " + entityData.friendlyName);
                    } else if (domain === "scene") {
                        HomeAssistantService.activateScene(entityId);
                        ToastService.showInfo("Activating " + entityData.friendlyName);
                    } else {
                        HomeAssistantService.toggleEntity(entityId, domain, state);
                        const newState = state === "on" ? "off" : "on";
                        ToastService.showInfo("Turning " + newState);
                    }
                }
            }
        }

        // Pin button - Material Design icon button
        Rectangle {
            id: pinButton
            width: 40
            height: 40
            radius: 20
            color: isPinned ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(0, 0, 0, 0)
            anchors.right: expandIcon.left
            anchors.rightMargin: Theme.spacingXS
            anchors.top: parent.top
            anchors.topMargin: (entityCard.baseHeight - pinButton.height) / 2
            z: 10

            DankIcon {
                name: isPinned ? "push_pin" : "push_pin"
                size: 18
                color: isPinned ? Theme.primary : Theme.surfaceVariantText
                anchors.centerIn: parent
                rotation: isPinned ? 0 : 45

                Behavior on rotation {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: pinMouse
                anchors.fill: parent
                hoverEnabled: false
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: false

                onClicked: {
                    root.togglePinEntity(entityData.entityId);
                }
            }
        }

        Rectangle {
            id: expandIcon
            width: 40
            height: 40
            radius: 20
            color: Qt.rgba(0, 0, 0, 0)
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingS
            anchors.top: parent.top
            anchors.topMargin: (entityCard.baseHeight - height) / 2
            z: 10

            DankIcon {
                name: isExpanded ? "expand_less" : "expand_more"
                size: 20
                color: Theme.surfaceText
                anchors.centerIn: parent

                Behavior on rotation {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: expandMouse
                anchors.fill: parent
                hoverEnabled: false
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: false
                onClicked: {
                    root.keyboardNavigationActive = false;
                    entityCard.parent.clicked();
                }
            }
        }

        MouseArea {
            id: entityMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 1  // Lower z-index than buttons
            onClicked: {
                root.keyboardNavigationActive = false;
                entityCard.parent.clicked();
            }
        }
    }

    horizontalBarPill: Row {
        spacing: Theme.spacingS

        HaIcon {
            anchors.verticalCenter: parent.verticalCenter
        }

        // Show pinned entities or entity count
        Repeater {
            model: root.getPinnedEntitiesData()

            Row {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: root.getIconForDomain(modelData.domain)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: {
                        const state = modelData.state || "";
                        const domain = modelData.domain || "";

                        if (domain === "light" || domain === "switch") {
                            return (state === "on") ? Theme.primary : Theme.surfaceVariantText;
                        } else if (domain === "binary_sensor") {
                            return (state === "on") ? Theme.warning : Theme.surfaceVariantText;
                        }
                        return Theme.primary;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        const val = modelData.state || "?";
                        const unit = modelData.unitOfMeasurement || "";
                        return unit ? `${val}${unit}` : val;
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor || Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        HaCount {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.pinnedEntities.length === 0
        }
    }

    verticalBarPill: Column {
        spacing: Theme.spacingXS

        HaIcon {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Show pinned entities or entity count
        Repeater {
            model: root.getPinnedEntitiesData()

            Column {
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: root.getIconForDomain(modelData.domain)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: {
                        const state = modelData.state || "";
                        const domain = modelData.domain || "";

                        if (domain === "light" || domain === "switch") {
                            return (state === "on") ? Theme.primary : Theme.surfaceVariantText;
                        } else if (domain === "binary_sensor") {
                            return (state === "on") ? Theme.warning : Theme.surfaceVariantText;
                        }
                        return Theme.primary;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        const val = modelData.state || "?";
                        const unit = modelData.unitOfMeasurement || "";
                        return unit ? `${val}${unit}` : val;
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor || Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        HaCount {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.pinnedEntities.length === 0
        }
    }

    popoutContent: Component {
        FocusScope {
            implicitWidth: 420
            implicitHeight: 600
            focus: true

            Component.onCompleted: {
                Qt.callLater(() => {
                    forceActiveFocus();
                });
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
                            text: globalHaAvailable.value ? `Monitoring ${globalEntityCount.value} entities` : "Home Assistant unavailable"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: root.pinnedEntities.length > 0 ? `${root.pinnedEntities.length} pinned to status bar` : "Click 📌 to pin entities to status bar"
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
                                    root.entitySearchText = "";  // Clear search when closing
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

                        // Header and Search
                        Column {
                            width: parent.width
                            spacing: 0

                            StyledText {
                                width: parent.width
                                text: "Browse All Entities"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                leftPadding: Theme.spacingM
                                topPadding: Theme.spacingS
                                bottomPadding: Theme.spacingXS
                            }

                            // Search box
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
                                            text: "Search entities..."
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeMedium
                                            verticalAlignment: Text.AlignVCenter
                                            visible: !searchInput.text && !searchInput.activeFocus
                                        }
                                    }

                                    // Clear button
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
                            model: root.getEntityDomains()

                            delegate: Column {
                                width: parent.width - Theme.spacingM * 2
                                spacing: 2

                                // Domain header
                                StyledText {
                                    text: modelData.name.toUpperCase()
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                    topPadding: Theme.spacingS
                                    bottomPadding: Theme.spacingXS
                                }

                                // Entities in domain
                                Repeater {
                                    model: modelData.entities

                                    StyledRect {
                                        width: parent.width
                                        height: 40
                                        radius: Theme.cornerRadius
                                        color: entityBrowserMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                        border.width: 0

                                        property bool isMonitored: root.isEntityMonitored(modelData.entityId)

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.rightMargin: Theme.spacingM
                                            spacing: Theme.spacingS

                                            // Checkbox
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

                                            // Icon
                                            DankIcon {
                                                name: root.getIconForDomain(modelData.domain)
                                                size: 18
                                                color: Theme.surfaceVariantText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // Name
                                            StyledText {
                                                text: modelData.friendlyName
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                                width: parent.width - 100
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // State
                                            StyledText {
                                                text: {
                                                    const val = modelData.state || "";
                                                    const unit = modelData.unitOfMeasurement || "";
                                                    return unit ? `${val}${unit}` : val;
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
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

                    // Disable height animation to prevent jitter
                    Behavior on height {
                        enabled: false
                    }

                    Component.onCompleted: {
                        root.entityListView = entityList;
                    }

                    delegate: Column {
                        id: entityDelegate
                        width: entityList.width - entityList.leftMargin - entityList.rightMargin
                        spacing: 0

                        property bool isExpanded: root.expandedEntities[modelData.entityId] || false
                        property bool isCurrentItem: root.keyboardNavigationActive && root.selectedEntityId === modelData.entityId

                        signal clicked()

                        onClicked: root.toggleEntity(modelData.entityId)

                        EntityCard {
                            entityData: modelData
                            isExpanded: entityDelegate.isExpanded
                            isCurrentItem: entityDelegate.isCurrentItem
                        }
                    }
                }

                // Empty state
                Column {
                    width: parent.width
                    height: {
                        const headerHeight = 46;
                        const browserHeight = root.showEntityBrowser ? 400 : 0;
                        const bottomPadding = Theme.spacingXL;
                        return root.popoutHeight - headerHeight - browserHeight - bottomPadding;
                    }
                    visible: globalEntities.value.length === 0 && !root.showEntityBrowser
                    spacing: Theme.spacingM

                    Item {
                        width: parent.width
                        height: parent.height / 3
                    }

                    DankIcon {
                        name: globalHaAvailable.value ? "info" : "error"
                        size: 48
                        color: globalHaAvailable.value ? Theme.surfaceVariantText : Theme.error
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: globalHaAvailable.value ? "No entities configured" : "Cannot connect to Home Assistant"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: globalHaAvailable.value ?
                            "Add entity IDs in the plugin settings to start monitoring." :
                            "Check your URL and access token in the plugin settings."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - Theme.spacingL * 2
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    component BrowseEntitiesButton: Rectangle {
        signal clicked
        property bool isActive: false

        width: 36
        height: 36
        radius: Theme.cornerRadius
        color: isActive ? Theme.primaryHover : Qt.rgba(0, 0, 0, 0)

        DankIcon {
            anchors.centerIn: parent
            name: isActive ? "expand_less" : "add"
            size: 18
            color: isActive ? Theme.primary : Theme.surfaceText
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component RefreshButton: Rectangle {
        signal clicked

        width: 36
        height: 36
        radius: Theme.cornerRadius
        color: Qt.rgba(0, 0, 0, 0)

        DankIcon {
            anchors.centerIn: parent
            name: "refresh"
            size: 18
            color: Theme.surfaceText
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    popoutWidth: 420
    popoutHeight: 600  // 固定高度，避免动画时抖动
}
