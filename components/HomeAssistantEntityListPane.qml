import QtQuick
import qs.Common
import qs.Widgets
import "../services"

Column {
    id: root

    property var entities: []
    property bool haAvailable: false
    property int globalEntityCount: 0
    property string connectionStatus: "offline"
    property string connectionMessage: ""
    property bool contentReady: false
    property real maxContentHeight
    property bool isEditing: false
    property bool keyboardNavigationActive: false
    property string selectedEntityId: ""
    property var pinnedEntityIds: []
    property var expandedEntities: ({})
    property var showEntityDetails: ({})
    property bool showAttributes: true
    property var customIcons: ({})
    property var visibilityRules: ({})
    property var deviceExtraEntities: ({})
    property var allEntities: []
    property var devicesCache: ({})
    property var entityToDeviceCache: ({})
    readonly property var entityById: {
        const map = {};
        for (const entity of root.allEntities || [])
            map[entity.entityId] = entity;
        return map;
    }
    readonly property real preferredHeight: {
        const contentHeight = (root.entities || []).length > 0 ? entityList.contentHeight : 260;
        return Math.min(root.maxContentHeight, Math.max(260, contentHeight));
    }

    signal requestListView(ListView listView)
    signal requestToggleExpand(string entityId)
    signal requestTogglePin(string entityId)
    signal requestToggleDetails(string entityId)
    signal requestRemoveEntity(string entityId)
    signal requestOpenIconPicker(string entityId)
    signal requestSetVisibility(string entityId, var rule)
    signal requestAddExtra(string mainEntityId, string extraEntityId)
    signal requestRemoveExtra(string mainEntityId, string extraEntityId)

    function extraEntityIdsFor(entityId) {
        return root.deviceExtraEntities[entityId] || [];
    }

    function extraEntitiesFor(entityId) {
        const ids = extraEntityIdsFor(entityId);
        return ids.map(id => root.entityById[id]).filter(e => e !== undefined);
    }

    function fallbackDeviceEntityIds(entityId) {
        const objectId = (entityId || "").split(".")[1] || "";
        const parts = objectId.split("_");
        for (let length = parts.length; length >= 4; length--) {
            const prefix = parts.slice(0, length).join("_");
            const matches = (root.allEntities || [])
                .map(e => e.entityId)
                .filter(id => {
                    const candidate = (id || "").split(".")[1] || "";
                    return candidate === prefix || candidate.startsWith(prefix + "_");
                });
            if (matches.length > 1)
                return matches;
        }
        return [];
    }

    function relatedEntitiesFor(entityId) {
        const deviceId = root.entityToDeviceCache[entityId];
        const device = deviceId ? root.devicesCache[deviceId] : null;
        const ids = device ? device.entityIds : (root.isEditing ? fallbackDeviceEntityIds(entityId) : []);
        return (ids || [])
            .filter(id => id !== entityId)
            .map(id => root.entityById[id])
            .filter(e => e !== undefined);
    }

    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : preferredHeight
    spacing: Theme.spacingS

    EmptyState {
        width: parent.width
        height: Math.max(260, root.height)
        visible: (root.entities || []).length === 0
        haAvailable: root.haAvailable
        connectionStatus: root.connectionStatus
        connectionMessage: root.connectionMessage
        entityCount: root.globalEntityCount
    }

    ListView {
        id: entityList
        width: parent.width
        height: root.height
        visible: (root.entities || []).length > 0
        spacing: Theme.spacingS
        clip: true
        cacheBuffer: 180
        boundsBehavior: Flickable.StopAtBounds
        model: {
            const count = root.contentReady ? (root.entities || []).length : 0;
            const hasShortcuts = HomeAssistantService.shortcutsModel.count > 0 || root.isEditing;
            return count + (hasShortcuts ? 1 : 0);
        }
        currentIndex: {
            const selectedIndex = (root.entities || []).findIndex(e => e.entityId === root.selectedEntityId);
            if (!root.keyboardNavigationActive || selectedIndex < 0)
                return -1;
            const hasShortcuts = HomeAssistantService.shortcutsModel.count > 0 || root.isEditing;
            return hasShortcuts ? selectedIndex + 1 : selectedIndex;
        }

        move: Transition {
            NumberAnimation { properties: "y"; duration: Theme.shorterDuration; easing.type: Easing.OutCubic }
        }
        moveDisplaced: Transition {
            NumberAnimation { properties: "y"; duration: Theme.shorterDuration; easing.type: Easing.OutCubic }
        }
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 200 }
        }
        Component.onCompleted: root.requestListView(entityList)
        onVisibleChanged: if (visible) root.requestListView(entityList)

        delegate: Item {
            required property int index

            readonly property bool hasShortcuts: HomeAssistantService.shortcutsModel.count > 0 || root.isEditing
            readonly property bool isShortcutRow: hasShortcuts && index === 0
            readonly property int entityIndex: hasShortcuts ? index - 1 : index
            readonly property var rowEntityData: !isShortcutRow && entityIndex >= 0 && entityIndex < (root.entities || []).length
                ? root.entities[entityIndex]
                : null
            readonly property bool rowExpanded: rowEntityData ? (root.expandedEntities[rowEntityData.entityId] || false) : false

            width: entityList.width
            height: isShortcutRow ? shortcutsRow.contentHeight : entityCardDelegate.height
            z: rowExpanded ? 10 : 0

            ShortcutsGrid {
                id: shortcutsRow
                width: parent.width
                visible: parent.isShortcutRow
                isEditing: root.isEditing
            }

            EntityCard {
                id: entityCardDelegate
                visible: !parent.isShortcutRow && !!parent.rowEntityData
                width: parent.width
                entityData: parent.rowEntityData
                isExpanded: parent.rowExpanded
                isCurrentItem: rowEntityData ? (root.keyboardNavigationActive && root.selectedEntityId === rowEntityData.entityId) : false
                isPinned: rowEntityData ? root.pinnedEntityIds.includes(rowEntityData.entityId) : false
                detailsExpanded: rowEntityData ? (root.showEntityDetails[rowEntityData.entityId] || false) : false
                showAttributes: root.showAttributes
                customIcons: root.customIcons
                visibilityRule: rowEntityData ? (root.visibilityRules[rowEntityData.entityId] || null) : null
                extraEntityIds: rowEntityData ? root.extraEntityIdsFor(rowEntityData.entityId) : []
                extraEntities: rowEntityData ? root.extraEntitiesFor(rowEntityData.entityId) : []
                relatedEntities: rowEntityData ? root.relatedEntitiesFor(rowEntityData.entityId) : []
                isEditing: root.isEditing

                onToggleExpand: if (rowEntityData) root.requestToggleExpand(rowEntityData.entityId)
                onTogglePin: if (rowEntityData) root.requestTogglePin(rowEntityData.entityId)
                onToggleDetails: if (rowEntityData) root.requestToggleDetails(rowEntityData.entityId)
                onRemoveEntity: if (rowEntityData) root.requestRemoveEntity(rowEntityData.entityId)
                onOpenIconPicker: if (rowEntityData) root.requestOpenIconPicker(rowEntityData.entityId)
                onSetVisibility: rule => { if (rowEntityData) root.requestSetVisibility(rowEntityData.entityId, rule) }
                onAddExtraEntity: extraEntityId => { if (rowEntityData) root.requestAddExtra(rowEntityData.entityId, extraEntityId) }
                onRemoveExtraEntity: extraEntityId => { if (rowEntityData) root.requestRemoveExtra(rowEntityData.entityId, extraEntityId) }
            }
        }

        footer: Item {
            width: 1
            height: Theme.spacingS
        }
    }
}
