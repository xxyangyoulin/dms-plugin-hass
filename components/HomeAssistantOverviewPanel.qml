import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    required property bool haAvailable
    required property string connectionStatus
    required property string connectionMessage
    required property bool isEditing
    required property bool manualRefreshInProgress

    signal requestToggleEditing()
    signal requestRefresh()

    readonly property color statusColor: {
        if (root.connectionStatus === "auth_error" || root.connectionStatus === "offline")
            return Theme.error;
        if (root.connectionStatus === "connecting" || root.connectionStatus === "degraded")
            return Theme.warning;
        if (!root.haAvailable)
            return Theme.error;
        return Theme.primary;
    }

    readonly property string titleText: {
        if (root.connectionStatus === "auth_error")
            return I18n.tr("Home Assistant authentication failed", "Home Assistant connection error");
        if (root.connectionStatus === "connecting")
            return I18n.tr("Connecting to Home Assistant", "Home Assistant status");
        if (root.connectionStatus === "degraded")
            return I18n.tr("Home Assistant connection degraded", "Home Assistant status");
        if (!root.haAvailable)
            return I18n.tr("Home Assistant unavailable", "Home Assistant connection error");
        return I18n.tr("Home Assistant", "Home Assistant dashboard title");
    }

    readonly property string subtitleText: {
        if (root.connectionStatus === "auth_error")
            return I18n.tr("Update the token in settings to restore entity updates.", "Home Assistant auth subtitle");
        if (root.connectionStatus === "connecting")
            return I18n.tr("Authenticating and loading your monitored entities.", "Home Assistant connecting subtitle");
        if (root.connectionStatus === "degraded")
            return I18n.tr("The server is reachable, but syncs are taking longer than expected.", "Home Assistant degraded subtitle");
        if (!root.haAvailable)
            return I18n.tr("Review your URL and access token if the dashboard stays offline.", "Home Assistant offline subtitle");
        return "";
    }
    readonly property bool showStatusNotice: ["connecting", "degraded", "offline", "auth_error"].indexOf(root.connectionStatus) >= 0
    readonly property string statusNoticeText: {
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

    radius: Theme.cornerRadius * 1.2
    color: Theme.surfaceContainerHigh || Theme.surfaceContainer
    border.width: 1
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
    height: overviewContent.implicitHeight + Theme.spacingM * 2

    Column {
        id: overviewContent
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            width: parent.width
            height: Math.max(34, titleBlock.implicitHeight, actionButtons.implicitHeight)
            spacing: Theme.spacingM

            Rectangle {
                width: 34
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.10)

                DankIcon {
                    anchors.centerIn: parent
                    name: root.connectionStatus === "connecting" ? "sync"
                          : (root.connectionStatus === "degraded" ? "warning"
                          : (root.connectionStatus === "auth_error" || root.connectionStatus === "offline" ? "error" : "home"))
                    size: 18
                    color: root.statusColor
                }
            }

            Column {
                id: titleBlock
                width: parent.width - actionButtons.implicitWidth - 34 - Theme.spacingM * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: root.titleText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                StyledText {
                    text: root.subtitleText
                    visible: text.length > 0
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                    width: parent.width
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
            }

            Row {
                id: actionButtons
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                PanelActionButton {
                    iconName: root.isEditing ? "check" : "edit"
                    active: root.isEditing
                    onClicked: root.requestToggleEditing()
                }

                RefreshButton {
                    spinning: root.manualRefreshInProgress
                    onClicked: root.requestRefresh()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: statusRow.implicitHeight + Theme.spacingS * 2
            visible: root.showStatusNotice
            radius: Theme.cornerRadius
            color: root.connectionStatus === "auth_error" || root.connectionStatus === "offline"
                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08)
                : Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.08)
            border.width: 1
            border.color: root.connectionStatus === "auth_error" || root.connectionStatus === "offline"
                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                : Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.18)

            Row {
                id: statusRow
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingS

                DankIcon {
                    name: root.connectionStatus === "connecting" ? "sync"
                          : (root.connectionStatus === "degraded" ? "warning" : "error")
                    size: 14
                    color: root.connectionStatus === "auth_error" || root.connectionStatus === "offline" ? Theme.error : Theme.warning
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    width: parent.width - 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.statusNoticeText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }
            }
        }
    }
}
