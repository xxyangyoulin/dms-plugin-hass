import QtQuick
import qs.Common

Column {
    id: root

    property bool expanded: false

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS
    visible: root.expanded
    opacity: visible ? 1 : 0
    height: visible ? implicitHeight : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.expressiveDurations["expressiveEffects"]
            easing.type: Theme.standardEasing
        }
    }
}
