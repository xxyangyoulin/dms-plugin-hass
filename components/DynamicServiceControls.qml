import QtQuick
import qs.Common
import qs.Widgets
import "../services"
import "." as Components

// Renders dynamic controls for a domain based on /api/services definitions
Column {
    id: root
    
    required property var entityData
    required property string domain
    
    width: parent ? parent.width : 200
    spacing: Theme.spacingM
    
    // Check if services are loaded
    readonly property bool servicesReady: HomeAssistantService.servicesLoaded
    readonly property var domainServices: servicesReady ? (HomeAssistantService.servicesCache[domain] || {}) : {}
    
    // Filter to only show services that take entity_id and have interesting fields
    readonly property var editableServices: {
        if (!servicesReady) return [];
        
        const services = [];
        const svcNames = Object.keys(domainServices);
        
        for (const svcName of svcNames) {
            const svc = domainServices[svcName];
            if (!svc || !svc.fields) continue;
            
            // Skip toggle/turn_on/turn_off (already handled)
            if (["toggle", "turn_on", "turn_off"].includes(svcName)) continue;
            
            // Check for fields with selectors we can render
            const fieldNames = Object.keys(svc.fields);
            for (const fieldName of fieldNames) {
                if (fieldName === "entity_id") continue;
                
                const field = svc.fields[fieldName];
                if (field && field.selector) {
                    const selectorType = Object.keys(field.selector)[0];
                    if (["boolean", "number", "select"].includes(selectorType)) {
                        services.push({
                            serviceName: svcName,
                            fieldName: fieldName,
                            field: field,
                            selectorType: selectorType,
                            selectorConfig: field.selector[selectorType] || {}
                        });
                    }
                }
            }
        }
        
        return services.slice(0, 5); // Limit to 5 controls
    }
    
    visible: editableServices.length > 0
    
    StyledText {
        text: I18n.tr("Service Controls", "Section label")
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
        visible: root.editableServices.length > 0
    }
    
    Repeater {
        model: root.editableServices
        
        delegate: Column {
            width: parent.width
            spacing: Theme.spacingS
            
            property var svcInfo: modelData
            
            StyledText {
                text: (svcInfo.field.name || svcInfo.fieldName.replace(/_/g, " "))
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
            
            Loader {
                width: parent.width
                sourceComponent: {
                    switch (svcInfo.selectorType) {
                        case "number": return numberControl;
                        case "boolean": return booleanControl;
                        case "select": return selectControl;
                        default: return null;
                    }
                }
                
                property var selectorConfig: svcInfo.selectorConfig
                property string serviceName: svcInfo.serviceName
                property string fieldName: svcInfo.fieldName
            }
        }
    }
    
    // Number control component
    Component {
        id: numberControl
        Components.GenericSlider {
            width: parent.width
            value: entityData && entityData.attributes ? (entityData.attributes[parent.fieldName] || parent.selectorConfig.min || 0) : 0
            minValue: parent.selectorConfig.min || 0
            maxValue: parent.selectorConfig.max || 100
            step: parent.selectorConfig.step || 1
            icon: "tune"
            displayValue: Math.round(value) + (parent.selectorConfig.unit_of_measurement || "")
            onChanged: (v) => {
                const data = {};
                data[parent.fieldName] = v;
                HomeAssistantService.callService(root.domain, parent.serviceName, entityData.entityId, data);
            }
        }
    }
    
    // Boolean control component
    Component {
        id: booleanControl
        StyledRect {
            width: parent.width
            height: 40
            radius: Theme.cornerRadius
            
            property bool currentVal: entityData && entityData.attributes ? (entityData.attributes[parent.fieldName] || false) : false
            
            color: currentVal ? Theme.primary : Theme.surfaceContainerHigh
            
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                
                DankIcon {
                    name: parent.parent.currentVal ? "check" : "close"
                    size: 18
                    color: parent.parent.currentVal ? Theme.onPrimary : Theme.surfaceText
                }
                
                StyledText {
                    text: parent.parent.currentVal ? I18n.tr("On", "State label") : I18n.tr("Off", "State label")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: parent.parent.currentVal ? Theme.onPrimary : Theme.surfaceText
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const data = {};
                    data[parent.parent.parent.fieldName] = !parent.currentVal;
                    HomeAssistantService.callService(root.domain, parent.parent.parent.serviceName, entityData.entityId, data);
                }
            }
        }
    }
    
    // Select control component
    Component {
        id: selectControl
        Components.SegmentedControl {
            width: parent.width
            value: entityData && entityData.attributes ? (entityData.attributes[parent.fieldName] || "") : ""
            options: parent.selectorConfig.options || []
            onSelected: (v) => {
                const data = {};
                data[parent.fieldName] = v;
                HomeAssistantService.callService(root.domain, parent.serviceName, entityData.entityId, data);
            }
        }
    }
}
