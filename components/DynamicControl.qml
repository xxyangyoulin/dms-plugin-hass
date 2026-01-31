import QtQuick
import qs.Common
import qs.Widgets
import "../services"
import "." as Components

// Dynamic control that renders based on HA selector type
Item {
    id: root
    
    // Required properties
    required property var fieldDef      // Field definition from /api/services
    required property string fieldName  // Field name (e.g., "percentage", "brightness")
    required property var currentValue  // Current value from entity attributes
    required property string entityId   // Entity ID for service calls
    required property string domain     // Entity domain
    
    signal valueChanged(var newValue)
    
    implicitHeight: controlLoader.height
    implicitWidth: parent ? parent.width : 200
    
    // Extract selector info from field definition
    readonly property var selector: fieldDef && fieldDef.selector ? fieldDef.selector : {}
    readonly property string selectorType: {
        if (!selector) return "unknown";
        // Selector is an object like { "number": { min: 0, max: 100 } }
        const keys = Object.keys(selector);
        return keys.length > 0 ? keys[0] : "unknown";
    }
    readonly property var selectorConfig: selector[selectorType] || {}
    
    Column {
        id: controlColumn
        width: parent.width
        spacing: Theme.spacingS
        
        // Label
        StyledText {
            visible: fieldDef && fieldDef.name
            text: fieldDef && fieldDef.name ? fieldDef.name : fieldName
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        
        // Control loader based on selector type
        Loader {
            id: controlLoader
            width: parent.width
            sourceComponent: {
                switch (root.selectorType) {
                    case "boolean": return booleanControl;
                    case "number": return numberControl;
                    case "select": return selectControl;
                    default: return null;
                }
            }
        }
    }
    
    // Boolean control (Toggle)
    Component {
        id: booleanControl
        StyledRect {
            width: parent.width
            height: 40
            radius: Theme.cornerRadius
            color: root.currentValue ? Theme.primary : Theme.surfaceContainerHigh
            
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                
                DankIcon {
                    name: root.currentValue ? "check" : "close"
                    size: 18
                    color: root.currentValue ? Theme.onPrimary : Theme.surfaceText
                }
                
                StyledText {
                    text: root.currentValue ? I18n.tr("On", "State label") : I18n.tr("Off", "State label")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.currentValue ? Theme.onPrimary : Theme.surfaceText
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.valueChanged(!root.currentValue)
            }
        }
    }
    
    // Number control (Slider)
    Component {
        id: numberControl
        Components.GenericSlider {
            width: parent.width
            value: root.currentValue || 0
            minValue: root.selectorConfig.min || 0
            maxValue: root.selectorConfig.max || 100
            step: root.selectorConfig.step || 1
            icon: "tune"
            displayValue: Math.round(value) + (root.selectorConfig.unit_of_measurement || "")
            onChanged: (v) => root.valueChanged(v)
        }
    }
    
    // Select control (Dropdown/Buttons)
    Component {
        id: selectControl
        Components.SegmentedControl {
            width: parent.width
            value: root.currentValue
            options: root.selectorConfig.options || []
            onSelected: (v) => root.valueChanged(v)
        }
    }
}
