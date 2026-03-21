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
        sections = EntityControlResolver.getFanSections(latestEntityData);
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
                case "speed_slider":
                    return speedSliderSection;
                case "speed_buttons":
                    return speedButtonsSection;
                case "oscillation":
                    return oscillationSection;
                case "preset_modes":
                    return presetSection;
                default:
                    return null;
                }
            }
        }
    }

    Component {
        id: speedSliderSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Speed", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            GenericSlider {
                width: parent.width
                value: parent.section.value
                step: parent.section.step
                maxValue: parent.section.maxValue
                icon: parent.section.icon
                displayValue: parent.section.displayValue
                onDragFinished: (v) => {
                    HomeAssistantService.setOptimisticState(root.entityData.entityId, "percentage", v);
                    HomeAssistantService.setFanSpeed(root.entityData.entityId, v);
                }
            }
        }
    }

    Component {
        id: speedButtonsSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Speed", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            SegmentedControl {
                width: parent.width
                value: parent.section.value
                options: parent.section.options
                unit: "%"
                onSelected: (v) => {
                    HomeAssistantService.setOptimisticState(root.entityData.entityId, "percentage", v);
                    HomeAssistantService.setFanSpeed(root.entityData.entityId, v);
                }
            }
        }
    }

    Component {
        id: oscillationSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Oscillation", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledRect {
                property var sectionData: parent.section
                width: parent.width
                height: 40
                radius: Theme.cornerRadius
                color: sectionData.value ? Theme.primary : Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "cached"
                        size: 18
                        color: parent.parent.sectionData.value ? root.selectedForegroundColor : Theme.surfaceText
                    }

                    StyledText {
                        text: parent.parent.sectionData.value ? I18n.tr("On", "State label") : I18n.tr("Off", "State label")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: parent.parent.sectionData.value ? root.selectedForegroundColor : Theme.surfaceText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const next = !parent.parent.sectionData.value;
                        HomeAssistantService.setOptimisticState(root.entityData.entityId, "oscillating", next);
                        HomeAssistantService.setOscillating(root.entityData.entityId, next);
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }

    Component {
        id: presetSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Preset", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            SegmentedControl {
                width: parent.width
                value: parent.section.value
                options: parent.section.options
                onSelected: (v) => {
                    HomeAssistantService.setOptimisticState(root.entityData.entityId, "preset_mode", v);
                    HomeAssistantService.setPresetMode(root.entityData.entityId, v);
                }
            }
        }
    }
}
