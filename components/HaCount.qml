import QtQuick
import qs.Common
import qs.Widgets

StyledText {
    id: root

    property int entityCount: 0
    property int barThickness: 32

    text: entityCount.toString()
    font.pixelSize: Theme.barTextSize(barThickness)
    color: Theme.widgetTextColor || Theme.surfaceText
    visible: entityCount > 0
}
