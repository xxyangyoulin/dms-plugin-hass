import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    required property string connectionStatus
    required property string connectionMessage

    visible: ["connecting", "degraded", "offline", "auth_error"].indexOf(root.connectionStatus) >= 0
    height: visible ? 32 : 0
    radius: Theme.cornerRadius
    color: root.connectionStatus === "auth_error" || root.connectionStatus === "offline"
        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
        : Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingS

        DankIcon {
            name: root.connectionStatus === "connecting" ? "sync"
                  : (root.connectionStatus === "degraded" ? "warning" : "error")
            size: 16
            color: root.connectionStatus === "auth_error" || root.connectionStatus === "offline" ? Theme.error : Theme.warning
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 24
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            elide: Text.ElideRight
            text: {
                if (root.connectionMessage)
                    return root.connectionMessage;
                if (root.connectionStatus === "connecting")
                    return I18n.tr("Connecting to Home Assistant", "Connection banner");
                if (root.connectionStatus === "degraded")
                    return I18n.tr("Home Assistant connection is unstable", "Connection banner");
                if (root.connectionStatus === "auth_error")
                    return I18n.tr("Home Assistant authentication failed", "Connection banner");
                return I18n.tr("Home Assistant is offline", "Connection banner");
            }
        }
    }
}
