import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property bool haAvailable: false
    property int entityCount: 0
    property string connectionStatus: "offline"
    property string connectionMessage: ""

    spacing: Theme.spacingM

    Item {
        width: parent.width
        height: parent.height / 3
    }

    DankIcon {
        name: haAvailable ? "info" : (connectionStatus === "connecting" ? "sync" : "error")
        size: 48
        color: haAvailable ? Theme.surfaceVariantText : ((connectionStatus === "connecting" || connectionStatus === "degraded") ? Theme.warning : Theme.error)
        anchors.horizontalCenter: parent.horizontalCenter
    }

    StyledText {
        text: {
            if (haAvailable) return I18n.tr("No entities configured", "Home Assistant empty state title");
            if (connectionStatus === "auth_error") return I18n.tr("Authentication failed", "Home Assistant auth error");
            if (connectionStatus === "connecting") return I18n.tr("Connecting to Home Assistant", "Home Assistant connecting state");
            return I18n.tr("Cannot connect to Home Assistant", "Home Assistant connection error");
        }
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
        anchors.horizontalCenter: parent.horizontalCenter
    }

    StyledText {
        text: {
            if (haAvailable) {
                return I18n.tr("Add entity IDs in the plugin settings to start monitoring.", "Home Assistant empty state hint");
            }
            if (connectionMessage) return connectionMessage;
            if (connectionStatus === "auth_error") {
                return I18n.tr("Check your Home Assistant access token in the plugin settings.", "Home Assistant auth error hint");
            }
            if (connectionStatus === "connecting") {
                return I18n.tr("Waiting for Home Assistant to complete authentication.", "Home Assistant connecting hint");
            }
            return I18n.tr("Check your URL and access token in the plugin settings.", "Home Assistant connection error hint");
        }
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.spacingL * 2
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
