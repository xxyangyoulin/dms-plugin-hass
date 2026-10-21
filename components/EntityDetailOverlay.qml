import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    property bool opened: false
    property Component content
    property alias headerHost: headerContentSlot
    property real outerPadding: 0
    anchors.margins: -outerPadding
    signal requestClose()

    property bool enterPending: false
    readonly property bool animationsEnabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    visible: opened || opacity > 0
    opacity: 0
    layer.enabled: enterPending || enterAnimation.running || exitAnimation.running
    layer.smooth: true

    Connections {
        target: root
        function onVisibleChanged() {
            if (!root.visible)
                root.focus = false;
        }
        function onOpenedChanged() {
            root.enterPending = false;
            enterAnimation.stop();
            exitAnimation.stop();
            if (!root.opened) {
                if (root.animationsEnabled)
                    exitAnimation.start();
                else
                    root.opacity = 0;
                return;
            }
            root.enterPending = root.animationsEnabled;
            root.opacity = root.enterPending ? 0 : 1;
            surface.entryScale = root.enterPending ? 0.92 : 1;
            detailFlick.contentY = 0;
            root.focusContent();
        }
    }

    Connections {
        target: root.Window.window
        enabled: root.enterPending
        function onFrameSwapped() {
            root.enterPending = false;
            enterAnimation.start();
        }
    }
    Accessible.role: Accessible.Dialog
    Accessible.name: I18n.tr("Details")

    function focusContent() {
        closeButton.forceActiveFocus();
    }

    function moveFocus(backwards) {
        const current = root.Window.window.activeFocusItem || closeButton;
        const next = current.nextItemInFocusChain(!backwards);
        for (let item = next; item; item = item.parent) {
            if (item === root) {
                next.forceActiveFocus(backwards ? Qt.BacktabFocusReason : Qt.TabFocusReason);
                return;
            }
        }
        closeButton.forceActiveFocus(Qt.TabFocusReason);
    }

    ParallelAnimation {
        id: enterAnimation
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: Theme.expressiveDurations.expressiveEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
        NumberAnimation {
            target: surface
            property: "entryScale"
            to: 1
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
        }
    }

    NumberAnimation {
        id: exitAnimation
        target: root
        property: "opacity"
        to: 0
        duration: Theme.expressiveDurations.expressiveEffects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
    }

    Keys.enabled: root.visible
    Keys.onEscapePressed: event => {
        root.requestClose();
        event.accepted = true;
    }
    Shortcut {
        sequence: "Tab"
        enabled: root.visible && root.enabled && root.activeFocus
        onActivated: root.moveFocus(false)
    }
    Shortcut {
        sequences: ["Backtab", "Shift+Tab"]
        enabled: root.visible && root.enabled && root.activeFocus
        onActivated: root.moveFocus(true)
    }
    Keys.onPressed: event => event.accepted = true

    Rectangle {
        anchors.fill: parent
        radius: Theme.windowRadius
        color: Theme.scrimColor
        opacity: Theme.scrimAlpha
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: root.requestClose()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        id: surface
        anchors.centerIn: parent
        width: Math.min(parent.width - (root.outerPadding + Theme.spacingM) * 2, 420)
        height: Math.min(parent.height - (root.outerPadding + Theme.spacingM) * 2, header.height + detailLoader.height + Theme.spacingM * 2)
        radius: Theme.cornerRadiusXL
        color: Theme.foregroundColor(Theme.hostSurface)
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        property real entryScale: 1
        scale: Math.min(1, entryScale)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
        }

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(48, headerContentSlot.childrenRect.height)

            Item {
                id: headerContentSlot
                anchors.left: parent.left
                anchors.right: closeButton.left
                anchors.top: parent.top
                height: parent.height
            }

            StyledText {
                visible: headerContentSlot.children.length === 0
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Details")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToolButton {
                id: closeButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                Accessible.name: I18n.tr("Close")
                onClicked: root.requestClose()
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                contentItem: DankIcon {
                    name: "close"
                    size: 20
                    color: Theme.surfaceText
                }
                background: Rectangle {
                    radius: width / 2
                    color: closeButton.hovered || closeButton.activeFocus ? Theme.surfaceContainerHigh : "transparent"
                }
            }
        }

        Flickable {
            id: detailFlick
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingS
            clip: true
            contentHeight: detailLoader.height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar {}

            Loader {
                id: detailLoader
                width: parent.width
                active: root.visible
                sourceComponent: root.content
            }
        }
    }
}
