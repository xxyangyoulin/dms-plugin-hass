import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../services"
import "."

Item {
    id: root

    property int orientation: Qt.Horizontal // or Qt.Vertical
    property bool haAvailable: false
    property int entityCount: 0
    property var pinnedEntitiesData: []
    property var customIcons: ({})
    property real barThickness: 0
    property bool showHomeIcon: true
    property bool showButtonsOnStatusBar: true

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // Helper functions
    function getEntityIcon(entityId, domain) {
        return customIcons[entityId] || HassConstants.getIconForDomain(domain);
    }

    function isSwitchable(entity) {
        if (!entity) return false;
        const domain = entity.domain;
        const switchableDomains = ["switch", "light", "input_boolean", "fan", "automation", "script", "group", "climate"];
        return switchableDomains.includes(domain);
    }

    // Dynamic layout based on orientation
    Loader {
        id: layout
        sourceComponent: root.orientation === Qt.Horizontal ? rowLayout : columnLayout
    }

    Component {
        id: rowLayout
        Row {
            spacing: Theme.spacingS
            
            HaIcon {
                barThickness: root.barThickness
                haAvailable: root.haAvailable
                entityCount: root.entityCount
                showHomeIcon: root.showHomeIcon
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.haAvailable || root.pinnedEntitiesData.length === 0
            }

            Repeater {
                model: root.pinnedEntitiesData
                delegate: entityDelegate
            }

            HaCount {
                entityCount: root.entityCount
                anchors.verticalCenter: parent.verticalCenter
                visible: root.pinnedEntitiesData.length === 0
            }
        }
    }

    Component {
        id: columnLayout
        Column {
            spacing: Theme.spacingXS

            HaIcon {
                barThickness: root.barThickness
                haAvailable: root.haAvailable
                entityCount: root.entityCount
                showHomeIcon: root.showHomeIcon
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.pinnedEntitiesData.length === 0
            }

            Repeater {
                model: root.pinnedEntitiesData
                delegate: entityDelegate
            }

            HaCount {
                entityCount: root.entityCount
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.pinnedEntitiesData.length === 0
            }
        }
    }

    // Shared Delegate
    Component {
        id: entityDelegate
        
        Item {
            // Calculate size based on orientation
            width: root.orientation === Qt.Horizontal ? rowContent.width : columnContent.width
            height: root.orientation === Qt.Horizontal ? rowContent.height : columnContent.height

            // Row Version
            Row {
                id: rowContent
                visible: root.orientation === Qt.Horizontal
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: root.getEntityIcon(modelData.entityId, modelData.domain)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: HassConstants.getStateColor(modelData.domain || "", modelData.state || "", Theme)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    active: root.isSwitchable(modelData) && root.showButtonsOnStatusBar
                    visible: active
                    sourceComponent: switchComponent
                }

                StyledText {
                    visible: !root.isSwitchable(modelData) || !root.showButtonsOnStatusBar
                    text: HassConstants.formatStateValue(modelData.state, modelData.unitOfMeasurement)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor || Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Column Version
            Column {
                id: columnContent
                visible: root.orientation === Qt.Vertical
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: root.getEntityIcon(modelData.entityId, modelData.domain)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: HassConstants.getStateColor(modelData.domain || "", modelData.state || "", Theme)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: root.isSwitchable(modelData) && root.showButtonsOnStatusBar
                    visible: active
                    sourceComponent: switchComponentVertical
                }

                StyledText {
                    visible: !root.isSwitchable(modelData) || !root.showButtonsOnStatusBar
                    text: HassConstants.formatStateValue(modelData.state, modelData.unitOfMeasurement)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor || Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Shared Switch Component Logic (reused for both, just sizing might differ slightly if needed, but here they look identical in logic)
            Component {
                id: switchComponent
                Rectangle {
                    width: 24; height: 14; radius: 7
                    property bool isActive: HassConstants.isActiveState(modelData.domain, modelData.state)
                    color: isActive ? Theme.primary : Theme.surfaceContainerHigh
                    
                    Rectangle {
                        width: 10; height: 10; radius: 5; color: "#FFFFFF"
                        x: parent.isActive ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleToggle(modelData)
                    }
                }
            }

            Component {
                id: switchComponentVertical
                Rectangle {
                    width: 24; height: 14; radius: 7
                    property bool isActive: HassConstants.isActiveState(modelData.domain, modelData.state)
                    color: isActive ? Theme.primary : Theme.surfaceContainerHigh
                    
                    Rectangle {
                        width: 10; height: 10; radius: 5; color: "#FFFFFF"
                        x: parent.isActive ? parent.width - width - 2 : 2
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.handleToggle(modelData)
                    }
                }
            }
        }
    }

    function handleToggle(modelData) {
        var domain = modelData.domain;
        var id = modelData.entityId;
        var state = modelData.state;
        
        if (domain === "script" || domain === "automation") {
            HomeAssistantService.triggerScript(id);
        } else if (domain === "climate") {
            var hvacModes = modelData.attributes && modelData.attributes.hvac_modes || ["off", "heat"];
            var nextState = state === "off" 
                ? (hvacModes.includes("heat") ? "heat" : hvacModes.find(m => m !== "off") || "heat")
                : "off";
            HomeAssistantService.setHvacMode(id, nextState);
        } else {
            HomeAssistantService.toggleEntity(id, domain, state);
        }
    }
}