import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    signal clicked
    property bool isActive: false

    width: 36
    height: 36
    radius: Theme.cornerRadius
    color: isActive ? Theme.primaryContainer : Qt.rgba(0, 0, 0, 0)

    DankIcon {
        anchors.centerIn: parent
        name: isActive ? "expand_less" : "add"
        size: 18
        color: isActive ? Theme.primary : Theme.surfaceText
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
