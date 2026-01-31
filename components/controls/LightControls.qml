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

    // Helper to get effective value (optimistic or real)
    function getVal(attr, def) {
        if (!entityData)
            return def;

        const real = (entityData.attributes && entityData.attributes[attr] !== undefined) ? entityData.attributes[attr] : def;
        return HomeAssistantService.getEffectiveValue(entityData.entityId, attr, real);
    }

    width: parent.width
    spacing: Theme.spacingS

    // Brightness
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: HassConstants.lightSupportsBrightness(entityData)

        StyledText {
            text: I18n.tr("Brightness", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        GenericSlider {
            width: parent.width
            value: root.getVal("brightness", 0)
            maxValue: 255
            icon: "brightness_6"
            onChanged: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "brightness", v);
                HomeAssistantService.setBrightness(entityData.entityId, v);
            }
            displayValue: Math.round((value / 255) * 100) + "%"
        }

    }

    // Color Temperature
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: HassConstants.lightSupportsColorTemp(entityData)

        StyledText {
            text: I18n.tr("Color Temperature", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        GenericSlider {
            width: parent.width
            value: root.getVal("color_temp", 0)
            minValue: root.getVal("min_mireds", 153)
            maxValue: root.getVal("max_mireds", 500)
            icon: "thermostat"
            isColorTemp: true
            onChanged: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "color_temp", v);
                HomeAssistantService.setColorTemp(entityData.entityId, v);
            }
            displayValue: value
        }

    }

    // Color
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: HassConstants.lightSupportsColor(entityData)

        StyledText {
            text: I18n.tr("Color", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Flow {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: [{
                    "name": "White",
                    "r": 255,
                    "g": 255,
                    "b": 255
                }, {
                    "name": "Red",
                    "r": 255,
                    "g": 0,
                    "b": 0
                }, {
                    "name": "Orange",
                    "r": 255,
                    "g": 127,
                    "b": 0
                }, {
                    "name": "Yellow",
                    "r": 255,
                    "g": 255,
                    "b": 0
                }, {
                    "name": "Green",
                    "r": 0,
                    "g": 255,
                    "b": 0
                }, {
                    "name": "Cyan",
                    "r": 0,
                    "g": 255,
                    "b": 255
                }, {
                    "name": "Blue",
                    "r": 0,
                    "g": 0,
                    "b": 255
                }, {
                    "name": "Purple",
                    "r": 127,
                    "g": 0,
                    "b": 255
                }, {
                    "name": "Pink",
                    "r": 255,
                    "g": 0,
                    "b": 127
                }]

                delegate: StyledRect {
                    width: 28
                    height: 28
                    radius: 14
                    color: Qt.rgba(modelData.r / 255, modelData.g / 255, modelData.b / 255, 1)
                    border.width: 2
                    border.color: Theme.outline

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HomeAssistantService.setLightColor(entityData.entityId, modelData.r, modelData.g, modelData.b)
                    }

                }

            }

        }

    }

    // Effects
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: {
            const list = root.getVal("effect_list", []);
            return list && list.length > 0;
        }

        StyledText {
            text: I18n.tr("Effect", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: root.getVal("effect_list", [])

                delegate: StyledRect {
                    height: 30
                    width: Math.max(60, effText.implicitWidth + 24)
                    radius: 15
                    color: {
                        const current = root.getVal("effect", "");
                        return (current === modelData) ? Theme.primary : Theme.surfaceContainerHigh;
                    }

                    StyledText {
                        id: effText

                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: {
                            const current = root.getVal("effect", "");
                            return (current === modelData) ? Font.Bold : Font.Normal;
                        }
                        color: {
                            const current = root.getVal("effect", "");
                            return (current === modelData) ? Theme.onPrimary : Theme.surfaceText;
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            HomeAssistantService.setOptimisticState(entityData.entityId, "effect", modelData);
                            HomeAssistantService.setLightEffect(entityData.entityId, modelData);
                        }
                    }

                }

            }

        }

    }

}
