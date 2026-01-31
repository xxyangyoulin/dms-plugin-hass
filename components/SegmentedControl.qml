import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root
    
    // Properties
    property var options: [] // Array of values e.g. [33, 66, 100]
    property var labels: []  // Optional: Array of labels corresponding to values
    property var value: null
    property string unit: ""
    property string icon: ""
    
    signal selected(var value)
    
    implicitHeight: 40
    implicitWidth: 200 // Default, but expands

    // Find the index of the closest option to the current value
    function findClosestOptionIndex() {
        if (!root.options || root.options.length === 0 || root.value === null) {
            return -1;
        }
        
        // Handle string options (exact match)
        if (typeof root.options[0] === "string") {
            return root.options.indexOf(root.value);
        }
        
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
        const threshold = root.options.length > 1 
            ? Math.abs(root.options[1] - root.options[0]) / 2 
            : 5;
        
        return minDiff <= threshold ? closestIdx : -1;
    }
    
    Row {
        id: layout
        anchors.fill: parent
        spacing: Theme.spacingS
        
        Repeater {
            model: root.options
            
            delegate: StyledRect {
                id: btn
                
                // Check if this is the closest option to current value
                property bool isSelected: index === root.findClosestOptionIndex()
                
                height: root.height
                width: (root.width - (layout.spacing * (root.options.length - 1))) / root.options.length
                radius: Theme.cornerRadius
                
                color: isSelected ? Theme.primary : Theme.surfaceContainerHigh
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS
                    visible: root.icon !== "" && btn.isSelected

                    DankIcon {
                        name: root.icon
                        size: 14
                        color: btn.isSelected ? Theme.onPrimary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: {
                            if (root.labels && root.labels.length > index) {
                                return root.labels[index];
                            }
                            return Math.round(modelData) + root.unit;
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: btn.isSelected ? Font.Bold : Font.Medium
                        color: btn.isSelected ? Theme.onPrimary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    id: label
                    anchors.centerIn: parent
                    visible: root.icon === "" || !btn.isSelected
                    text: {
                        if (root.labels && root.labels.length > index) {
                            return root.labels[index];
                        }
                        return (typeof modelData === "number" ? Math.round(modelData) : modelData) + root.unit;
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: btn.isSelected ? Font.Bold : Font.Medium
                    color: btn.isSelected ? Theme.onPrimary : Theme.surfaceText
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(modelData)
                }
            }
        }
    }
}
