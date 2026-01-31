import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import "../"
import "../../services"

Column {
    // Tilt position could be added here later

    id: root

    required property var entityData

    function getVal(attr, def) {
        if (!entityData)
            return def;

        const real = (entityData.attributes && entityData.attributes[attr] !== undefined) ? entityData.attributes[attr] : def;
        return HomeAssistantService.getEffectiveValue(entityData.entityId, attr, real);
    }

    width: parent.width
    spacing: Theme.spacingS

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.getVal("current_position", undefined) !== undefined

        StyledText {
            text: I18n.tr("Position", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        GenericSlider {
            width: parent.width
            value: root.getVal("current_position", 0)
            maxValue: 100
            icon: "roller_shades"
            onChanged: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "current_position", v);
                HomeAssistantService.setCoverPosition(entityData.entityId, v);
            }
            displayValue: value + "%"
        }

    }

}
