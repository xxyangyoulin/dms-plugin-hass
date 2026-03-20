import QtQuick
import qs.Common
import qs.Widgets

DankIcon {
    id: root

    property int barThickness: 32
    property bool haAvailable: false
    property int entityCount: 0
    property bool showHomeIcon: true
    property string connectionStatus: "offline"

    name: "home"
    size: Theme.barIconSize(barThickness, -4)
    visible: showHomeIcon
    color: {
        if (connectionStatus === "auth_error" || connectionStatus === "offline")
            return Theme.error;
        if (connectionStatus === "degraded" || connectionStatus === "connecting")
            return Theme.warning;
        if (!haAvailable)
            return Theme.error;
        if (entityCount > 0)
            return Theme.primary;
        return Theme.widgetIconColor || Theme.surfaceText;
    }
}
