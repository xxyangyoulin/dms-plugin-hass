import QtQuick
import QtQuick.Layouts
import "." as Components
import "../services"
import qs.Common
import qs.Widgets

Column {
    id: root

    required property var relatedEntities
    property bool isEditing: false
    property bool pickerVisible: true
    property string baseName: ""
    property var selectedEntityIds: []

    signal addEntity(string entityId)
    signal removeEntity(string entityId)

    function isSelected(entityId) {
        return selectedEntityIds.includes(entityId);
    }

    function shortEntityName(entity) {
        if (!entity)
            return "";
        const name = entity.friendlyName || entity.entityId || "";
        const base = root.baseName.replace(/\s+(空调|灯|开关|风扇|传感器)$/, "").trim();
        if (base && name.startsWith(base))
            return name.slice(base.length).replace(/^[\s*]+/, "").trim() || name;
        return name;
    }

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS
    visible: root.pickerVisible && (root.isEditing || (root.relatedEntities && root.relatedEntities.length > 0))

    StyledText {
        text: I18n.tr("Connected Entities", "Control label")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.relatedEntities && root.relatedEntities.length > 0

        Repeater {
            model: root.visible ? root.relatedEntities : []

            delegate: StyledRect {
                height: 36
                width: parent.width
                radius: 6
                color: Theme.surfaceContainerHigh

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingS

                    StyledText {
                        text: root.shortEntityName(modelData)
                        font.pixelSize: 10
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        width: parent.width - stateText.width - (actionButton.visible ? actionButton.width + Theme.spacingS : 0) - Theme.spacingS * 2
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 1
                    }

                    StyledText {
                        id: stateText
                        text: {
                            const translationVersion = HomeAssistantService.translationsVersion;
                            return HomeAssistantService.formatEntityState(modelData.domain || "", modelData.state, modelData.unitOfMeasurement);
                        }
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    EditActionButton {
                        id: actionButton
                        width: 26
                        height: 26
                        visible: root.isEditing
                        iconName: root.isSelected(modelData.entityId) ? "close" : "add"
                        iconSize: 13
                        iconColor: root.isSelected(modelData.entityId) ? Theme.primaryText : Theme.surfaceText
                        backgroundColor: root.isSelected(modelData.entityId) ? (Theme.error || "transparent") : (Theme.surfaceContainerHighest || "transparent")
                        onClicked: {
                            if (root.isSelected(modelData.entityId))
                                root.removeEntity(modelData.entityId);
                            else
                                root.addEntity(modelData.entityId);
                        }
                    }
                }
            }
        }
    }

    StyledText {
        visible: root.isEditing && (!root.relatedEntities || root.relatedEntities.length === 0)
        text: I18n.tr("No connected entities found for this device", "Empty state")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
}
