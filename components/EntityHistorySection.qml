import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Column {
    id: root

    required property var historyData
    required property string unit

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS
    visible: historyData.length > 0

    RowLayout {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            Layout.fillWidth: true
            text: I18n.tr("24h History", "Sensor history label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            text: sparkline.hoveredTime
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    Sparkline {
        id: sparkline
        width: parent.width
        height: 50
        historyData: root.historyData
        unit: root.unit
    }
}
