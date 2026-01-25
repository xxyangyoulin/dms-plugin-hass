import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    signal clicked

    width: 36
    height: 36
    radius: Theme.cornerRadius
    color: Qt.rgba(0, 0, 0, 0)

    DankIcon {
        anchors.centerIn: parent
        name: "refresh"
        size: 18
        color: Theme.surfaceText
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
