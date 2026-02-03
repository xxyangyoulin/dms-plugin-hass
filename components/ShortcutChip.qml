import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../services"
import "."

StyledRect {
    id: root
    
    required property var shortcutData // { id, name, domain }
    property bool isEditing: false
    property bool isSelected: false
    property bool isRenaming: false

    signal requestDelete()
    signal requestRename(string newName)
    signal requestEdit()
    signal longPressed()
    signal requestSelect()
    signal requestMove(int offset)

    // Safety check
    visible: shortcutData !== undefined && shortcutData !== null

    // Use implicit size to suggest size to layout
    implicitWidth: isEditing ? Math.max(140, row.implicitWidth + Theme.spacingS * 2) : Math.max(100, row.implicitWidth + Theme.spacingS * 2)
    implicitHeight: 42
    height: 42
    radius: 21

    // Visual feedback for edit mode
    color: isSelected ? (Theme.primary || "transparent") : (isEditing ? Theme.surfaceContainerHigh : (mouseArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer))
    border.width: isSelected ? 2 : (isEditing ? 1 : (mouseArea.containsMouse ? 1 : 0))
    border.color: isSelected ? (Theme.primary || "transparent") : (isEditing ? (Theme.primary || "transparent") : (mouseArea.containsMouse ? (Theme.primary || "transparent") : "transparent"))

    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on border.width { NumberAnimation { duration: 150 } }
    
    // Reset state when not editing
    onIsEditingChanged: {
        if (!isEditing) {
            isRenaming = false;
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingS
        visible: parent.visible
        
        DankIcon {
            name: parent.visible ? HassConstants.getIconForDomain(shortcutData.domain) : ""
            size: 16
            color: Theme.primary || "transparent"
            anchors.verticalCenter: parent.verticalCenter
        }
        
        // Editable Text
        TextInput {
            id: nameInput
            text: parent.visible ? shortcutData.name : ""
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter

            // Constrain text width with elision
            width: isEditing ? 80 : Math.min(root.width - 40, implicitWidth)
            clip: true

            readOnly: !isRenaming
            selectByMouse: isRenaming
            activeFocusOnPress: isRenaming

            // Allow clicking through when not editing
            visible: true

            onEditingFinished: {
                isRenaming = false
                root.requestRename(text)
            }

            onActiveFocusChanged: {
                if (!activeFocus) {
                    isRenaming = false
                }
            }
        }
    }

    // Edit Controls Overlay
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        visible: isEditing
        z: 10

        EditActionButton {
            width: 20; height: 20
            iconName: "chevron_left"
            iconSize: 14
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: root.requestMove(-1)
        }

        EditActionButton {
            width: 20; height: 20
            iconName: "chevron_right"
            iconSize: 14
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: root.requestMove(1)
        }

        EditActionButton {
            width: 20; height: 20
            iconName: "close"
            iconSize: 12
            iconColor: Theme.primaryText
            backgroundColor: Theme.error || "transparent"
            onClicked: root.requestDelete()
        }
    }
    
    // Ripple effect
    Rectangle {
        id: feedback
        anchors.fill: parent
        radius: parent.radius
        color: Theme.primary || "transparent"
        opacity: 0
    }
    
    SequentialAnimation {
        id: triggerAnim
        NumberAnimation { target: feedback; property: "opacity"; from: 0.3; to: 0; duration: 400; easing.type: Easing.OutQuad }
    }

    // Main Mouse Area
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !isRenaming

        onDoubleClicked: {
            if (isEditing) {
                isRenaming = true
                nameInput.forceActiveFocus()
                nameInput.selectAll()
            } else {
                root.requestEdit()
            }
        }

        onClicked: {
            if (isEditing) {
                // In edit mode, clicking selects the chip for keyboard reordering
                root.requestSelect();
            } else {
                // Normal mode: trigger action
                if (!shortcutData) return;

                // Trigger Action
                if (shortcutData.domain === "button") {
                    HomeAssistantService.callService("button", "press", shortcutData.id, {});
                } else if (shortcutData.domain === "switch") {
                    HomeAssistantService.toggleEntity(shortcutData.id, "switch", "unknown"); // Optimistic toggle
                } else {
                    HomeAssistantService.triggerScript(shortcutData.id);
                }

                triggerAnim.start();
                ToastService.showInfo(I18n.tr("Triggered", "Action notification") + " " + shortcutData.name);
            }
        }

        onPressAndHold: root.longPressed()
    }
}