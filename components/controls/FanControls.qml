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
        return EntityHelper.getEffectiveValue(entityData, attr, def);
    }

    width: parent.width
    spacing: Theme.spacingS

    // Speed
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: HassConstants.supportsFeature(entityData, HassConstants.fanFeature.SET_SPEED)

        StyledText {
            text: I18n.tr("Speed", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Loader {
            width: parent.width
            sourceComponent: HassConstants.fanShouldUseButtons(entityData) ? fanSpeedButtons : fanSpeedSlider
        }

        Component {
            id: fanSpeedSlider

            GenericSlider {
                width: parent.width
                value: root.getVal("percentage", 0)
                step: root.getVal("percentage_step", 1)
                maxValue: 100
                icon: "mode_fan"
                onChanged: (v) => {
                    HomeAssistantService.setOptimisticState(entityData.entityId, "percentage", v);
                    HomeAssistantService.setFanSpeed(entityData.entityId, v);
                }
                displayValue: Math.round(value) + "%"
            }

        }

        Component {
            id: fanSpeedButtons

            SegmentedControl {
                width: parent.width
                value: root.getVal("percentage", 0)
                options: {
                    const step = root.getVal("percentage_step", 33.33);
                    let opts = [];
                    let val = step;
                    while (val <= 100.1) {
                        opts.push(val);
                        val += step;
                    }
                    return opts;
                }
                unit: "%"
                onSelected: (v) => {
                    HomeAssistantService.setOptimisticState(entityData.entityId, "percentage", v);
                    HomeAssistantService.setFanSpeed(entityData.entityId, v);
                }
            }

        }

    }

    // Oscillation
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: HassConstants.supportsFeature(entityData, HassConstants.fanFeature.OSCILLATE)

        StyledText {
            text: I18n.tr("Oscillation", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledRect {
            width: parent.width
            height: 40
            radius: Theme.cornerRadius
            color: root.getVal("oscillating", false) ? Theme.primary : Theme.surfaceContainerHigh

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "cached"
                    size: 18
                    color: root.getVal("oscillating", false) ? Theme.onPrimary : Theme.surfaceText
                }

                StyledText {
                    text: root.getVal("oscillating", false) ? I18n.tr("On", "State label") : I18n.tr("Off", "State label")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.getVal("oscillating", false) ? Theme.onPrimary : Theme.surfaceText
                }

            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const current = root.getVal("oscillating", false);
                    HomeAssistantService.setOptimisticState(entityData.entityId, "oscillating", !current);
                    HomeAssistantService.setOscillating(entityData.entityId, !current);
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }

            }

        }

    }

    // Preset Modes
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: {
            const list = root.getVal("preset_modes", []);
            return list && list.length > 0;
        }

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

}
