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
    property bool isRenaming: false
    readonly property color hoverTintColor: Theme.primary || Theme.surfaceText

    signal requestDelete()
    signal requestRename(string newName)
    signal longPressed()
    signal requestMove(int offset)

    // Safety check
    visible: shortcutData !== undefined && shortcutData !== null

    // Use implicit size to suggest size to layout
    implicitWidth: isEditing ? Math.max(144, row.implicitWidth + Theme.spacingM * 2) : Math.max(104, row.implicitWidth + Theme.spacingM * 2)
    implicitHeight: 40
    height: 40
    radius: 20

    color: Theme.surfaceContainerLow || Theme.surfaceContainer
    border.width: 1
    border.color: mouseArea.containsMouse
        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
        : (isEditing ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18))

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
        z: 2
        
        DankIcon {
            name: parent.visible ? HassConstants.getIconForDomain(shortcutData.domain) : ""
            size: 15
            color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: !root.isRenaming
            text: parent.visible ? shortcutData.name : ""
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            width: isEditing ? 80 : Math.min(root.width - 40, implicitWidth)
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        TextInput {
            id: nameInput
            visible: root.isRenaming
            text: parent.visible ? shortcutData.name : ""
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            width: 80
            clip: true

            enabled: root.isRenaming
            readOnly: !root.isRenaming
            selectByMouse: root.isRenaming
            activeFocusOnPress: root.isRenaming

            onEditingFinished: {
                root.isRenaming = false
                root.requestRename(text)
            }

            onActiveFocusChanged: {
                if (!activeFocus && root.isRenaming) {
                    root.isRenaming = false
                    root.requestRename(text)
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.hoverTintColor
        opacity: mouseArea.containsMouse ? 0.08 : 0
        z: 1
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    // Edit Controls Overlay
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        visible: isEditing
        z: 10

        EditActionButton {
            width: 18; height: 18
            iconName: "chevron_left"
            iconSize: 12
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: root.requestMove(-1)
        }

        EditActionButton {
            width: 18; height: 18
            iconName: "chevron_right"
            iconSize: 12
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: root.requestMove(1)
        }

        EditActionButton {
            width: 18; height: 18
            iconName: "close"
            iconSize: 11
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
            }
        }

        onClicked: {
            if (!isEditing) {
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
