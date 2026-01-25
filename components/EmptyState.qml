import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property bool haAvailable: false
    property int entityCount: 0

    spacing: Theme.spacingM

    Item {
        width: parent.width
        height: parent.height / 3
    }

    DankIcon {
        name: haAvailable ? "info" : "error"
        size: 48
        color: haAvailable ? Theme.surfaceVariantText : Theme.error
        anchors.horizontalCenter: parent.horizontalCenter
    }

    StyledText {
        text: haAvailable ? I18n.tr("No entities configured", "Home Assistant empty state title") : I18n.tr("Cannot connect to Home Assistant", "Home Assistant connection error")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
        anchors.horizontalCenter: parent.horizontalCenter
    }

    StyledText {
        text: haAvailable ?
            I18n.tr("Add entity IDs in the plugin settings to start monitoring.", "Home Assistant empty state hint") :
            I18n.tr("Check your URL and access token in the plugin settings.", "Home Assistant connection error hint")
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.spacingL * 2
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
