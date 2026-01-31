import QtQuick
import qs.Common

Canvas {
    id: canvas
    property var historyData: []
    property string unit: ""
    property color lineColor: Theme.primary
    property real lineWidth: 2
    property bool fillEnabled: true
    property real revealProgress: 0

    NumberAnimation on revealProgress {
        id: revealAnim
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.OutQuart
    }

    onHistoryDataChanged: {
        revealProgress = 0;
        revealAnim.restart();
    }

    onRevealProgressChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: canvas.requestPaint()
        onExited: canvas.requestPaint()
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        
        if (!historyData || historyData.length < 2) return;

        var min = Infinity;
        var max = -Infinity;
        var minIdx = 0;
        var maxIdx = 0;

        for (var i = 0; i < historyData.length; i++) {
            var val = historyData[i].value;
            if (val < min) { min = val; minIdx = i; }
            if (val > max) { max = val; maxIdx = i; }
        }

        var range = max - min;
        if (range === 0) range = 1;

        var padding = 15; // Increased padding for labels
        var drawWidth = width;
        var drawHeight = height - padding * 2;

        var points = [];
        for (var i = 0; i < historyData.length; i++) {
            var x = (i / (historyData.length - 1)) * drawWidth;
            var y = height - padding - ((historyData[i].value - min) / range) * drawHeight;
            points.push({x: x, y: y, value: historyData[i].value});
        }

        // Apply reveal progress to visible points
        var visibleCount = Math.ceil(points.length * revealProgress);
        if (visibleCount < 2) return;
        var visiblePoints = points.slice(0, visibleCount);

        // Draw Line
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";

        ctx.beginPath();
        ctx.moveTo(visiblePoints[0].x, visiblePoints[0].y);
        for (var i = 0; i < visiblePoints.length - 1; i++) {
            var p0 = visiblePoints[i];
            var p1 = visiblePoints[i + 1];
            var cx = (p0.x + p1.x) / 2;
            ctx.bezierCurveTo(cx, p0.y, cx, p1.y, p1.x, p1.y);
        }
        ctx.stroke();

        // Draw Fill
        if (fillEnabled) {
            ctx.beginPath();
            ctx.moveTo(visiblePoints[0].x, visiblePoints[0].y);
            for (var i = 0; i < visiblePoints.length - 1; i++) {
                var p0 = visiblePoints[i];
                var p1 = visiblePoints[i + 1];
                var cx = (p0.x + p1.x) / 2;
                ctx.bezierCurveTo(cx, p0.y, cx, p1.y, p1.x, p1.y);
            }
            ctx.lineTo(visiblePoints[visiblePoints.length - 1].x, height);
            ctx.lineTo(visiblePoints[0].x, height);
            ctx.closePath();
            
            var gradient = ctx.createLinearGradient(0, 0, 0, height);
            gradient.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.3 * revealProgress));
            gradient.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0));
            ctx.fillStyle = gradient;
            ctx.fill();
        }

        // Draw labels and interactive tooltip
        ctx.font = "bold 10px sans-serif";

        function drawPill(x, y, text, isMain) {
            var textMetrics = ctx.measureText(text);
            var textWidth = textMetrics.width;
            var textHeight = 10;
            var px = 6, py = 3;
            var pw = textWidth + px * 2, ph = textHeight + py * 2;
            
            var pillX = Math.max(2, Math.min(width - pw - 2, x - pw / 2));
            var pillY = y - 10 - ph;
            if (pillY < 2) pillY = y + 10;

            // Dot
            ctx.beginPath();
            ctx.arc(x, y, isMain ? 4 : 3, 0, 2 * Math.PI);
            ctx.fillStyle = "#FFFFFF";
            ctx.fill();
            ctx.strokeStyle = lineColor;
            ctx.lineWidth = 2;
            ctx.stroke();

            if (revealProgress < 1 && !isMain) return; // Only show main tooltip during reveal

            // Pill Shadow
            ctx.shadowBlur = 4;
            ctx.shadowColor = "rgba(0,0,0,0.2)";
            
            // Pill (Manual Rounded Rect for compatibility)
            ctx.beginPath();
            var r = ph / 2;
            ctx.moveTo(pillX + r, pillY);
            ctx.lineTo(pillX + pw - r, pillY);
            ctx.arcTo(pillX + pw, pillY, pillX + pw, pillY + ph, r);
            ctx.lineTo(pillX + pw, pillY + ph - r);
            ctx.arcTo(pillX + pw, pillY + ph, pillX + pw - r, pillY + ph, r);
            ctx.lineTo(pillX + r, pillY + ph);
            ctx.arcTo(pillX, pillY + ph, pillX, pillY + ph - r, r);
            ctx.lineTo(pillX, pillY + r);
            ctx.arcTo(pillX, pillY, pillX + r, pillY, r);
            ctx.closePath();
            
            ctx.fillStyle = isMain ? lineColor : Theme.surfaceContainerHighest;
            ctx.fill();
            
            ctx.shadowBlur = 0;

            // Text
            ctx.fillStyle = isMain ? "#FFFFFF" : Theme.surfaceText;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.fillText(text, pillX + pw / 2, pillY + ph / 2);
        }

        // Always show min/max as background reference when reveal is finished
        if (revealProgress === 1) {
            if (max === min) {
                drawPill(points[0].x, points[0].y, min + (unit ? " " + unit : ""), false);
            } else {
                drawPill(points[minIdx].x, points[minIdx].y, min + (unit ? " " + unit : ""), false);
                drawPill(points[maxIdx].x, points[maxIdx].y, max + (unit ? " " + unit : ""), false);
            }
        }

        // Draw interactive tooltip on top
        if (revealProgress === 1 && mouseArea.containsMouse) {
            var mouseX = mouseArea.mouseX;
            var idx = Math.round((mouseX / drawWidth) * (points.length - 1));
            idx = Math.max(0, Math.min(points.length - 1, idx));
            var p = points[idx];
            drawPill(p.x, p.y, p.value + (unit ? " " + unit : ""), true);
        }
    }
}
