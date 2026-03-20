import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    signal clicked

    property string iconName: ""
    property bool showIcon: true
    property bool active: false
    property bool busy: false
    property color accentColor: Theme.primary
    property color activeBackgroundColor: Theme.primaryContainer
    property color inactiveBackgroundColor: Theme.surfaceContainerHigh
    property color hoverBackgroundColor: Theme.surfaceContainerHighest || Theme.surfaceContainerHigh

    width: 36
    height: 36
    radius: Theme.cornerRadius
    color: {
        if (!root.enabled) {
            return Qt.rgba(inactiveBackgroundColor.r, inactiveBackgroundColor.g, inactiveBackgroundColor.b, 0.55);
        }
        if (root.active || root.busy) return activeBackgroundColor;
        if (buttonMouse.containsMouse) return hoverBackgroundColor;
        return inactiveBackgroundColor;
    }
    border.width: 0
    border.color: "transparent"

    Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    DankIcon {
        visible: root.showIcon
        anchors.centerIn: parent
        name: root.iconName
        size: 18
        color: {
            if (!root.enabled) return Theme.surfaceVariantText;
            return (root.active || root.busy) ? (Theme.primary || root.accentColor) : Theme.surfaceText;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.surfaceText
        opacity: buttonMouse.pressed ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled && !root.busy
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
