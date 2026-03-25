import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../services"
import "."

Column {
    id: shortcutsGridRoot

    property bool isEditing: false
    readonly property int chipHeight: 44
    readonly property int shortcutCount: HomeAssistantService.shortcutsModel.count
    readonly property int rowCount: shortcutCount > 0 ? Math.ceil(shortcutCount / Math.max(1, shortcutsGrid.columns)) : 0
    readonly property int contentHeight: topSpacer.height
        + (rowCount > 0 ? rowCount * chipHeight + Math.max(0, rowCount - 1) * shortcutsGrid.rowSpacing : 0)
        + bottomSpacer.height
        + spacing

    // Keep a small breathing room without wasting vertical space.
    Item {
        id: topSpacer
        width: 1
        height: Theme.spacingXS
    }
    visible: HomeAssistantService.shortcutsModel.count > 0 || isEditing
    spacing: Theme.spacingXS

    GridLayout {
        id: shortcutsGrid
        width: parent.width
        columnSpacing: Theme.spacingS
        rowSpacing: Theme.spacingXS

        // Fixed columns: 1, 2, or 3 based on available width
        columns: {
            const minWidth = 100 + columnSpacing;
            const availableWidth = width + columnSpacing;
            if (availableWidth >= minWidth * 3) return 3;
            if (availableWidth >= minWidth * 2) return 2;
            return 1;
        }

        Repeater {
            model: HomeAssistantService.shortcutsModel

            delegate: ShortcutChip {
                required property int index
                required property string entityId
                required property string name
                required property string domain

                shortcutData: ({
                    "id": entityId,
                    "name": name,
                    "domain": domain
                })

                isEditing: shortcutsGridRoot.isEditing

                Layout.fillWidth: true
                Layout.minimumWidth: 100

                onLongPressed: shortcutsGridRoot.isEditing = true

                onRequestDelete: {
                    HomeAssistantService.removeShortcut(entityId);
                }

                onRequestRename: (newName) => {
                    HomeAssistantService.renameShortcut(entityId, newName);
                }
                
                onRequestMove: (offset) => {
                    var newIndex = index + offset;
                    if (newIndex >= 0 && newIndex < HomeAssistantService.shortcutsModel.count) {
                        HomeAssistantService.moveShortcut(index, newIndex);
                    }
                }
            }
        }
    }

    // Spacer
    Item {
        id: bottomSpacer
        width: 1
        height: 0
    }
}
