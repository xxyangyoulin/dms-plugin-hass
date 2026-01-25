import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../services"
import "." as Components

StyledRect {
    id: entityCard

    required property var entityData
    property bool isExpanded: false
    property bool isCurrentItem: false
    property bool isPinned: false
    property bool detailsExpanded: false
    property bool showAttributes: true
    property var customIcons: ({})

    // Optimistic UI state
    property var optimisticStates: ({})
    property var optimisticTimer: Timer {
        interval: Components.HassConstants.optimisticTimeout
        onTriggered: entityCard.optimisticStates = ({})
    }

    function _setOptimistic(key, value) {
        var states = Object.assign({}, optimisticStates);
        states[key] = value;
        optimisticStates = states;
        optimisticTimer.restart();
    }

    function _getEffectiveAttr(attrName, realValue) {
        return optimisticStates[attrName] !== undefined ? optimisticStates[attrName] : realValue;
    }

    function _getEffectiveState() {
        if (optimisticStates.state !== undefined) return optimisticStates.state;
        return entityData && entityData.state ? entityData.state : "";
    }

    signal toggleExpand()
    signal togglePin()
    signal toggleDetails()
    signal removeEntity()
    signal openIconPicker()

    width: parent ? parent.width : 300
    radius: Theme.cornerRadius * 1.5
    color: isCurrentItem ? (Theme.surfaceContainerHighest || Theme.surfaceContainerHigh) : Theme.surfaceContainer
    border.width: isCurrentItem ? 2 : 0
    border.color: Theme.primary

    readonly property real baseHeight: 68
    readonly property bool isControllable: Components.HassConstants.isControllableDomain(entityData && entityData.domain ? entityData.domain : "")
    readonly property bool hasControls: _hasControls()
    property var historyData: []

    onIsExpandedChanged: {
        if (isExpanded && entityData) {
            var domain = entityData.domain;
            if (domain === "sensor" || domain === "binary_sensor") {
                HomeAssistantService.fetchHistory(entityData.entityId, function(data) {
                    historyData = data;
                });
            }
        }
    }

    function _hasControls() {
        if (!entityData || !entityData.attributes) return false;
        var attrs = entityData.attributes;
        var domain = entityData.domain;

        return attrs.brightness !== undefined ||
               attrs.color_temp !== undefined ||
               attrs.percentage !== undefined ||
               attrs.current_position !== undefined ||
               attrs.options !== undefined ||
               attrs.hvac_modes !== undefined ||
               attrs.preset_modes !== undefined ||
               attrs.fan_modes !== undefined ||
               attrs.swing_modes !== undefined ||
               attrs.effect_list !== undefined ||
               domain === "climate" ||
               domain === "number" ||
               domain === "input_number";
    }

    function _getAttr(name, def) {
        return Components.HassConstants.safeAttr(entityData, name, def);
    }

    height: baseHeight + (isExpanded && hasControls ? Theme.spacingM + controlsColumn.height : 0) + (isExpanded ? Theme.spacingM + attributesColumn.height : 0)

    function _getEntityIcon(entityId, domain) {
        return customIcons[entityId] || Components.HassConstants.getIconForDomain(domain);
    }

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
        z: 3
        color: Components.HassConstants.getIconBackgroundColor(
            entityData && entityData.domain ? entityData.domain : "",
            entityCard._getEffectiveState(),
            Theme
        )

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        DankIcon {
            id: entityIcon
            name: entityCard._getEntityIcon(
                entityData && entityData.entityId ? entityData.entityId : "",
                entityData && entityData.domain ? entityData.domain : ""
            )
            size: 24
            color: Components.HassConstants.getStateColor(
                entityData && entityData.domain ? entityData.domain : "",
                entityCard._getEffectiveState(),
                Theme
            )
            anchors.centerIn: parent


            

            RotationAnimation on rotation {
                id: fanAnimation
                from: 0
                to: 360
                duration: Math.max(500, 3000 - (entityCard._getAttr("percentage", 50) * 25))
                loops: Animation.Infinite
                running: entityData && entityData.domain === "fan" && entityCard._getEffectiveState() === "on"
            }


            SequentialAnimation on opacity {
                id: pulseAnimation
                running: entityData && entityData.domain === "binary_sensor" && entityCard._getEffectiveState() === "on"
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 4; height: parent.height - 4
            radius: width/2
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
            opacity: 0
            scale: 1.0
            visible: entityData && entityData.domain === "light" && entityCard._getEffectiveState() === "on"

            SequentialAnimation on opacity {
                running: parent.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 0.5; duration: 1500 }
                NumberAnimation { from: 0.5; to: 0; duration: 1500 }
            }
            
            SequentialAnimation on scale {
                running: parent.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.4; duration: 3000; easing.type: Easing.OutCubic }
                PropertyAction { value: 1.0 }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (entityData && entityData.entityId) {
                    entityCard.openIconPicker();
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

        StyledText {
            text: Components.HassConstants.formatStateValue(
                entityCard._getEffectiveState(),
                entityData && entityData.unitOfMeasurement ? entityData.unitOfMeasurement : ""
            )
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.primary
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    Column {
        id: controlsColumn
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingL + Theme.spacingS
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL + Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: entityCard.baseHeight
        spacing: Theme.spacingM
        visible: isExpanded && hasControls
        opacity: visible ? 1 : 0
        height: visible ? implicitHeight : 0
        z: 15

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        // Divider
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outline
            opacity: 0.2
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: entityCard._getAttr("brightness", undefined) !== undefined

            StyledText {
                text: I18n.tr("Brightness", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            GenericSlider {
                width: parent.width
                value: entityCard._getAttr("brightness", 0)
                maxValue: 255
                icon: "brightness_6"
                onChanged: (v) => HomeAssistantService.setBrightness(entityData.entityId, v)
                displayValue: Math.round((value / 255) * 100) + "%"
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: entityCard._getAttr("color_temp", undefined) !== undefined

            StyledText {
                text: I18n.tr("Color Temperature", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            GenericSlider {
                width: parent.width
                value: entityCard._getAttr("color_temp", 0)
                minValue: entityCard._getAttr("min_mireds", 153)
                maxValue: entityCard._getAttr("max_mireds", 500)
                icon: "thermostat"
                isColorTemp: true
                onChanged: (v) => HomeAssistantService.setColorTemp(entityData.entityId, v)
                displayValue: value
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: entityCard._getAttr("percentage", undefined) !== undefined && entityData.domain !== "light"

            StyledText {
                text: I18n.tr("Speed", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            GenericSlider {
                width: parent.width
                value: entityCard._getAttr("percentage", 0)
                maxValue: 100
                icon: "mode_fan"
                onChanged: (v) => HomeAssistantService.setFanSpeed(entityData.entityId, v)
                displayValue: value + "%"
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: entityCard._getAttr("current_position", undefined) !== undefined

            StyledText {
                text: I18n.tr("Position", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            GenericSlider {
                width: parent.width
                value: entityCard._getAttr("current_position", 0)
                maxValue: 100
                icon: "roller_shades"
                onChanged: (v) => HomeAssistantService.setCoverPosition(entityData.entityId, v)
                displayValue: value + "%"
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: entityData && entityData.domain === "climate"

            StyledText {
                text: I18n.tr("Temperature Control", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
            
            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "thermostat"; size: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    StyledText {
                        text: I18n.tr("Target:", "Label") + " " + entityCard._getAttr("temperature", 20).toFixed(1) + entityCard._getAttr("temperature_unit", "°C")
                        font.pixelSize: Theme.fontSizeMedium; color: Theme.primary
                    }
                    StyledText {
                        visible: entityCard._getAttr("current_temperature", undefined) !== undefined
                        text: I18n.tr("Current:", "Label") + " " + entityCard._getAttr("current_temperature", 0).toFixed(1) + entityCard._getAttr("temperature_unit", "°C")
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                    }
                }
            }

            Row {
                width: parent.width; spacing: Theme.spacingS
                // Simplified climate buttons
                StyledRect {
                    width: (parent.width - Theme.spacingS) / 2; height: 32; radius: 8
                    color: Theme.surfaceContainerHigh
                    DankIcon { name: "remove"; anchors.centerIn: parent; color: Theme.surfaceText }
                    MouseArea { anchors.fill: parent; onClicked: {
                        const cur = entityCard._getAttr("temperature", 20);
                        const step = entityCard._getAttr("target_temp_step", 0.5);
                        HomeAssistantService.setTemperature(entityData.entityId, cur - step);
                    }}
                }
                StyledRect {
                    width: (parent.width - Theme.spacingS) / 2; height: 32; radius: 8
                    color: Theme.surfaceContainerHigh
                    DankIcon { name: "add"; anchors.centerIn: parent; color: Theme.surfaceText }
                    MouseArea { anchors.fill: parent; onClicked: {
                        const cur = entityCard._getAttr("temperature", 20);
                        const step = entityCard._getAttr("target_temp_step", 0.5);
                        HomeAssistantService.setTemperature(entityData.entityId, cur + step);
                    }}
                }
            }
        }

        Repeater {
            id: modeGroupsRepeater
            model: {
                if (!entityData || !entityData.attributes) return [];
                var attrs = entityData.attributes;
                var groups = [];

                var mappings = [
                    { key: "hvac_modes", label: I18n.tr("HVAC Mode", "Control label"), current: entityData.state, stateKey: "state" },
                    { key: "preset_modes", label: I18n.tr("Preset", "Control label"), current: attrs.preset_mode, stateKey: "preset_mode" },
                    { key: "fan_modes", label: I18n.tr("Fan Mode", "Control label"), current: attrs.fan_mode, stateKey: "fan_mode" },
                    { key: "swing_modes", label: I18n.tr("Swing Mode", "Control label"), current: attrs.swing_mode, stateKey: "swing_mode" },
                    { key: "effect_list", label: I18n.tr("Effect", "Control label"), current: attrs.effect, stateKey: "effect" },
                    { key: "options", label: I18n.tr("Options", "Control label"), current: entityData.state, stateKey: "state" }
                ];

                for (var i = 0; i < mappings.length; i++) {
                    var m = mappings[i];
                    var val = attrs[m.key];
                    if (val && typeof val === "object" && val.length > 0) {
                        groups.push({
                            name: m.key,
                            label: m.label,
                            options: val,
                            current: m.current,
                            stateKey: m.stateKey
                        });
                    }
                }
                return groups;
            }

            delegate: Column {
                id: groupColumn
                property var groupData: modelData
                width: controlsColumn.width
                spacing: Theme.spacingS
                
                StyledText {
                    text: groupData.label
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceVariantText
                }

                Flow {
                    width: parent.width
                    spacing: 6
                    
                    Repeater {
                        model: groupData.options
                        delegate: StyledRect {
                            height: 30
                            width: Math.max(60, optText.implicitWidth + 24)
                            radius: 15
                            color: {
                                const current = entityCard._getEffectiveAttr(groupData.stateKey, groupData.current);
                                return (current === modelData) ? Theme.primary : Theme.surfaceContainerHigh;
                            }

                            StyledText {
                                id: optText
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: {
                                    const current = entityCard._getEffectiveAttr(groupData.stateKey, groupData.current);
                                    return (current === modelData) ? Font.Bold : Font.Normal;
                                }
                                color: {
                                    const current = entityCard._getEffectiveAttr(groupData.stateKey, groupData.current);
                                    return (current === modelData) ? Theme.onPrimary : Theme.surfaceText;
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    entityCard._setOptimistic(groupData.stateKey, modelData);
                                    HomeAssistantService.setOption(entityData.entityId, entityData.domain, groupData.name, modelData);
                                }
                            }
                        }
                    }
                }
                
                Item { width: 1; height: 4; visible: index < modeGroupsRepeater.count - 1 }
            }
        }
    }

    Column {
        id: attributesColumn
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingL + Theme.spacingS
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL + Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: controlsColumn.visible ? (controlsColumn.y + controlsColumn.height + Theme.spacingM) : entityCard.baseHeight
        spacing: Theme.spacingS
        visible: isExpanded
        opacity: visible ? 1 : 0
        height: visible ? implicitHeight : 0
        z: 15

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
            visible: !controlsColumn.visible
        }

        // 0. SENSOR HISTORY SPARKLINE
        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: historyData.length > 0
            
            StyledText {
                text: I18n.tr("24h History", "Sensor history label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Sparkline {
                width: parent.width
                height: 50
                historyData: entityCard.historyData
            }
        }

        StyledRect {
            width: parent.width
            height: 32
            visible: showAttributes
            radius: Theme.cornerRadius
            color: detailsToggleMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
            border.width: 1
            border.color: detailsExpanded ? Theme.primary : Theme.outline

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingS

                DankIcon {
                    name: detailsExpanded ? "expand_less" : "expand_more"
                    size: 18
                    color: detailsExpanded ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: detailsExpanded ? I18n.tr("Hide Details", "Entity card hide details button") : I18n.tr("Show Details", "Entity card show details button")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: detailsExpanded ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: detailsToggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: false
                onClicked: function(mouse) {
                    mouse.accepted = true;
                    entityCard.toggleDetails();
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: detailsExpanded && showAttributes
            opacity: visible ? 1 : 0
            height: visible ? implicitHeight : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                width: parent.width
                height: entityIdText.height + Theme.spacingS * 2
                color: Theme.surfaceContainerLowest || Theme.surfaceContainer
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
                    var attrs = entityData.attributes;
                    var keys = Object.keys(attrs).filter(function(key) {
                        return key !== "friendly_name" &&
                               key !== "icon" &&
                               key !== "unit_of_measurement";
                    });
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

        // Delete button - compact, right-aligned
        Item {
            width: parent.width
            height: 36

            StyledRect {
                width: deleteMouse.containsMouse ? deleteRow.width + Theme.spacingM * 2 : 28
                height: 28
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                radius: 14
                color: deleteMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1) : "transparent"
                border.width: 1
                border.color: deleteMouse.containsMouse ? Theme.error : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2)

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    id: deleteRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "delete"
                        size: 16
                        color: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Remove", "Entity card remove button")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: deleteMouse.containsMouse ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                MouseArea {
                    id: deleteMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    propagateComposedEvents: false

                    onClicked: function(mouse) {
                        mouse.accepted = true;
                        entityCard.removeEntity();
                    }
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
            const state = entityCard._getEffectiveState();
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
                var domain = entityData && entityData.domain ? entityData.domain : "";
                var state = entityCard._getEffectiveState();

                if (domain === "script" || domain === "automation") return "play_arrow";
                if (domain === "scene") return "palette";
                if (domain === "cover") return state === "open" ? "expand_more" : "expand_less";
                if (domain === "lock") return state === "locked" ? "lock" : "lock_open";
                return "power_settings_new";
            }
            size: 22
            color: entityCard._getEffectiveState() === "on" ? Theme.onPrimary : Theme.surfaceText
            anchors.centerIn: parent
        }

        MouseArea {
            id: controlMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            propagateComposedEvents: false

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
                } else {
                    var nextState = state === "on" ? "off" : "on";
                    if (domain === "cover") nextState = state === "open" ? "closed" : "open";
                    if (domain === "lock") nextState = state === "locked" ? "unlocked" : "locked";

                    entityCard._setOptimistic("state", nextState);
                    HomeAssistantService.toggleEntity(entityId, domain, state);
                    ToastService.showInfo(I18n.tr("Turning", "Entity control action") + " " + nextState);
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
            name: "push_pin"
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
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            propagateComposedEvents: false

            onClicked: entityCard.togglePin()
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
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            propagateComposedEvents: false
            onClicked: entityCard.toggleExpand()
        }
    }

    MouseArea {
        id: entityMouse
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: entityCard.baseHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 1
        onClicked: entityCard.toggleExpand()
    }
}
