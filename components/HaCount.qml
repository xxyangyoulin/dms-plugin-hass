import QtQuick
import qs.Common
import qs.Widgets

StyledText {
    id: root

    property int entityCount: 0
    property int barThickness: 32
    property var barConfig: null

    text: entityCount.toString()
    font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
    color: Theme.widgetTextColor || Theme.surfaceText
    visible: entityCount > 0
}
