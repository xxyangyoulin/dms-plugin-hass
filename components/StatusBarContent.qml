import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../services"
import "."

Item {
    id: root

    property int orientation: Qt.Horizontal // or Qt.Vertical
    property bool haAvailable: false
    property int entityCount: 0
    property var globalEntities: []  // All monitored entities (already includes optimistic states)
    property var pinnedEntityIds: []  // List of pinned entity IDs
    property var customIcons: ({})
    property real barThickness: 0
    property bool showHomeIcon: true
    property bool showButtonsOnStatusBar: true

    property string _lastPinnedIdsStr: ""

    // ListModel for efficient incremental updates
    ListModel {
        id: pinnedEntitiesModel
    }

    // Sync model when data changes
    onGlobalEntitiesChanged: syncModel()
    onPinnedEntityIdsChanged: syncModel()

    // Listen for entity data changes from HomeAssistantService (unified signal)
    Connections {
        target: HomeAssistantService
        function onEntityDataChanged(entityId) {
            // Get the latest entity data from HomeAssistantService
            const entityData = HomeAssistantService.getEntityData(entityId);
            if (!entityData) return;

            // Update the entity in the ListModel
            for (var i = 0; i < pinnedEntitiesModel.count; i++) {
                var current = pinnedEntitiesModel.get(i);
                if (current.entityId === entityId) {
                    pinnedEntitiesModel.set(i, {
                        entityId: entityData.entityId,
                        domain: entityData.domain,
                        state: entityData.state,
                        friendlyName: entityData.friendlyName,
                        unitOfMeasurement: entityData.unitOfMeasurement || "",
                        attributes: entityData.attributes || {}
                    });
                    break;
                }
            }
        }
    }

    function syncModel() {
        const entities = globalEntities || [];
        const pinnedIds = pinnedEntityIds || [];
        const currentIdsStr = pinnedIds.join(",");

        // Build entity map for quick lookup
        const entityMap = {};
        for (let i = 0; i < entities.length; i++) {
            const e = entities[i];
            entityMap[e.entityId] = e;
        }

        // Check if structure changed
        if (currentIdsStr !== _lastPinnedIdsStr || pinnedEntitiesModel.count !== pinnedIds.length) {
            _lastPinnedIdsStr = currentIdsStr;
            // Full rebuild
            pinnedEntitiesModel.clear();
            for (let i = 0; i < pinnedIds.length; i++) {
                const id = pinnedIds[i];
                const e = entityMap[id];
                if (e) {
                    pinnedEntitiesModel.append({
                        entityId: e.entityId,
                        domain: e.domain,
                        state: e.state,
                        friendlyName: e.friendlyName,
                        unitOfMeasurement: e.unitOfMeasurement || "",
                        attributes: e.attributes || {}
                    });
                }
            }
        } else {
            // Incremental update - only update changed entities
            for (let i = 0; i < pinnedIds.length; i++) {
                const id = pinnedIds[i];
                const e = entityMap[id];
                if (!e) continue;

                // Get current model data
                const current = pinnedEntitiesModel.get(i);

                // Only update if something actually changed
                // Note: e.state already includes optimistic states from HomeAssistantService
                if (current.state !== e.state) {
                    pinnedEntitiesModel.set(i, {
                        entityId: e.entityId,
                        domain: e.domain,
                        state: e.state,
                        friendlyName: e.friendlyName,
                        unitOfMeasurement: e.unitOfMeasurement || "",
                        attributes: e.attributes || {}
                    });
                }
            }
        }
    }

    Component.onCompleted: syncModel()

    implicitWidth: root.orientation === Qt.Vertical ? root.barThickness : entityRow.implicitWidth
    implicitHeight: root.orientation === Qt.Vertical ? entityColumn.implicitHeight : root.barThickness

    // Helper functions
    function getEntityIcon(entityId, domain) {
        return customIcons[entityId] || HassConstants.getIconForDomain(domain);
    }

    function isSwitchable(entity) {
        if (!entity) return false;
        const domain = entity.domain;
        const switchableDomains = ["switch", "light", "input_boolean", "fan", "automation", "script", "group", "climate"];
        return switchableDomains.includes(domain);
    }

    // Horizontal Layout
    Row {
        id: entityRow
        visible: root.orientation === Qt.Horizontal
        anchors.centerIn: parent
        spacing: Theme.spacingS

        HaIcon {
            barThickness: root.barThickness
            haAvailable: root.haAvailable
            entityCount: root.entityCount
            showHomeIcon: root.showHomeIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.haAvailable || pinnedEntitiesModel.count === 0
        }

        Repeater {
            model: pinnedEntitiesModel
            delegate: entityDelegate
        }

        HaCount {
            entityCount: root.entityCount
            anchors.verticalCenter: parent.verticalCenter
            visible: pinnedEntitiesModel.count === 0
        }
    }

    // Vertical Layout
    Column {
        id: entityColumn
        visible: root.orientation === Qt.Vertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        HaIcon {
            barThickness: root.barThickness
            haAvailable: root.haAvailable
            entityCount: root.entityCount
            showHomeIcon: root.showHomeIcon
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pinnedEntitiesModel.count === 0
        }

        Repeater {
            model: pinnedEntitiesModel
            delegate: entityDelegate
        }

        HaCount {
            entityCount: root.entityCount
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pinnedEntitiesModel.count === 0
        }
    }

    // Shared Delegate
    Component {
        id: entityDelegate

        Item {
            implicitWidth: root.orientation === Qt.Vertical ? root.barThickness : entityRowContent.implicitWidth
            implicitHeight: root.orientation === Qt.Vertical ? entityColumnContent.implicitHeight : root.barThickness

            // Row Version (Horizontal orientation)
            Row {
                id: entityRowContent
                visible: root.orientation === Qt.Horizontal
                anchors.fill: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.getEntityIcon(model.entityId, model.domain)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: (model.state === "unavailable" || model.state === "unknown") ? Theme.warning : HassConstants.getStateColor(model.domain || "", model.state || "", Theme)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Loader {
                    id: switchLoader
                    anchors.verticalCenter: parent.verticalCenter
                    active: root.isSwitchable(model) && root.showButtonsOnStatusBar
                    visible: active
                    sourceComponent: switchComponent
                    onLoaded: {
                        item.modelData = model
                        item.root = root
                    }
                }

                StyledText {
                    visible: (!root.isSwitchable(model) || !root.showButtonsOnStatusBar) && model.state !== "unavailable" && model.state !== "unknown"
                    text: {
                        var state = model.state;
                        return HassConstants.formatStateValue(state, model.unitOfMeasurement);
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: (model.state === "unavailable" || model.state === "unknown") ? Theme.warning : (Theme.widgetTextColor || Theme.surfaceText)
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Column Version (Vertical orientation)
            Column {
                id: entityColumnContent
                visible: root.orientation === Qt.Vertical
                anchors.centerIn: parent
                spacing: 2

                DankIcon {
                    name: root.getEntityIcon(model.entityId, model.domain)
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: (model.state === "unavailable" || model.state === "unknown") ? Theme.warning : HassConstants.getStateColor(model.domain || "", model.state || "", Theme)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Loader {
                    id: switchLoaderVertical
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: root.isSwitchable(model) && root.showButtonsOnStatusBar
                    visible: active
                    sourceComponent: switchComponent
                    onLoaded: {
                        item.modelData = model
                        item.root = root
                    }
                }

                StyledText {
                    visible: (!root.isSwitchable(model) || !root.showButtonsOnStatusBar) && model.state !== "unavailable" && model.state !== "unknown"
                    text: {
                        var state = model.state;
                        return HassConstants.formatStateValue(state, model.unitOfMeasurement);
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: (model.state === "unavailable" || model.state === "unknown") ? Theme.warning : (Theme.widgetTextColor || Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // Switch Component
    Component {
        id: switchComponent
        Rectangle {
            width: 24; height: 14; radius: 7
            property var modelData: null
            property var root: null
            property bool isActive: modelData ? HassConstants.isActiveState(modelData.domain, modelData.state) : false
            color: isActive ? Theme.primary : Theme.surfaceContainerHigh

            Rectangle {
                width: 10; height: 10; radius: 5; color: "#FFFFFF"
                x: parent.isActive ? parent.width - width - 2 : 2
                anchors.verticalCenter: parent.verticalCenter
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root && modelData) {
                        root.handleToggle(modelData)
                    }
                }
            }
        }
    }

    function handleToggle(modelData) {
        var domain = modelData.domain;
        var id = modelData.entityId;
        // Use actual state instead of optimistic state for toggle logic
        var state = HomeAssistantService.getActualState(id) || modelData.state;

        // Predict next state for optimistic UI
        var nextState = state;
        if (domain === "script" || domain === "automation") {
            HomeAssistantService.triggerScript(id);
            return;
        } else if (domain === "climate") {
            var hvacModes = modelData.attributes && modelData.attributes.hvac_modes || ["off", "heat"];
            nextState = state === "off"
                ? (hvacModes.includes("heat") ? "heat" : hvacModes.find(m => m !== "off") || "heat")
                : "off";
            HomeAssistantService.setHvacMode(id, nextState);
        } else {
            // For switchable entities, toggle the state
            if (state === "on") nextState = "off";
            else if (state === "off") nextState = "on";
            else nextState = state;
            HomeAssistantService.toggleEntity(id, domain, state);
        }

        // Set optimistic state for immediate UI feedback
        // This now goes directly to HomeAssistantService, which will trigger syncModel()
        if (nextState !== state) {
            HomeAssistantService.setOptimisticState(id, "state", nextState);
        }
    }
}
