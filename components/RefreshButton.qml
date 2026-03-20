import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    signal clicked
    property bool spinning: false
    property int spinDuration: 900
    property bool animationActive: false
    property double spinStartedAt: 0

    function startSpin() {
        stopSpinTimer.stop();
        spinStartedAt = Date.now();
        refreshIcon.rotation = 0;
        animationActive = true;
    }

    function stopSpin() {
        stopSpinTimer.stop();
        animationActive = false;
        refreshIcon.rotation = 0;
    }

    function scheduleStop() {
        if (!animationActive) {
            refreshIcon.rotation = 0;
            return;
        }

        const elapsed = Math.max(0, Date.now() - spinStartedAt);
        let remaining = spinDuration - (elapsed % spinDuration);

        if (elapsed >= spinDuration && remaining === spinDuration) {
            remaining = 0;
        }

        if (remaining <= 0) {
            stopSpin();
            return;
        }

        stopSpinTimer.interval = Math.ceil(remaining);
        stopSpinTimer.restart();
    }

    width: 36
    height: 36
    radius: Theme.cornerRadius
    color: Qt.rgba(0, 0, 0, 0)

    DankIcon {
        id: refreshIcon
        anchors.centerIn: parent
        name: "refresh"
        size: 18
        color: Theme.surfaceText
        rotation: 0

        RotationAnimation on rotation {
            id: refreshSpinAnimation
            from: 0
            to: 360
            duration: root.spinDuration
            loops: Animation.Infinite
            running: root.animationActive
            onStopped: {
                refreshIcon.rotation = 0;
            }
        }
    }

    Timer {
        id: stopSpinTimer
        interval: root.spinDuration
        repeat: false
        onTriggered: root.stopSpin()
    }

    onSpinningChanged: {
        if (spinning) {
            if (!animationActive) {
                startSpin();
            } else {
                stopSpinTimer.stop();
            }
        } else {
            scheduleStop();
        }
    }

    Component.onCompleted: {
        if (spinning) {
            startSpin();
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor
        enabled: !root.spinning
        onClicked: root.clicked()
    }
}
