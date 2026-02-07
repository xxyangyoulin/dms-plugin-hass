import "../"
import "../../services"
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    required property var entityData

    function getVal(attr, def) {
        return EntityHelper.getEffectiveValue(entityData, attr, def);
    }

    width: parent.width
    spacing: Theme.spacingS

    // Number / Input Number
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: entityData.domain === "number" || entityData.domain === "input_number"

        StyledText {
            text: I18n.tr("Value", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        GenericSlider {
            width: parent.width
            value: parseFloat(root.getVal("state", 0)) || 0
            minValue: root.getVal("min", 0)
            maxValue: root.getVal("max", 100)
            step: root.getVal("step", 1)
            icon: "tune"
            displayValue: {
                const unit = entityData.unitOfMeasurement || "";
                return Math.round(value * 10) / 10 + unit;
            }
            onChanged: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "state", v.toString());
                const domain = entityData.domain;
                HomeAssistantService.callService(domain, "set_value", entityData.entityId, {
                    "value": v
                });
            }
        }

    }

    // Select / Input Select
    Column {
        property var options: root.getVal("options", [])

        width: parent.width
        spacing: Theme.spacingS
        visible: entityData.domain === "select" || entityData.domain === "input_select"

        StyledText {
            text: I18n.tr("Select", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        // Use buttons if <= 5 options, otherwise show dropdown (simulated)
        Loader {
            width: parent.width
            sourceComponent: parent.options.length <= 5 ? selectButtonsComponent : selectDropdownComponent

            Component {
                id: selectButtonsComponent

                SegmentedControl {
                    width: parent.width
                    options: root.parent.options
                    value: root.getVal("state", "")
                    labels: root.parent.options
                    unit: ""
                    onSelected: (v) => {
                        HomeAssistantService.setOptimisticState(entityData.entityId, "state", v);
                        const domain = entityData.domain;
                        HomeAssistantService.callService(domain, "select_option", entityData.entityId, {
                            "option": v
                        });
                    }
                }

            }

            Component {
                id: selectDropdownComponent

                StyledRect {
                    width: parent.width
                    height: 44
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: root.getVal("state", "-")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - dropdownIcon.width - Theme.spacingS
                            elide: Text.ElideRight
                        }

                        DankIcon {
                            id: dropdownIcon

                            name: "expand_more"
                            size: 20
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }

                }

            }

        }

    }

    // Button
    StyledRect {
        width: parent.width
        height: 44
        radius: Theme.cornerRadius
        visible: entityData.domain === "button"
        color: buttonMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.primary

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "touch_app"
                size: 20
                color: Theme.primary
            }

            StyledText {
                text: I18n.tr("Press", "Button action label")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.primary
            }

        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: HomeAssistantService.callService("button", "press", entityData.entityId, {
            })
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }

        }

    }

    // Generic options (for any entity having 'options' attribute not handled elsewhere)
    Column {
        // Climate options handled in ClimateControls

        width: parent.width
        spacing: Theme.spacingS
        visible: {
            const opts = root.getVal("options", []);
            // Only show if NOT handled by input_select above
            return opts && opts.length > 0 && entityData.domain !== "select" && entityData.domain !== "input_select" && entityData.domain !== "climate";
        }

        StyledText {
            text: I18n.tr("Options", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: root.getVal("options", [])

                delegate: StyledRect {
                    height: 30
                    width: Math.max(60, optText.implicitWidth + 24)
                    radius: 15
                    color: {
                        const current = root.getVal("state", "");
                        return (current === modelData) ? Theme.primary : Theme.surfaceContainerHigh;
                    }

                    StyledText {
                        id: optText

                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: {
                            const current = root.getVal("state", "");
                            return (current === modelData) ? Theme.onPrimary : Theme.surfaceText;
                        }
                    }

                    MouseArea {
                        // Generic option handler? Might depend on domain.
                        // Assuming set_option or similar. For now, leave as placeholder or generic service.

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                        }
                    }

                }

            }

        }

    }

}
