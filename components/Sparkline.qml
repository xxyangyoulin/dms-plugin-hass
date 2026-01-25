import QtQuick
import qs.Common

Canvas {
    id: canvas
    property var historyData: []
    property color lineColor: Theme.primary
    property real lineWidth: 2
    property bool fillEnabled: true

    onHistoryDataChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        
        if (!historyData || historyData.length < 2) return;

        var min = Math.min(...historyData.map(d => d.value));
        var max = Math.max(...historyData.map(d => d.value));
        var range = max - min;
        if (range === 0) range = 1;

        var padding = 5;
        var drawWidth = width;
        var drawHeight = height - padding * 2;

        ctx.strokeStyle = lineColor;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";

        ctx.beginPath();
        
        for (var i = 0; i < historyData.length; i++) {
            var x = (i / (historyData.length - 1)) * drawWidth;
            var y = height - padding - ((historyData[i].value - min) / range) * drawHeight;
            
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();

        if (fillEnabled) {
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            
            var gradient = ctx.createLinearGradient(0, 0, 0, height);
            gradient.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.2));
            gradient.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0));
            ctx.fillStyle = gradient;
            ctx.fill();
        }
    }
}
