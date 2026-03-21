import QtQuick
import QtQuick.Layouts
import "." as Components
import qs.Common
import qs.Widgets

Column {
    id: root

    required property var relatedEntities

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS
    visible: root.relatedEntities && root.relatedEntities.length > 0

    StyledText {
        text: I18n.tr("Connected Entities", "Control label")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.relatedEntities

            delegate: StyledRect {
                height: 32
                width: (parent.width - Theme.spacingS) / 2 - 1
                radius: 6
                color: Theme.surfaceContainerHigh

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingS

                    DankIcon {
                        name: Components.HassConstants.getIconForDomain(modelData.domain)
                        size: 14
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: modelData.friendlyName
                        font.pixelSize: 10
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        width: parent.width - 60
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 1
                    }

                    StyledText {
                        text: Components.HassConstants.formatStateValue(modelData.state, modelData.unitOfMeasurement)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
