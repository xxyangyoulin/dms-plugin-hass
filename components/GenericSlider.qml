import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root
    height: 40

    property real value: 0
    property real minValue: 0
    property real maxValue: 100
    property string icon: ""
    property string displayValue: ""
    property bool isColorTemp: false
    property real step: 1
    property bool snap: true
    property string valueSuffix: "%"
    property bool showPercentage: true

    property real visualValue: value
    property bool isDragging: false

    onValueChanged: {
        if (!isDragging)
            visualValue = value;
    }

    signal previewValueChanged(real newValue)
    signal dragFinished(real newValue)

    function updateValue(mouseX, trackWidth) {
        const range = root.maxValue - root.minValue;
        if (range <= 0)
            return;

        const percent = Math.max(0, Math.min(1, mouseX / trackWidth));
        var rawVal = root.minValue + percent * range;

        if (root.snap && root.step > 0)
            rawVal = Math.round(rawVal / root.step) * root.step;

        const nextValue = Math.min(root.maxValue, Math.max(root.minValue, rawVal));
        if (nextValue === root.visualValue)
            return;

        root.visualValue = nextValue;
        root.previewValueChanged(root.visualValue);
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            name: root.icon
            size: 20
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            id: track
            width: parent.width - 100
            height: 12
            radius: 6
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 6
                visible: root.isColorTemp
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#ff9300" }
                    GradientStop { position: 1.0; color: "#a5c6ff" }
                }
            }

            Rectangle {
                width: {
                    const range = root.maxValue - root.minValue;
                    if (range <= 0)
                        return 0;
                    return ((root.visualValue - root.minValue) / range) * parent.width;
                }
                height: parent.height
                radius: 6
                color: Theme.primary
                visible: !root.isColorTemp
            }

            Rectangle {
                x: {
                    const range = root.maxValue - root.minValue;
                    if (range <= 0)
                        return 0;
                    const pos = ((root.visualValue - root.minValue) / range) * parent.width;
                    return Math.min(parent.width - width, Math.max(0, pos - width / 2));
                }
                width: 6
                height: 18
                radius: 3
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.isColorTemp || root.isDragging
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                cursorShape: Qt.PointingHandCursor

                onPressed: (mouse) => {
                    root.isDragging = true;
                    root.updateValue(mouse.x, width);
                }

                onPositionChanged: (mouse) => {
                    if (pressed)
                        root.updateValue(mouse.x, width);
                }

                onReleased: {
                    root.isDragging = false;
                    root.dragFinished(root.visualValue);
                }
            }
        }

        StyledText {
            text: {
                if (root.isDragging) {
                    if (root.isColorTemp)
                        return Math.round(root.visualValue);

                    if (root.showPercentage) {
                        const range = root.maxValue - root.minValue;
                        if (range <= 0)
                            return "0" + root.valueSuffix;
                        return Math.round(((root.visualValue - root.minValue) / range) * 100) + root.valueSuffix;
                    }

                    return Math.round(root.visualValue) + root.valueSuffix;
                }

                return root.displayValue;
            }
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: root.isDragging ? Theme.primary : Theme.surfaceText
            width: 50
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
