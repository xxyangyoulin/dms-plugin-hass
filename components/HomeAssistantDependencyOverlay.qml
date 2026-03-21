import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    required property bool missingDependency

    anchors.fill: parent
    z: 999
    color: Theme.surface
    visible: root.missingDependency

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingM

        DankIcon {
            name: "error"
            size: 48
            color: Theme.error
            Layout.alignment: Qt.AlignHCenter
        }

        StyledText {
            text: I18n.tr("Missing Dependency", "Error title")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.error
            Layout.alignment: Qt.AlignHCenter
        }

        StyledText {
            text: I18n.tr("Please install 'qt6-websockets' package and then RESTART DMS to use this plugin.", "Error description")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            Layout.maximumWidth: parent.width - Theme.spacingXL * 2
            wrapMode: Text.WordWrap
        }
    }
}
