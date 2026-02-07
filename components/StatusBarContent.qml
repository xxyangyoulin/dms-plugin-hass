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
    property var globalEntities: []  // All monitored entities
    property var pinnedEntityIds: []  // List of pinned entity IDs
    property var customIcons: ({})
    property real barThickness: 0
    property bool showHomeIcon: true
    property bool showButtonsOnStatusBar: true

    // Optimistic state cache for immediate UI feedback
    property var optimisticStates: ({})
    property string _lastPinnedIdsStr: ""

    // ListModel for efficient incremental updates
    ListModel {
        id: pinnedEntitiesModel
    }

    // Sync model when data changes
    onGlobalEntitiesChanged: syncModel()
    onPinnedEntityIdsChanged: syncModel()

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
            // Full rebuild - clear all optimistic states
            optimisticStates = {};
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
            var statesChanged = false;
            for (let i = 0; i < pinnedIds.length; i++) {
                const id = pinnedIds[i];
                const e = entityMap[id];
                if (!e) continue;

                // Get current model data
                const current = pinnedEntitiesModel.get(i);

                // Check if we have an optimistic state for this entity
                const optimistic = optimisticStates[id];

                // If HA reports a different state than our optimistic state, clear the optimistic state
                if (optimistic && optimistic !== e.state) {
                    delete optimisticStates[id];
                    statesChanged = true;
                }

                // Use actual state from HA (optimistic state was cleared above if different)
                const effectiveState = optimisticStates[id] || e.state;

                // Only update if something actually changed
                if (current.state !== effectiveState) {
                    pinnedEntitiesModel.set(i, {
                        entityId: e.entityId,
                        domain: e.domain,
                        state: effectiveState,
                        friendlyName: e.friendlyName,
                        unitOfMeasurement: e.unitOfMeasurement || "",
                        attributes: e.attributes || {}
                    });
                }
            }

            // Update optimisticStates property if any were cleared
            if (statesChanged) {
                optimisticStates = Object.assign({}, optimisticStates);
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

    function setOptimisticState(entityId, state) {
        var states = Object.assign({}, optimisticStates);
        states[entityId] = state;
        optimisticStates = states;

        // Immediately update the model for this entity
        for (var i = 0; i < pinnedEntitiesModel.count; i++) {
            var e = pinnedEntitiesModel.get(i);
            if (e.entityId === entityId) {
                pinnedEntitiesModel.set(i, { state: state });
                break;
            }
        }
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
                    visible: !root.isSwitchable(model) || !root.showButtonsOnStatusBar
                    text: {
                        var state = model.state;
                        if (state === "unavailable" || state === "unknown") {
                            return "-";
                        }
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
                    visible: !root.isSwitchable(model) || !root.showButtonsOnStatusBar
                    text: {
                        var state = model.state;
                        if (state === "unavailable" || state === "unknown") {
                            return "-";
                        }
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
        var state = modelData.state;

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
        if (nextState !== state) {
            setOptimisticState(id, nextState);
        }
    }
}
