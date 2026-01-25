import QtQuick
import qs.Common
import qs.Widgets

StyledText {
    id: root

    property int entityCount: 0

    text: entityCount.toString()
    font.pixelSize: Theme.fontSizeMedium
    color: Theme.widgetTextColor || Theme.surfaceText
    visible: entityCount > 0
}
