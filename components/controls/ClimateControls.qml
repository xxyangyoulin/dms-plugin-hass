import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import "../"
import "../../services"

Column {
    id: root

    required property var entityData

    function getVal(attr, def) {
        if (!entityData)
            return def;

        // Special case for "state"
        if (attr === "state")
            return HomeAssistantService.getEffectiveValue(entityData.entityId, "state", entityData.state);

        const real = (entityData.attributes && entityData.attributes[attr] !== undefined) ? entityData.attributes[attr] : def;
        return HomeAssistantService.getEffectiveValue(entityData.entityId, attr, real);
    }

    width: parent.width
    spacing: Theme.spacingM

    // Temperature Control (Circle +/-)
    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: I18n.tr("Temperature Control", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM

            StyledRect {
                width: 40
                height: 40
                radius: 20
                color: Theme.surfaceContainerHigh

                DankIcon {
                    name: "remove"
                    anchors.centerIn: parent
                    color: Theme.surfaceText
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const cur = root.getVal("temperature", 20);
                        const step = root.getVal("target_temp_step", 0.5);
                        const next = cur - step;
                        HomeAssistantService.setOptimisticState(entityData.entityId, "temperature", next);
                        HomeAssistantService.setTemperature(entityData.entityId, next);
                    }
                }

            }

            Column {
                Layout.fillWidth: true
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: root.getVal("temperature", 20).toFixed(1) + root.getVal("temperature_unit", "°C")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.primary
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: root.getVal("current_temperature", undefined) !== undefined
                    text: I18n.tr("Current:", "Label") + " " + root.getVal("current_temperature", 0).toFixed(1) + root.getVal("temperature_unit", "°C")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

            }

            StyledRect {
                width: 40
                height: 40
                radius: 20
                color: Theme.surfaceContainerHigh

                DankIcon {
                    name: "add"
                    anchors.centerIn: parent
                    color: Theme.surfaceText
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const cur = root.getVal("temperature", 20);
                        const step = root.getVal("target_temp_step", 0.5);
                        const next = cur + step;
                        HomeAssistantService.setOptimisticState(entityData.entityId, "temperature", next);
                        HomeAssistantService.setTemperature(entityData.entityId, next);
                    }
                }

            }

        }

    }

    // HVAC Modes
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.getVal("hvac_modes", []).length > 0

        StyledText {
            text: I18n.tr("Mode", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        SegmentedControl {
            width: parent.width
            value: root.getVal("state", "") // Climate state is the HVAC mode
            options: root.getVal("hvac_modes", [])
            onSelected: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "state", v);
                HomeAssistantService.setHvacMode(entityData.entityId, v);
            }
        }

    }

    // Fan Modes
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.getVal("fan_modes", []).length > 0

        StyledText {
            text: I18n.tr("Fan Mode", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        SegmentedControl {
            width: parent.width
            value: root.getVal("fan_mode", "")
            options: root.getVal("fan_modes", [])
            onSelected: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "fan_mode", v);
                HomeAssistantService.setClimateFanMode(entityData.entityId, v);
            }
            icon: "mode_fan"
        }

    }

    // Preset Modes
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.getVal("preset_modes", []).length > 0

        StyledText {
            text: I18n.tr("Preset", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        SegmentedControl {
            width: parent.width
            value: root.getVal("preset_mode", "")
            options: root.getVal("preset_modes", [])
            onSelected: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "preset_mode", v);
                HomeAssistantService.setPresetMode(entityData.entityId, v);
            }
        }

    }

    // Swing Modes
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.getVal("swing_modes", []).length > 0

        StyledText {
            text: I18n.tr("Swing", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        SegmentedControl {
            width: parent.width
            value: root.getVal("swing_mode", "")
            options: root.getVal("swing_modes", [])
            onSelected: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "swing_mode", v);
                HomeAssistantService.setOption(entityData.entityId, "climate", "swing_mode", v);
            }
        }

    }

}
