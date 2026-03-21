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
    property var sections: []

    function refreshSections() {
        const latestEntityData = entityData && entityData.entityId
            ? (HomeAssistantService.getEntityData(entityData.entityId) || entityData)
            : entityData;
        sections = EntityControlResolver.getClimateSections(latestEntityData);
    }

    width: parent.width
    spacing: Theme.spacingM

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
                case "temperature":
                    return temperatureSection;
                case "hvac_modes":
                case "fan_modes":
                case "preset_modes":
                case "swing_modes":
                    return segmentedSection;
                default:
                    return null;
                }
            }
        }
    }

    Component {
        id: temperatureSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Temperature Control", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Row {
                property var sectionData: parent.section
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
                            const next = parent.parent.sectionData.value - parent.parent.sectionData.step;
                            HomeAssistantService.setOptimisticState(root.entityData.entityId, "temperature", next);
                            HomeAssistantService.setTemperature(root.entityData.entityId, next);
                        }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: parent.parent.sectionData.value.toFixed(1) + parent.parent.sectionData.unit
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.primary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        visible: parent.parent.sectionData.currentTemperature !== undefined
                        text: I18n.tr("Current:", "Label") + " " + parent.parent.sectionData.currentTemperature.toFixed(1) + parent.parent.sectionData.unit
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
                            const next = parent.parent.sectionData.value + parent.parent.sectionData.step;
                            HomeAssistantService.setOptimisticState(root.entityData.entityId, "temperature", next);
                            HomeAssistantService.setTemperature(root.entityData.entityId, next);
                        }
                    }
                }
            }
        }
    }

    Component {
        id: segmentedSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr(section.label, "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            SegmentedControl {
                width: parent.width
                value: parent.section.value
                options: parent.section.options
                icon: parent.section.icon || ""
                onSelected: (v) => {
                    switch (parent.section.type) {
                    case "hvac_modes":
                        HomeAssistantService.setOptimisticState(root.entityData.entityId, "state", v);
                        HomeAssistantService.setHvacMode(root.entityData.entityId, v);
                        break;
                    case "fan_modes":
                        HomeAssistantService.setOptimisticState(root.entityData.entityId, "fan_mode", v);
                        HomeAssistantService.setClimateFanMode(root.entityData.entityId, v);
                        break;
                    case "preset_modes":
                        HomeAssistantService.setOptimisticState(root.entityData.entityId, "preset_mode", v);
                        HomeAssistantService.setPresetMode(root.entityData.entityId, v);
                        break;
                    case "swing_modes":
                        HomeAssistantService.setOptimisticState(root.entityData.entityId, "swing_mode", v);
                        HomeAssistantService.setOption(root.entityData.entityId, "climate", "swing_mode", v);
                        break;
                    default:
                        break;
                    }
                }
            }
        }
    }
}
