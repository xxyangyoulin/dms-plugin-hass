import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../services"
import "."

Column {
    id: shortcutsGridRoot

    property bool isEditing: false

    // Top spacer for consistent spacing
    Item { width: 1; height: Theme.spacingS }
    property string selectedShortcutId: ""
    
    // Signals
    signal requestSelect(string id)
    signal requestEdit(string id)
    signal requestDelete(string id)
    
    visible: HomeAssistantService.shortcutsModel.count > 0 || isEditing
    spacing: Theme.spacingS
    
    onIsEditingChanged: {
        if (!isEditing) selectedShortcutId = "";
    }
    
    // Internal shortcut selection state handling
    // We need to support keyboard navigation which was previously in the parent
    
    GridLayout {
        id: shortcutsGrid
        width: parent.width
        columnSpacing: Theme.spacingS
        rowSpacing: Theme.spacingS

        // Fixed columns: 1, 2, or 3 based on available width
        columns: {
            const minWidth = 100 + columnSpacing;
            const availableWidth = width + columnSpacing;
            if (availableWidth >= minWidth * 3) return 3;
            if (availableWidth >= minWidth * 2) return 2;
            return 1;
        }

        focus: true
        Keys.enabled: shortcutsGridRoot.isEditing && shortcutsGridRoot.selectedShortcutId !== ""

        Keys.onUpPressed: {
            if (shortcutsGridRoot.selectedShortcutId === "") return;

            var currentIndex = -1;
            for (var i = 0; i < HomeAssistantService.shortcutsModel.count; i++) {
                if (HomeAssistantService.shortcutsModel.get(i).entityId === shortcutsGridRoot.selectedShortcutId) {
                    currentIndex = i;
                    break;
                }
            }

            if (currentIndex > 0) {
                HomeAssistantService.moveShortcut(currentIndex, currentIndex - 1);
            }
        }

        Keys.onDownPressed: {
            if (shortcutsGridRoot.selectedShortcutId === "") return;

            var currentIndex = -1;
            for (var i = 0; i < HomeAssistantService.shortcutsModel.count; i++) {
                if (HomeAssistantService.shortcutsModel.get(i).entityId === shortcutsGridRoot.selectedShortcutId) {
                    currentIndex = i;
                    break;
                }
            }

            if (currentIndex >= 0 && currentIndex < HomeAssistantService.shortcutsModel.count - 1) {
                HomeAssistantService.moveShortcut(currentIndex, currentIndex + 1);
            }
        }

        Keys.onEscapePressed: {
            shortcutsGridRoot.selectedShortcutId = "";
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
                isSelected: shortcutsGridRoot.selectedShortcutId === entityId

                Layout.fillWidth: true
                Layout.minimumWidth: 100

                onLongPressed: shortcutsGridRoot.isEditing = true

                onRequestSelect: {
                    shortcutsGridRoot.selectedShortcutId = entityId;
                    shortcutsGrid.forceActiveFocus();
                }

                onRequestEdit: {
                    shortcutsGridRoot.selectedShortcutId = entityId;
                    shortcutsGridRoot.isEditing = true;
                }

                onRequestDelete: {
                    // Clear selection first to avoid accessing context after removal
                    shortcutsGridRoot.selectedShortcutId = "";
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
    Item { width: 1; height: Theme.spacingS }
}