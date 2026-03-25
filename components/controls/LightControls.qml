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
    readonly property color selectedForegroundColor: Theme.primaryText || "#FFFFFF"
    property var sections: []

    function refreshSections() {
        const latestEntityData = entityData && entityData.entityId
            ? (HomeAssistantService.getEntityData(entityData.entityId) || entityData)
            : entityData;
        sections = EntityControlResolver.getLightSections(latestEntityData);
    }

    width: parent.width
    spacing: Theme.spacingS

    onEntityDataChanged: refreshSections()
    Component.onCompleted: refreshSections()

    Connections {
        target: HomeAssistantService

        function onEntityDataChanged(entityId) {
            if (root.entityData && root.entityData.entityId === entityId)
                root.refreshSections();
        }
    }

    Repeater {
        model: root.sections

        delegate: Loader {
            required property var modelData

            width: root.width
            property var section: modelData
            onLoaded: {
                if (item)
                    item.section = section;
            }
            sourceComponent: {
                switch (section.type) {
                case "brightness":
                    return brightnessSection;
                case "color_temp":
                    return colorTempSection;
                case "color":
                    return colorSection;
                case "effect":
                    return effectSection;
                default:
                    return null;
                }
            }
        }
    }

    Component {
        id: brightnessSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Brightness", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            GenericSlider {
                width: parent.width
                value: parent.section.value
                maxValue: parent.section.maxValue
                icon: parent.section.icon
                displayValue: parent.section.displayValue
                onDragFinished: (v) => {
                    HomeAssistantService.setOptimisticState(root.entityData.entityId, "brightness", v);
                    HomeAssistantService.setBrightness(root.entityData.entityId, v);
                }
            }
        }
    }

    Component {
        id: colorTempSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Color Temperature", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            GenericSlider {
                width: parent.width
                value: parent.section.value
                minValue: parent.section.minValue
                maxValue: parent.section.maxValue
                step: parent.section.step
                icon: parent.section.icon
                isColorTemp: true
                displayValue: parent.section.displayValue
                onDragFinished: (v) => {
                    HomeAssistantService.setOptimisticState(root.entityData.entityId, "color_temp_kelvin", v);
                    HomeAssistantService.setColorTemp(root.entityData.entityId, v);
                }
            }
        }
    }

    Component {
        id: colorSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Color", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS
                property var sectionData: parent.section

                Repeater {
                    model: parent.sectionData.palette

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
                            onClicked: HomeAssistantService.setLightColor(root.entityData.entityId, modelData.r, modelData.g, modelData.b)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: effectSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Effect", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Flow {
                width: parent.width
                spacing: 6
                property var sectionData: parent.section

                Repeater {
                    model: parent.sectionData.options

                    delegate: StyledRect {
                        readonly property bool isSelected: parent.sectionData.value === modelData
                        height: 30
                        width: Math.max(60, effectText.implicitWidth + 24)
                        radius: 15
                        color: isSelected ? Theme.primary : Theme.surfaceContainerHigh

                        StyledText {
                            id: effectText
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: parent.isSelected ? Font.Bold : Font.Normal
                            color: parent.isSelected ? root.selectedForegroundColor : Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                HomeAssistantService.setOptimisticState(root.entityData.entityId, "effect", modelData);
                                HomeAssistantService.setLightEffect(root.entityData.entityId, modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
