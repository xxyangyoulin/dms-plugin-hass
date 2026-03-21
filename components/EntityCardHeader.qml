import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    required property var entityData
    required property var customIcons
    required property color hoverTintColor
    required property color stateTone
    required property color iconBackgroundColor
    required property string iconName
    required property string effectiveState
    required property string stateText
    required property string errorText
    required property bool actionPending
    required property bool actionError
    required property int pendingDotsPhase
    required property bool isRenaming
    required property bool isEditing
    required property bool showLightAnimation
    required property bool showBinaryPulse
    required property bool showFanAnimation
    required property real fanAnimationDuration
    property bool hovered: false

    signal iconClicked()
    signal renameCommitted(string text)
    signal renameCancelled()

    function forceRenameFocus() {
        nameInput.forceActiveFocus();
        nameInput.selectAll();
    }

    radius: 0
    color: "transparent"
    z: 4

    Rectangle {
        id: iconContainer
        width: 42
        height: 42
        radius: 21
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.top: parent.top
        anchors.topMargin: (parent.height - height) / 2
        z: 3
        color: Theme.surfaceContainerHighest || Theme.surfaceContainerHigh
        border.width: 1
        border.color: Qt.rgba(root.stateTone.r, root.stateTone.g, root.stateTone.b, 0.24)

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 4
            height: parent.height - 4
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
            visible: root.showLightAnimation
            opacity: 0
            scale: 1

            SequentialAnimation on opacity {
                running: root.showLightAnimation
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 0.5; duration: 1500 }
                NumberAnimation { from: 0.5; to: 0; duration: 1500 }
            }

            SequentialAnimation on scale {
                running: root.showLightAnimation
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 1.4; duration: 3000; easing.type: Easing.OutCubic }
                PropertyAction { value: 1 }
            }
        }

        DankIcon {
            id: entityIcon
            name: root.iconName
            size: 22
            color: root.stateTone
            anchors.centerIn: parent

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: root.fanAnimationDuration
                loops: Animation.Infinite
                running: root.showFanAnimation
            }

            SequentialAnimation on opacity {
                running: root.showBinaryPulse
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.6; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.6; to: 1; duration: 800; easing.type: Easing.InOutSine }
            }

            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.iconClicked()
        }
    }

    Column {
        id: textColumn
        anchors.left: iconContainer.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        StyledText {
            visible: !root.isRenaming
            text: root.entityData && root.entityData.friendlyName ? root.entityData.friendlyName : ""
            font.pixelSize: Theme.fontSizeMedium + 1
            font.weight: Font.Medium
            color: Theme.surfaceText
            width: parent.width
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        TextInput {
            id: nameInput
            visible: root.isRenaming
            text: root.entityData && root.entityData.friendlyName ? root.entityData.friendlyName : ""
            font.pixelSize: Theme.fontSizeMedium + 1
            font.weight: Font.Medium
            color: Theme.surfaceText
            width: parent.width
            clip: true
            enabled: root.isRenaming
            readOnly: !root.isRenaming
            selectByMouse: root.isRenaming
            activeFocusOnPress: root.isRenaming

            Keys.onEscapePressed: {
                text = root.entityData && root.entityData.friendlyName ? root.entityData.friendlyName : "";
                root.renameCancelled();
            }

            onEditingFinished: root.renameCommitted(text)

            onActiveFocusChanged: {
                if (!activeFocus && root.isRenaming)
                    root.renameCommitted(text);
            }
        }

        Flow {
            width: parent.width
            spacing: 4

            Rectangle {
                radius: 9
                height: 20
                color: Qt.rgba(root.stateTone.r, root.stateTone.g, root.stateTone.b, root.actionError ? 0.14 : 0.10)
                border.width: 1
                border.color: Qt.rgba(root.stateTone.r, root.stateTone.g, root.stateTone.b, 0.18)
                width: Math.min(parent.width, pillRow.implicitWidth + Theme.spacingS * 2)

                Row {
                    id: pillRow
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    StyledText {
                        text: root.stateText
                        font.pixelSize: Theme.fontSizeSmall - 2
                        font.weight: Font.DemiBold
                        color: root.stateTone
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: Math.min(textColumn.width - Theme.spacingM * 2, implicitWidth)
                    }

                    Row {
                        visible: root.actionPending
                        spacing: 1

                        Repeater {
                            model: 3

                            StyledText {
                                text: "•"
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Font.Bold
                                color: root.stateTone
                                opacity: index <= root.pendingDotsPhase ? 1 : 0.3
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: root.actionError
            text: root.errorText
            font.pixelSize: Theme.fontSizeSmall - 2
            color: Theme.error
            width: parent.width
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }
}
