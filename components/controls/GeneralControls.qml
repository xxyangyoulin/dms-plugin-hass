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
    readonly property color selectedForegroundColor: Theme.primaryText || "#FFFFFF"
    property var sections: []

    function refreshSections() {
        const latestEntityData = entityData && entityData.entityId
            ? (HomeAssistantService.getEntityData(entityData.entityId) || entityData)
            : entityData;
        sections = EntityControlResolver.getGeneralSections(latestEntityData);
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
                case "number":
                    return numberSection;
                case "select":
                    return selectSection;
                case "button":
                    return buttonSection;
                case "options":
                    return optionsSection;
                default:
                    return null;
                }
            }
        }
    }

    Component {
        id: numberSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Value", "Control label")
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
                displayValue: parent.section.displayValue
                onDragFinished: (v) => {
                    HomeAssistantService.setOptimisticState(root.entityData.entityId, "state", v.toString());
                    HomeAssistantService.callService(root.entityData.domain, "set_value", root.entityData.entityId, {
                        value: v
                    });
                }
            }
        }
    }

    Component {
        id: selectSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Select", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Loader {
                width: parent.width
                property var sectionData: parent.section
                sourceComponent: sectionData.options.length <= 5 ? selectButtonsComponent : selectReadoutComponent

                Component {
                    id: selectButtonsComponent

                    SegmentedControl {
                        width: parent.width
                        options: parent.sectionData.options
                        value: parent.sectionData.value
                        labels: parent.sectionData.options
                        unit: ""
                        onSelected: (v) => {
                            HomeAssistantService.setOptimisticState(root.entityData.entityId, "state", v);
                            HomeAssistantService.callService(root.entityData.domain, "select_option", root.entityData.entityId, {
                                option: v
                            });
                        }
                    }
                }

                Component {
                    id: selectReadoutComponent

                    StyledRect {
                        property var sectionData: parent.sectionData

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
                                text: parent.parent.sectionData.value || "-"
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
    }

    Component {
        id: buttonSection

        StyledRect {
            property var section

            width: root.width
            height: 44
            radius: Theme.cornerRadius
            color: buttonMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.primary

            Row {
                property var sectionData: parent.section
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: parent.sectionData.icon
                    size: 20
                    color: Theme.primary
                }

                StyledText {
                    text: I18n.tr(parent.sectionData.label, "Button action label")
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
                onClicked: HomeAssistantService.callService(root.entityData.domain, "press", root.entityData.entityId, {})
            }

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }

    Component {
        id: optionsSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Options", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: parent.section.options

                    delegate: StyledRect {
                        readonly property bool isSelected: section.value === modelData
                        height: 30
                        width: Math.max(60, optionText.implicitWidth + 24)
                        radius: 15
                        color: isSelected ? Theme.primary : Theme.surfaceContainerHigh

                        StyledText {
                            id: optionText
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: parent.isSelected ? Font.Bold : Font.Medium
                            color: parent.isSelected ? root.selectedForegroundColor : Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                HomeAssistantService.setOptimisticState(root.entityData.entityId, "state", modelData);
                                HomeAssistantService.setOption(root.entityData.entityId, root.entityData.domain, "options", modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
