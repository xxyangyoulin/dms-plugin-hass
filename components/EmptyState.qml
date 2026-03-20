import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property bool haAvailable: false
    property int entityCount: 0
    property string connectionStatus: "offline"
    property string connectionMessage: ""
    readonly property bool connectionIssue: !haAvailable || ["connecting", "degraded", "offline", "auth_error"].indexOf(connectionStatus) >= 0
    readonly property color statusColor: {
        if (connectionStatus === "auth_error" || connectionStatus === "offline") return Theme.error;
        if (connectionStatus === "connecting" || connectionStatus === "degraded") return Theme.warning;
        return Theme.primary;
    }
    readonly property string iconName: {
        if (haAvailable && entityCount === 0) return "dashboard_customize";
        if (connectionStatus === "auth_error") return "lock";
        if (connectionStatus === "connecting") return "sync";
        if (connectionStatus === "degraded") return "warning";
        return "error";
    }
    readonly property string titleText: {
        if (haAvailable && entityCount === 0) return I18n.tr("No monitored entities yet", "Home Assistant empty state title");
        if (connectionStatus === "auth_error") return I18n.tr("Authentication failed", "Home Assistant auth error");
        if (connectionStatus === "connecting") return I18n.tr("Connecting to Home Assistant", "Home Assistant connecting state");
        if (connectionStatus === "degraded") return I18n.tr("Connection is unstable", "Home Assistant degraded state");
        return I18n.tr("Cannot connect to Home Assistant", "Home Assistant connection error");
    }
    readonly property string bodyText: {
        if (haAvailable && entityCount === 0) {
            return I18n.tr("Open the browser panel and add entities you want to keep on this dashboard.", "Home Assistant empty state hint");
        }
        if (connectionMessage) return connectionMessage;
        if (connectionStatus === "auth_error") {
            return I18n.tr("Check your Home Assistant access token in the plugin settings and retry the connection.", "Home Assistant auth error hint");
        }
        if (connectionStatus === "connecting") {
            return I18n.tr("Waiting for Home Assistant to complete authentication and return the initial entity list.", "Home Assistant connecting hint");
        }
        if (connectionStatus === "degraded") {
            return I18n.tr("The server is reachable, but requests are timing out or reconnecting. Monitoring may be incomplete.", "Home Assistant degraded hint");
        }
        return I18n.tr("Check your Home Assistant URL and access token in the plugin settings.", "Home Assistant connection error hint");
    }
    readonly property string supportText: {
        if (haAvailable && entityCount === 0) return I18n.tr("Tip: pin frequently used entities to the status bar after adding them.", "Home Assistant empty state support");
        if (connectionStatus === "auth_error") return I18n.tr("The token likely expired or no longer has the required permissions.", "Home Assistant auth support");
        if (connectionStatus === "connecting") return I18n.tr("This panel will populate automatically once the first sync completes.", "Home Assistant connecting support");
        if (connectionStatus === "degraded") return I18n.tr("If this persists, verify the server is not under heavy load and that WebSocket access is enabled.", "Home Assistant degraded support");
        return I18n.tr("If the server is online, re-open the plugin after updating the connection settings.", "Home Assistant connection support");
    }

    spacing: Theme.spacingL

    Item {
        width: parent.width
        height: Math.max(24, parent.height * 0.12)
    }

    Rectangle {
        width: Math.min(parent.width - Theme.spacingXL * 2, 360)
        height: contentColumn.implicitHeight + Theme.spacingXL * 2
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Theme.cornerRadius * 1.6
        color: Theme.surfaceContainerHigh || Theme.surfaceContainer
        border.width: 1
        border.color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.18)

        Column {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingM

            Rectangle {
                width: 64
                height: 64
                radius: 32
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.12)

                DankIcon {
                    name: root.iconName
                    size: 30
                    color: root.statusColor
                    anchors.centerIn: parent
                }
            }

            StyledText {
                text: root.titleText
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                text: root.bodyText
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: parent.width
                height: supportLabel.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerLowest || Theme.surfaceContainer

                StyledText {
                    id: supportLabel
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    text: root.supportText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
