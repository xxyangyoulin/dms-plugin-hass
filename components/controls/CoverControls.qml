import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import "../"
import "../../services"

Column {
    id: root

    required property var entityData
    property var sections: []

    function refreshSections() {
        const latestEntityData = entityData && entityData.entityId
            ? (HomeAssistantService.getEntityData(entityData.entityId) || entityData)
            : entityData;
        sections = EntityControlResolver.getCoverSections(latestEntityData);
    }

    width: parent.width
    spacing: Theme.spacingS

    onEntityDataChanged: refreshSections()
    Component.onCompleted: refreshSections()

    Connections {
        target: HomeAssistantService

        function onEntityDataChanged(entityId) {
            if (root.entityData && root.entityData.entityId === entityId)
                root.refreshSections();
        }
    }

    Repeater {
        model: root.sections

        delegate: Loader {
            required property var modelData

            width: root.width
            property var section: modelData
            onLoaded: {
                if (item)
                    item.section = section;
            }
            sourceComponent: section.type === "position" ? positionSection : null
        }
    }

    Component {
        id: positionSection

        Column {
            property var section

            width: root.width
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Position", "Control label")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            GenericSlider {
                width: parent.width
                value: parent.section.value
                maxValue: parent.section.maxValue
                icon: parent.section.icon
                displayValue: parent.section.displayValue
                onDragFinished: (v) => {
                    HomeAssistantService.setOptimisticState(root.entityData.entityId, "current_position", v);
                    HomeAssistantService.setCoverPosition(root.entityData.entityId, v);
                }
            }
        }
    }
}
