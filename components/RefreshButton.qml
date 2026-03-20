import QtQuick
import qs.Common
import qs.Widgets

PanelActionButton {
    id: root

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

    iconName: "refresh"
    showIcon: false
    busy: spinning

    DankIcon {
        id: refreshIcon
        anchors.centerIn: parent
        name: root.iconName
        size: 18
        color: (root.active || root.busy) ? (Theme.primary || Theme.surfaceText) : Theme.surfaceText
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
}
