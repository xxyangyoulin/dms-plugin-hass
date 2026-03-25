import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    required property var historyData
    required property string unit

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS
    visible: historyData.length > 0

    StyledText {
        text: I18n.tr("24h History", "Sensor history label")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Sparkline {
        width: parent.width
        height: 50
        historyData: root.historyData
        unit: root.unit
    }
}
