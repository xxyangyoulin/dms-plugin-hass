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

    property real visualValue: value
    property bool isDragging: false
    property bool blockSync: false

    Timer {
        id: syncLockTimer
        interval: 3000 // Block external updates for 3s after user interaction
        onTriggered: {
            root.blockSync = false;
            root.visualValue = root.value;
        }
    }

    onValueChanged: {
        if (!isDragging && !blockSync) {
            visualValue = value;
        }
    }

    signal changed(real newValue)

    function updateValue(mouseX, width) {
        const range = root.maxValue - root.minValue;
        if (range <= 0) return;
        const percent = Math.max(0, Math.min(1, mouseX / width));
        visualValue = root.minValue + percent * range;
        
        // Start/Restart sync lock
        blockSync = true;
        syncLockTimer.restart();
        
        root.changed(visualValue);
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
                    GradientStop { position: 0.0; color: "#a5c6ff" }
                    GradientStop { position: 1.0; color: "#ff9300" }
                }
            }

            Rectangle {
                width: {
                    const range = root.maxValue - root.minValue;
                    if (range <= 0) return 0;
                    return ((root.visualValue - root.minValue) / range) * parent.width;
                }
                height: parent.height
                radius: 6
                color: Theme.primary
                visible: !root.isColorTemp

                Behavior on width { 
                    enabled: !root.isDragging
                    NumberAnimation { duration: 150 } 
                }
            }

            Rectangle {
                x: {
                    const range = root.maxValue - root.minValue;
                    if (range <= 0) return 0;
                    const pos = ((root.visualValue - root.minValue) / range) * parent.width;
                    return Math.min(parent.width - width, Math.max(0, pos - width/2));
                }
                width: 6
                height: 18
                radius: 3
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.isColorTemp || root.isDragging

                Behavior on x { 
                    enabled: !root.isDragging
                    NumberAnimation { duration: 150 } 
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10 // Increase hit area
                cursorShape: Qt.PointingHandCursor
                
                onPressed: (mouse) => {
                    root.isDragging = true;
                    root.updateValue(mouse.x, width);
                }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        root.updateValue(mouse.x, width);
                    }
                }
                onReleased: {
                    root.isDragging = false;
                }
            }
        }

        StyledText {
            text: {
                if (root.isDragging || root.blockSync) {
                    // Use optimistic visual value for text as well
                    if (root.isColorTemp) return Math.round(root.visualValue);
                    
                    const range = root.maxValue - root.minValue;
                    if (range <= 0) return "0%";
                    
                    // Most controls in this plugin use percentage for non-color-temp sliders
                    return Math.round(((root.visualValue - root.minValue) / range) * 100) + "%";
                }
                return root.displayValue;
            }
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: (root.isDragging || root.blockSync) ? Theme.primary : Theme.surfaceText
            width: 50
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
