import "." as Components
import "../services"
import "./controls"
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

StyledRect {
    id: entityCard

    required property var entityData
    property bool isExpanded: false
    property bool isCurrentItem: false
    property bool isPinned: false
    property bool detailsExpanded: false
    property bool showAttributes: true
    property var customIcons: ({})
    readonly property real baseHeight: 68
    readonly property bool isControllable: Components.HassConstants.isControllableDomain(entityData && entityData.domain ? entityData.domain : "")
    readonly property bool hasControls: _hasControls()
    property var historyData: []
    property var relatedEntities: []

    property bool isEditing: false
    property bool isRenaming: false
    
    onIsEditingChanged: {
        if (!isEditing) isRenaming = false;
    }

    signal toggleExpand()
    signal togglePin()
    signal toggleDetails()
    signal removeEntity()
    signal openIconPicker()

    function _getEffectiveState() {
        if (!entityData) return "";
        return HomeAssistantService.getEffectiveValue(entityData.entityId, "state", entityData.state || "");
    }

    function _getEffectiveAttr(attr, real) {
        if (!entityData) return real;
        return HomeAssistantService.getEffectiveValue(entityData.entityId, attr, real);
    }

    function _updateRelatedEntities() {
        if (!isExpanded) { relatedEntities = []; return; }
        if (!entityData || !HomeAssistantService.entityToDeviceCache) { relatedEntities = []; return; }
        const deviceName = HomeAssistantService.entityToDeviceCache[entityData.entityId];
        if (!deviceName) { relatedEntities = []; return; }
        const deviceEntityIds = HomeAssistantService.devicesCache[deviceName] || [];
        const all = globalAllEntities.value || [];
        const entityMap = {};
        for (const e of all) entityMap[e.entityId] = e
        const result = deviceEntityIds.filter((id) => id !== entityData.entityId).map((id) => entityMap[id]).filter((e) => e !== undefined);
        relatedEntities = result;
    }

    function _hasControls() {
        if (!entityData) return false;
        var attrs = entityData.attributes || {};
        var domain = entityData.domain;
        if (["climate", "cover", "fan", "light", "media_player", "number", "input_number", "select", "input_select", "button"].includes(domain)) return true;
        return attrs.brightness !== undefined || attrs.color_temp !== undefined || attrs.percentage !== undefined || attrs.current_position !== undefined || attrs.options !== undefined || attrs.effect_list !== undefined;
    }

    function _getEntityIcon(entityId, domain) {
        return customIcons[entityId] || Components.HassConstants.getIconForDomain(domain);
    }

    width: parent ? parent.width : 300
    radius: Theme.cornerRadius * 1.5
    color: isCurrentItem ? (Theme.surfaceContainerHighest || Theme.surfaceContainerHigh) : Theme.surfaceContainer
    border.width: isCurrentItem ? 2 : 0
    border.color: Theme.primary

    onEntityDataChanged: _updateRelatedEntities()
    onIsExpandedChanged: {
        _updateRelatedEntities();
        if (isExpanded && entityData) {
            var domain = entityData.domain;
            if (domain === "sensor" || domain === "binary_sensor")
                HomeAssistantService.fetchHistory(entityData.entityId, function(data) { historyData = data; });
        }
    }
    height: baseHeight + (isExpanded && hasControls ? Theme.spacingM + controlsLoader.height : 0) + (isExpanded ? Theme.spacingM + attributesColumn.height : 0)

    PluginGlobalVar {
        id: globalAllEntities
        varName: "allEntities"
        defaultValue: []
    }

    // Hover overlay layer
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "#000000"
        opacity: entityMouse.containsMouse ? 0.05 : 0
        z: 2
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    // Icon with background circle
    Rectangle {
        id: iconContainer
        width: 48; height: 48; radius: 24
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.top: parent.top
        anchors.topMargin: (entityCard.baseHeight - height) / 2
        z: 3
        color: Components.HassConstants.getIconBackgroundColor(entityData && entityData.domain ? entityData.domain : "", entityCard._getEffectiveState(), Theme)

        DankIcon {
            id: entityIcon
            name: entityCard._getEntityIcon(entityData && entityData.entityId ? entityData.entityId : "", entityData && entityData.domain ? entityData.domain : "")
            size: 24
            color: Components.HassConstants.getStateColor(entityData && entityData.domain ? entityData.domain : "", entityCard._getEffectiveState(), Theme)
            anchors.centerIn: parent

            RotationAnimation on rotation {
                id: fanAnimation
                from: 0; to: 360
                duration: Math.max(500, 3000 - (entityCard._getEffectiveAttr("percentage", 50) * 25))
                loops: Animation.Infinite
                running: !!entityData && entityData.domain === "fan" && entityCard._getEffectiveState() === "on"
            }
            SequentialAnimation on opacity {
                id: pulseAnimation
                running: !!entityData && entityData.domain === "binary_sensor" && entityCard._getEffectiveState() === "on"
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.4; to: 1; duration: 800; easing.type: Easing.InOutSine }
            }
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        // Light effect (simplified)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 4; height: parent.height - 4; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.primary
            opacity: 0; scale: 1
            visible: !!entityData && entityData.domain === "light" && entityCard._getEffectiveState() === "on"
            SequentialAnimation on opacity {
                running: parent.visible; loops: Animation.Infinite
                NumberAnimation { from: 0; to: 0.5; duration: 1500 }
                NumberAnimation { from: 0.5; to: 0; duration: 1500 }
            }
            SequentialAnimation on scale {
                running: parent.visible; loops: Animation.Infinite
                NumberAnimation { from: 1; to: 1.4; duration: 3000; easing.type: Easing.OutCubic }
                PropertyAction { value: 1 }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (entityData && entityData.entityId) entityCard.openIconPicker(); }
        }
        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    Column {
        id: entityTextColumn
        anchors.left: iconContainer.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: controlButton.visible ? controlButton.left : expandIcon.left
        anchors.rightMargin: Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: (entityCard.baseHeight - entityTextColumn.height) / 2
        spacing: 4

        TextInput {
            id: nameInput
            text: entityData && entityData.friendlyName ? entityData.friendlyName : ""
            font.pixelSize: Theme.fontSizeMedium + 1
            font.weight: Font.Medium
            color: Theme.surfaceText
            width: parent.width
            clip: true
            
            readOnly: !isRenaming
            selectByMouse: isRenaming
            activeFocusOnPress: isRenaming
            
            onEditingFinished: {
                isRenaming = false
                if (entityData && entityData.entityId) {
                    HomeAssistantService.renameEntity(entityData.entityId, text);
                }
            }
            
            onActiveFocusChanged: {
                if (!activeFocus) isRenaming = false;
            }
        }

        StyledText {
            text: Components.HassConstants.formatStateValue(entityCard._getEffectiveState(), entityData && entityData.unitOfMeasurement ? entityData.unitOfMeasurement : "")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.primary
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    // Controls Loader
    Loader {
        id: controlsLoader
        anchors.left: parent.left; anchors.leftMargin: Theme.spacingL + Theme.spacingS
        anchors.right: parent.right; anchors.rightMargin: Theme.spacingL + Theme.spacingS
        anchors.top: parent.top; anchors.topMargin: entityCard.baseHeight
        visible: isExpanded && hasControls
        active: isExpanded && hasControls
        opacity: visible ? 1 : 0
        height: (visible && item) ? item.implicitHeight : 0
        z: 15
        sourceComponent: {
            if (!entityData) return null;
            const domain = entityData.domain;
            if (domain === "light") return lightControlsComp;
            if (domain === "climate") return climateControlsComp;
            if (domain === "fan") return fanControlsComp;
            if (domain === "cover") return coverControlsComp;
            if (domain === "media_player") return mediaPlayerControlsComp;
            return generalControlsComp;
        }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Component { id: lightControlsComp; LightControls { entityData: entityCard.entityData } }
    Component { id: climateControlsComp; ClimateControls { entityData: entityCard.entityData } }
    Component { id: fanControlsComp; FanControls { entityData: entityCard.entityData } }
    Component { id: coverControlsComp; CoverControls { entityData: entityCard.entityData } }
    Component { id: mediaPlayerControlsComp; MediaPlayerControls { entityData: entityCard.entityData } }
    Component { id: generalControlsComp; GeneralControls { entityData: entityCard.entityData } }

    // Attributes & Extras
    Column {
        id: attributesColumn
        anchors.left: parent.left; anchors.leftMargin: Theme.spacingL + Theme.spacingS
        anchors.right: parent.right; anchors.rightMargin: Theme.spacingL + Theme.spacingS
        anchors.top: parent.top; anchors.topMargin: controlsLoader.visible ? (controlsLoader.y + controlsLoader.height + Theme.spacingM) : entityCard.baseHeight
        spacing: Theme.spacingS
        visible: isExpanded
        opacity: visible ? 1 : 0
        height: visible ? implicitHeight : 0
        z: 15

        // History
        Column {
            width: parent.width; spacing: Theme.spacingS; visible: historyData.length > 0
            StyledText { text: I18n.tr("24h History", "Sensor history label"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            Sparkline { width: parent.width; height: 50; historyData: entityCard.historyData; unit: entityData && entityData.unitOfMeasurement ? entityData.unitOfMeasurement : "" }
        }

        // Connected Entities
        Column {
            width: parent.width; spacing: Theme.spacingS; visible: entityCard.relatedEntities && entityCard.relatedEntities.length > 0
            StyledText { text: I18n.tr("Connected Entities", "Control label"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            Flow {
                width: parent.width; spacing: Theme.spacingS
                Repeater {
                    model: entityCard.relatedEntities
                    delegate: StyledRect {
                        height: 32; width: (parent.width - Theme.spacingS) / 2 - 1; radius: 6; color: Theme.surfaceContainerHigh
                        Row {
                            anchors.fill: parent; anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS; spacing: Theme.spacingS
                            DankIcon { name: Components.HassConstants.getIconForDomain(modelData.domain); size: 14; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: modelData.friendlyName; font.pixelSize: 10; color: Theme.surfaceText; elide: Text.ElideRight; width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter }
                            Item { Layout.fillWidth: true; height: 1 }
                            StyledText { text: Components.HassConstants.formatStateValue(modelData.state, modelData.unitOfMeasurement); font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        // Details Button
        StyledRect {
            width: parent.width; height: 32; visible: showAttributes; radius: Theme.cornerRadius
            color: detailsToggleMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
            border.width: 1; border.color: detailsExpanded ? Theme.primary : Theme.outline
            Row {
                anchors.fill: parent; anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM; spacing: Theme.spacingS
                DankIcon { name: detailsExpanded ? "expand_less" : "expand_more"; size: 18; color: detailsExpanded ? Theme.primary : Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: detailsExpanded ? I18n.tr("Hide Details", "Entity card hide details button") : I18n.tr("Show Details", "Entity card show details button"); font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: detailsExpanded ? Theme.primary : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
                id: detailsToggleMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; propagateComposedEvents: false
                onClicked: { mouse.accepted = true; entityCard.toggleDetails(); }
            }
        }

        // Details Content
        Column {
            width: parent.width; spacing: Theme.spacingS; visible: detailsExpanded && showAttributes; opacity: visible ? 1 : 0; height: visible ? implicitHeight : 0
            Rectangle {
                width: parent.width; height: entityIdText.height + Theme.spacingS * 2; color: Theme.surfaceContainerLowest || Theme.surfaceContainer; radius: Theme.cornerRadius
                StyledText { id: entityIdText; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter; text: entityData && entityData.entityId ? entityData.entityId : ""; font.pixelSize: Theme.fontSizeSmall - 1; font.family: "monospace"; color: Theme.surfaceVariantText; opacity: 0.9; elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
            }
            Repeater {
                model: {
                    if (!entityData || !entityData.attributes) return [];
                    var attrs = entityData.attributes;
                    var keys = Object.keys(attrs).filter(function(key) { return key !== "friendly_name" && key !== "icon" && key !== "unit_of_measurement"; });
                    return keys.slice(0, 15);
                }
                Rectangle {
                    width: parent.width; height: attrContent.height + Theme.spacingXS * 2; color: "transparent"; radius: Theme.cornerRadius
                    Row {
                        id: attrContent
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingS
                        StyledText { text: modelData.replace(/_/g, " ") + ":"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceVariantText; width: Math.min(140, parent.width * 0.35); elide: Text.ElideRight; verticalAlignment: Text.AlignTop; wrapMode: Text.NoWrap }
                        StyledText {
                            text: { const val = entityData.attributes[modelData]; if (typeof val === "object") return JSON.stringify(val, null, 2); return String(val); }
                            font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: parent.width - Math.min(140, parent.width * 0.35) - Theme.spacingS; wrapMode: Text.Wrap; maximumLineCount: 5; elide: Text.ElideRight
                        }
                    }
                }
            }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        Behavior on opacity { NumberAnimation { duration: Theme.expressiveDurations["expressiveEffects"]; easing.type: Theme.standardEasing } }
    }

    // Quick control button
    Rectangle {
        id: controlButton
        width: isControllable && !isEditing ? 44 : 0
        height: 44
        radius: 22
        visible: isControllable && !isEditing
        color: {
            const state = entityCard._getEffectiveState();
            const domain = entityData && entityData.domain ? entityData.domain : "";
            return Components.HassConstants.isActiveState(domain, state) ? Theme.primary : Theme.surfaceVariant;
        }
        anchors.right: expandIcon.left
        anchors.rightMargin: isControllable ? Theme.spacingS : 0
        anchors.top: parent.top
        anchors.topMargin: (entityCard.baseHeight - controlButton.height) / 2
        z: 10
        // Hover
        Rectangle {
            anchors.fill: parent; radius: parent.radius; color: "#000000"; opacity: controlMouse.containsMouse ? 0.1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        DankIcon {
            name: {
                var domain = entityData && entityData.domain ? entityData.domain : "";
                var state = entityCard._getEffectiveState();
                if (domain === "script" || domain === "automation") return "play_arrow";
                if (domain === "scene") return "palette";
                if (domain === "cover") return state === "open" ? "expand_more" : "expand_less";
                if (domain === "lock") return state === "locked" ? "lock" : "lock_open";
                if (domain === "climate") return state !== "off" ? "local_fire_department" : "power_settings_new";
                return "power_settings_new";
            }
            size: 22
            color: {
                var domain = entityData && entityData.domain ? entityData.domain : "";
                var state = entityCard._getEffectiveState();
                return Components.HassConstants.isActiveState(domain, state) ? Theme.primaryText : Theme.surfaceText;
            }
            anchors.centerIn: parent
        }
        MouseArea {
            id: controlMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; propagateComposedEvents: false
            onClicked: {
                var domain = entityData.domain;
                var entityId = entityData.entityId;
                var state = entityData.state;
                var friendlyName = entityData.friendlyName;
                if (domain === "script" || domain === "automation") {
                    HomeAssistantService.triggerScript(entityId);
                    ToastService.showInfo(I18n.tr("Executing", "Entity control action") + " " + friendlyName);
                } else if (domain === "scene") {
                    HomeAssistantService.activateScene(entityId);
                    ToastService.showInfo(I18n.tr("Activating", "Entity control action") + " " + friendlyName);
                } else if (domain === "button") {
                    HomeAssistantService.callService("button", "press", entityId, {});
                    ToastService.showInfo(I18n.tr("Pressing", "Entity control action") + " " + friendlyName);
                } else if (domain === "media_player") {
                    if (state === "playing") { HomeAssistantService.callService("media_player", "media_pause", entityId, {}); ToastService.showInfo(I18n.tr("Pausing", "Entity control action")); }
                    else { HomeAssistantService.callService("media_player", "media_play", entityId, {}); ToastService.showInfo(I18n.tr("Playing", "Entity control action")); }
                } else if (domain === "climate") {
                    var hvacModes = entityData.attributes && entityData.attributes.hvac_modes || ["off", "heat"];
                    var nextState = state === "off" ? (hvacModes.includes("heat") ? "heat" : hvacModes.find((m) => m !== "off") || "heat") : "off";
                    HomeAssistantService.setOptimisticState(entityId, "state", nextState);
                    HomeAssistantService.setHvacMode(entityId, nextState);
                    ToastService.showInfo(I18n.tr("Setting", "Entity control action") + " " + friendlyName + " → " + nextState);
                } else {
                    var nextState = state === "on" ? "off" : "on";
                    if (domain === "cover") nextState = state === "open" ? "closed" : "open";
                    if (domain === "lock") nextState = state === "locked" ? "unlocked" : "locked";
                    HomeAssistantService.setOptimisticState(entityId, "state", nextState);
                    HomeAssistantService.toggleEntity(entityId, domain, state);
                    ToastService.showInfo(I18n.tr("Turning", "Entity control action") + " " + nextState);
                }
            }
        }
    }

    Rectangle {
        id: expandIcon
        width: 40; height: 40; radius: 20
        color: Qt.rgba(0, 0, 0, 0)
        anchors.right: parent.right; anchors.rightMargin: Theme.spacingS
        anchors.top: parent.top; anchors.topMargin: (entityCard.baseHeight - height) / 2
        z: 10
        visible: !isEditing

        DankIcon {
            name: isExpanded ? "expand_less" : "expand_more"; size: 20; color: Theme.surfaceText; anchors.centerIn: parent
            Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: false; cursorShape: Qt.PointingHandCursor; propagateComposedEvents: false
            onClicked: entityCard.toggleExpand()
        }
    }

    // Edit Controls Overlay (Visible in Edit Mode)
    Row {
        anchors.right: parent.right; anchors.rightMargin: Theme.spacingS
        anchors.top: parent.top; anchors.topMargin: (entityCard.baseHeight - height) / 2
        spacing: 2
        visible: isEditing
        z: 20

        EditActionButton {
            width: 32; height: 32
            iconName: "push_pin"
            iconSize: 16
            iconColor: isPinned ? (Theme.primary || "transparent") : Theme.surfaceText
            backgroundColor: isPinned ? (Theme.primary || "transparent") : (Theme.surfaceContainerHigh || "transparent")
            backgroundOpacity: isPinned ? 0.3 : 0.7
            iconRotation: isPinned ? 0 : 45
            onClicked: entityCard.togglePin()
        }

        EditActionButton {
            width: 32; height: 32
            iconName: "arrow_upward"
            iconSize: 16
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: HomeAssistantService.moveEntity(entityData.entityId, "up")
        }

        EditActionButton {
            width: 32; height: 32
            iconName: "arrow_downward"
            iconSize: 16
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: HomeAssistantService.moveEntity(entityData.entityId, "down")
        }

        EditActionButton {
            width: 32; height: 32
            iconName: "close"
            iconSize: 14
            iconColor: Theme.primaryText
            backgroundColor: Theme.error || "transparent"
            onClicked: entityCard.removeEntity()
        }
    }

    MouseArea {
        id: entityMouse
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: entityCard.baseHeight
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: 1
        enabled: !isRenaming // Allow clicks unless renaming input is active
        
        onClicked: {
            if (isEditing) {
                // In edit mode single click could select or do nothing (currently nothing special requested for selection visual)
            } else {
                entityCard.toggleExpand();
            }
        }
        
        onDoubleClicked: {
            if (isEditing) {
                isRenaming = true;
                nameInput.forceActiveFocus();
                nameInput.selectAll();
            } else {
                entityCard.toggleExpand();
            }
        }
    }

    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: Theme.expressiveDurations["expressiveFastSpatial"]; easing.type: Theme.standardEasing } }
}