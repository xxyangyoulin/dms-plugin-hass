import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var options: [] // Array of values e.g. [33, 66, 100]
    property var labels: [] // Optional: Array of labels corresponding to values
    property var value: null
    property string unit: ""
    property string icon: ""
    property int buttonHeight: 30
    property int minimumButtonWidth: 60
    readonly property color selectedForegroundColor: Theme.primaryText || "#FFFFFF"
    signal selected(var value)

    function labelFor(modelData, index) {
        if (root.labels && root.labels.length > index)
            return root.labels[index];

        return (typeof modelData === "number" ? Math.round(modelData) : modelData) + root.unit;
    }

    // Find the index of the closest option to the current value
    function findClosestOptionIndex() {
        if (!root.options || root.options.length === 0 || root.value === null)
            return -1;

        // Handle string options (exact match)
        if (typeof root.options[0] === "string")
            return root.options.indexOf(root.value);

        // Handle numeric options (proximity match)
        let closestIdx = 0;
        let minDiff = Math.abs(root.value - root.options[0]);
        for (let i = 1; i < root.options.length; i++) {
            const diff = Math.abs(root.value - root.options[i]);
            if (diff < minDiff) {
                minDiff = diff;
                closestIdx = i;
            }
        }
        // Only consider it a match if within reasonable threshold (half a step)
        const threshold = root.options.length > 1 ? Math.abs(root.options[1] - root.options[0]) / 2 : 5;
        return minDiff <= threshold ? closestIdx : -1;
    }

    implicitHeight: layout.childrenRect.height
    implicitWidth: 200 // Default, but expands

    Flow {
        id: layout

        width: root.width
        spacing: 6

        Repeater {
            model: root.options

            delegate: StyledRect {
                id: btn

                // Check if this is the closest option to current value
                property bool isSelected: index === root.findClosestOptionIndex()
                readonly property bool showIcon: root.icon !== "" && isSelected

                height: root.buttonHeight
                width: Math.min(root.width, Math.max(root.minimumButtonWidth,
                    label.implicitWidth + 24 + (root.icon !== "" ? 14 + Theme.spacingXS : 0)))
                radius: root.buttonHeight / 2
                clip: true
                color: isSelected ? Theme.primary : Theme.surfaceContainerHigh

                Row {
                    id: content

                    readonly property int maxWidth: Math.max(0, btn.width - Theme.spacingS * 2)

                    width: Math.min(maxWidth, (selectedIcon.visible ? selectedIcon.width + spacing : 0) + label.implicitWidth)
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        id: selectedIcon

                        name: root.icon
                        size: 14
                        visible: btn.showIcon
                        color: btn.isSelected ? root.selectedForegroundColor : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: label

                        text: root.labelFor(modelData, index)
                        width: parent.width - (selectedIcon.visible ? selectedIcon.width + parent.spacing : 0)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: btn.isSelected ? Font.Bold : Font.Normal
                        color: btn.isSelected ? root.selectedForegroundColor : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(modelData)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }

                }

            }

        }

    }

}
