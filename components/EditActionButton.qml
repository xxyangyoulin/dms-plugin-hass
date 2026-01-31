import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root
    
    property string iconName: ""
    property color iconColor: Theme.onSurface
    property color backgroundColor: Theme.surfaceContainerHigh
    property real backgroundOpacity: 0.7
    property real radius: height / 2
    property real iconSize: 16
    property real iconRotation: 0
    
    signal clicked()

    // Default size
    implicitWidth: 32
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.backgroundColor
        opacity: root.backgroundOpacity
        border.width: 1
        border.color: Theme.outline
        
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    DankIcon {
        name: root.iconName
        size: root.iconSize
        color: root.iconColor
        rotation: root.iconRotation
        anchors.centerIn: parent
        
        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        hoverEnabled: true
        
        // Simple hover effect
        onEntered: parent.opacity = 0.9
        onExited: parent.opacity = 1.0
    }
}
