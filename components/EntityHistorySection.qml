import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Column {
    id: root

    required property var historyData
    required property string unit
    property bool loading: false

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS

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

    Item {
        width: parent.width
        height: 112

        Sparkline {
            id: sparkline
            anchors.fill: parent
            visible: !root.loading && root.historyData.length > 0
            historyData: root.historyData
            unit: root.unit
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.loading || root.historyData.length === 0
            text: root.loading ? I18n.tr("Loading history…") : I18n.tr("No history available")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    RowLayout {
        width: parent.width
        opacity: !root.loading && root.historyData.length > 0 ? 1 : 0

        StyledText {
            text: Qt.formatDateTime(new Date(sparkline.startTime), "MM/dd HH:mm")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            Layout.fillWidth: true
        }
        StyledText {
            text: Qt.formatDateTime(new Date(sparkline.endTime), "MM/dd HH:mm")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
}
