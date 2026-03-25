import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    required property bool visibleWhenActive
    required property bool actionPending
    required property bool actionError
    required property bool activeState
    required property string iconName
    required property color activeColor
    required property color inactiveColor
    required property color activeIconColor
    required property color inactiveIconColor

    signal clicked()

    width: root.visibleWhenActive ? 40 : 0
    height: 40
    radius: 20
    visible: root.visibleWhenActive
    color: {
        if (root.actionError)
            return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.14);
        if (root.activeState)
            return Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.92);
        return Qt.rgba(root.inactiveColor.r, root.inactiveColor.g, root.inactiveColor.b, 0.72);
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "#000000"
        opacity: buttonHover.hovered ? 0.1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    DankIcon {
        name: root.iconName
        size: 20
        color: root.actionError
            ? Theme.error
            : (root.activeState ? root.activeIconColor : root.inactiveIconColor)
        anchors.centerIn: parent
    }

    HoverHandler {
        id: buttonHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        enabled: !root.actionPending
        onTapped: root.clicked()
    }
}
