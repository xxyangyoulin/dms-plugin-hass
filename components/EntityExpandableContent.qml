import QtQuick
import qs.Common

Column {
    id: root

    property bool expanded: false

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS
    visible: height > 0
    opacity: root.expanded ? 1 : 0
    height: root.expanded ? implicitHeight : 0
    clip: true

    Behavior on height {
        NumberAnimation {
            duration: Theme.shorterDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shorterDuration
            easing.type: Easing.OutCubic
        }
    }
}
