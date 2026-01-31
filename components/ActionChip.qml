import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../services"
import "."

StyledRect {
    id: root
    
    required property var entityData
    
    // Safety check
    visible: entityData !== undefined && entityData !== null

    width: visible ? Math.min(160, Math.max(120, row.implicitWidth + Theme.spacingM * 2)) : 0
    height: visible ? 36 : 0
    radius: 18
    color: mouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
    border.width: 1
    border.color: mouseArea.containsMouse ? Theme.primary : "transparent"
    
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
    
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: parent.visible
        
        DankIcon {
            name: parent.visible ? HassConstants.getIconForDomain(entityData.domain) : ""
            size: 16
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }
        
        StyledText {
            text: parent.visible ? entityData.friendlyName : ""
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(parent.parent.width - 40, implicitWidth)
            elide: Text.ElideRight
        }
    }
    
    // Ripple/Feedback effect
    Rectangle {
        id: feedback
        anchors.fill: parent
        radius: parent.radius
        color: Theme.primary
        opacity: 0
        visible: opacity > 0
    }
    
    SequentialAnimation {
        id: triggerAnim
        NumberAnimation { target: feedback; property: "opacity"; from: 0.3; to: 0; duration: 400; easing.type: Easing.OutQuad }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!entityData) return;
            HomeAssistantService.triggerScript(entityData.entityId);
            triggerAnim.start();
            ToastService.showInfo(I18n.tr("Triggered", "Action notification") + " " + entityData.friendlyName);
        }
    }
}
