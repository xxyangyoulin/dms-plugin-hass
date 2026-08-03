import "." as Components
import "../services"
import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: entityCard

    required property var entityData
    property bool isExpanded: false
    property bool isCurrentItem: false
    property bool isPinned: false
    property bool detailsExpanded: false
    property bool showAttributes: true
    property var customIcons: ({})
    readonly property real baseHeight: 68
    readonly property bool isControllable: Components.HassConstants.isControllableDomain(entityData && entityData.domain ? entityData.domain : "")
    readonly property bool hasControls: _hasControls()
    readonly property bool hasOperations: hasControls || _extraEntitiesWithControls().length > 0
    readonly property bool hasHistoryChart: entityData && entityData.domain === "sensor" && !isNaN(parseFloat(entityData.state))
    readonly property bool canExpand: hasOperations || hasHistoryChart
    readonly property bool canToggleExpand: isEditing || canExpand
    readonly property color hoverTintColor: Theme.primary || Theme.surfaceText
    readonly property string effectiveState: _getEffectiveState()
    readonly property bool availabilityIssue: effectiveState === "unavailable" || effectiveState === "unknown"
    readonly property bool activeState: Components.HassConstants.isActiveState(entityData && entityData.domain ? entityData.domain : "", effectiveState)
    readonly property color stateTone: {
        if (actionError) return Theme.error;
        if (availabilityIssue) return Theme.warning;
        return Components.HassConstants.getStateColor(entityData && entityData.domain ? entityData.domain : "", effectiveState, Theme);
    }
    readonly property color iconBackgroundColor: Components.HassConstants.getIconBackgroundColor(entityData && entityData.domain ? entityData.domain : "", effectiveState, Theme)
    readonly property string entityIconName: _getEntityIcon(entityData && entityData.entityId ? entityData.entityId : "", entityData && entityData.domain ? entityData.domain : "")
    readonly property string stateSummaryText: {
        const translationVersion = HomeAssistantService.translationsVersion;
        const stateText = HomeAssistantService.formatEntityState(entityData && entityData.domain ? entityData.domain : "", effectiveState, entityData && entityData.unitOfMeasurement ? entityData.unitOfMeasurement : "");
        if (actionError) return stateText + " • " + I18n.tr("Failed", "Entity action failed");
        return stateText;
    }
    property var entityActionState: ({ status: "idle", action: "", message: "", updatedAt: 0 })
    readonly property bool actionPending: entityActionState.status === "pending"
    readonly property bool actionError: entityActionState.status === "error"
    property int pendingDotsPhase: 0
    property var historyData: []
    property string historyEntityId: ""
    property string historyRequestEntityId: ""
    property var relatedEntities: []
    property var extraEntityIds: []
    property var extraEntities: []
    property bool isEditing: false
    property bool isRenaming: false
    property bool showExtraEntityPicker: false
    property string _renameBaseline: ""
    property var visibilityRule: null   // { op, value } or null (= always shown on bar)

    onIsEditingChanged: {
        if (!isEditing) {
            isRenaming = false;
            showExtraEntityPicker = false;
        }
    }

    signal toggleExpand()
    signal togglePin()
    signal toggleDetails()
    signal removeEntity()
    signal openIconPicker()
    signal setVisibility(var rule)   // null clears (always visible)
    signal addExtraEntity(string entityId)
    signal removeExtraEntity(string entityId)

    function _getEffectiveState() {
        return EntityHelper.getEffectiveState(entityData);
    }

    function _getEffectiveAttr(attr, real) {
        return EntityHelper.getEffectiveValue(entityData, attr, real);
    }

    function _hasControls() {
        return _hasControlsFor(entityData);
    }

    function _hasControlsFor(data) {
        return Components.EntityControlResolver.getOperationCount(data) > 0;
    }

    function _extraEntitiesWithControls() {
        return (extraEntities || []).filter(e => _hasControlsFor(e));
    }

    function _availableRelatedEntities() {
        return (relatedEntities || []).filter(e => _hasControlsFor(e) && !extraEntityIds.includes(e.entityId));
    }

    function _shortEntityName(entity) {
        if (!entity)
            return "";
        const name = entity.friendlyName || entity.entityId || "";
        const base = entityData && entityData.friendlyName ? entityData.friendlyName.replace(/\s+(空调|灯|开关|风扇|传感器)$/, "").trim() : "";
        if (base && name.startsWith(base))
            return name.slice(base.length).replace(/^[\s*]+/, "").trim() || name;
        return name;
    }

    function _loadHistory() {
        if (!isExpanded || !hasHistoryChart || !entityData || historyRequestEntityId === entityData.entityId)
            return;
        const requestedEntityId = entityData.entityId;
        historyRequestEntityId = requestedEntityId;
        HomeAssistantService.fetchHistory(requestedEntityId, function(data) {
            if (historyRequestEntityId === requestedEntityId)
                historyRequestEntityId = "";
            if (!isExpanded || !entityData || entityData.entityId !== requestedEntityId || !hasHistoryChart)
                return;
            historyEntityId = requestedEntityId;
            historyData = data;
        });
    }

    function _getEntityIcon(entityId, domain) {
        return customIcons[entityId] || Components.HassConstants.getIconForDomain(domain);
    }

    function _refreshActionState() {
        entityActionState = HomeAssistantService.getEntityActionState(entityData && entityData.entityId ? entityData.entityId : "");
    }

    function _startRename() {
        if (!entityData)
            return;
        _renameBaseline = entityData.friendlyName || "";
        isRenaming = true;
        Qt.callLater(function() {
            headerLoader.forceRenameFocus();
        });
    }

    function _commitRename(nextName) {
        const candidate = (nextName || "").trim();
        const baseline = (_renameBaseline || "").trim();
        isRenaming = false;
        if (candidate === baseline)
            return;
        if (entityData && entityData.entityId)
            HomeAssistantService.renameEntity(entityData.entityId, candidate);
    }

    function _cancelRename() {
        isRenaming = false;
    }

    function _triggerQuickAction() {
        const domain = entityData.domain;
        const entityId = entityData.entityId;
        const state = HomeAssistantService.getActualState(entityId) || entityData.state;
        if (domain === "script" || domain === "automation") {
            HomeAssistantService.triggerScript(entityId);
        } else if (domain === "scene") {
            HomeAssistantService.activateScene(entityId);
        } else if (domain === "button") {
            HomeAssistantService.callService("button", "press", entityId, {});
        } else if (domain === "media_player") {
            if (state === "playing")
                HomeAssistantService.callService("media_player", "media_pause", entityId, {});
            else
                HomeAssistantService.callService("media_player", "media_play", entityId, {});
        } else if (domain === "climate") {
            const hvacModes = entityData.attributes && entityData.attributes.hvac_modes || ["off", "heat"];
            const nextState = state === "off" ? (hvacModes.includes("heat") ? "heat" : hvacModes.find((m) => m !== "off") || "heat") : "off";
            HomeAssistantService.setOptimisticState(entityId, "state", nextState);
            HomeAssistantService.setHvacMode(entityId, nextState);
        } else {
            let nextState = state === "on" ? "off" : "on";
            if (domain === "cover") nextState = state === "open" ? "closed" : "open";
            if (domain === "lock") nextState = state === "locked" ? "unlocked" : "locked";
            HomeAssistantService.setOptimisticState(entityId, "state", nextState);
            HomeAssistantService.toggleEntity(entityId, domain, state);
        }
    }

    width: parent ? parent.width : 300
    radius: Theme.cornerRadius * 1.5
    color: isCurrentItem ? (Theme.surfaceContainerHighest || Theme.surfaceContainerHigh) : (Theme.surfaceContainerLow || Theme.surfaceContainer)
    border.width: isCurrentItem ? 2 : 1
    border.color: isCurrentItem
        ? Theme.primary
        : (entityMouse.containsMouse
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.22))

    onEntityDataChanged: {
        _refreshActionState();
        if (!isRenaming)
            _renameBaseline = entityData && entityData.friendlyName ? entityData.friendlyName : "";
        const currentEntityId = entityData && entityData.entityId ? entityData.entityId : "";
        if (historyEntityId !== currentEntityId) {
            historyEntityId = "";
            historyData = [];
            _loadHistory();
        }
    }
    Component.onCompleted: {
        _renameBaseline = entityData && entityData.friendlyName ? entityData.friendlyName : "";
        _refreshActionState();
    }
    onIsExpandedChanged: {
        if (isExpanded && !canToggleExpand) {
            toggleExpand();
            return;
        }
        if (!isExpanded)
            showExtraEntityPicker = false;
        else
            _loadHistory();
    }
    onCanToggleExpandChanged: {
        if (!canToggleExpand && isExpanded)
            toggleExpand();
    }
    onActionPendingChanged: {
        if (actionPending) {
            pendingDotsPhase = 0;
            pendingDotsTimer.start();
        } else {
            pendingDotsTimer.stop();
            pendingDotsPhase = 0;
        }
    }

    Connections {
        target: HomeAssistantService
        function onEntityActionStateChanged(entityId) {
            if (entityData && entityData.entityId === entityId)
                entityCard._refreshActionState();
        }
    }

    height: baseHeight + (isExpanded && hasControls ? Theme.spacingM + controlsLoader.height : 0) + (isExpanded ? Theme.spacingM + expandedContent.height : 0)

    Timer {
        id: pendingDotsTimer
        interval: 300
        repeat: true
        running: entityCard.actionPending
        onTriggered: entityCard.pendingDotsPhase = (entityCard.pendingDotsPhase + 1) % 3
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: entityCard.baseHeight
        radius: parent.radius
        color: entityCard.hoverTintColor
        opacity: entityMouse.containsMouse ? 0.05 : 0
        z: 2
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    EntityCardHeader {
        id: headerLoader
        width: parent.width - Theme.spacingM * 2 - (controlButton.visible ? controlButton.width + Theme.spacingS : 0) - (expandIcon.visible ? expandIcon.width + Theme.spacingS : 0)
        height: entityCard.baseHeight
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.top: parent.top
        radius: parent.radius
        entityData: entityCard.entityData
        customIcons: entityCard.customIcons
        hoverTintColor: entityCard.hoverTintColor
        stateTone: entityCard.stateTone
        iconBackgroundColor: entityCard.iconBackgroundColor
        iconName: entityCard.entityIconName
        effectiveState: entityCard.effectiveState
        stateText: entityCard.stateSummaryText
        errorText: entityCard.entityActionState.message || I18n.tr("The last action did not complete", "Entity action error detail")
        actionPending: entityCard.actionPending
        actionError: entityCard.actionError
        pendingDotsPhase: entityCard.pendingDotsPhase
        isRenaming: entityCard.isRenaming
        isEditing: entityCard.isEditing
        showLightAnimation: !!entityCard.entityData && entityCard.entityData.domain === "light" && entityCard.effectiveState === "on"
        showBinaryPulse: !!entityCard.entityData && entityCard.entityData.domain === "binary_sensor" && entityCard.effectiveState === "on"
        showFanAnimation: !!entityCard.entityData && entityCard.entityData.domain === "fan" && entityCard.effectiveState === "on"
        fanAnimationDuration: Math.max(500, 3000 - (entityCard._getEffectiveAttr("percentage", 50) * 25))
        hovered: entityMouse.containsMouse
        z: 4
        anchors.right: controlButton.visible ? controlButton.left : expandIcon.left
        anchors.rightMargin: Theme.spacingS

        onIconClicked: {
            if (entityData && entityData.entityId)
                entityCard.openIconPicker();
        }
        onRenameCommitted: entityCard._commitRename(text)
        onRenameCancelled: entityCard._cancelRename()
    }

    Loader {
        id: controlsLoader
        asynchronous: true
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingL + Theme.spacingS
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL + Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: entityCard.baseHeight
        visible: isExpanded && hasControls
        active: isExpanded && hasControls
        opacity: visible ? 1 : 0
        height: (visible && item) ? Math.max(item.implicitHeight, item.height) : 0
        z: 15
        sourceComponent: entityControlsComp
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Component { id: entityControlsComp; EntityControlsView { entityData: entityCard.entityData; compactLabels: true } }

    EntityExpandableContent {
        id: expandedContent
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingL + Theme.spacingS
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL + Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: controlsLoader.visible ? (controlsLoader.y + controlsLoader.height + Theme.spacingM) : entityCard.baseHeight
        expanded: entityCard.isExpanded
        z: 15

        Loader {
            width: parent.width
            active: entityCard.isExpanded && entityCard.historyData.length > 0
            asynchronous: true
            sourceComponent: historySectionComponent
        }

        Component {
            id: historySectionComponent

            EntityHistorySection {
                historyData: entityCard.historyData
                unit: entityData && entityData.unitOfMeasurement ? entityData.unitOfMeasurement : ""
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: entityCard._extraEntitiesWithControls().length > 0

            StyledRect {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
            }

            Repeater {
                model: entityCard.isExpanded ? entityCard._extraEntitiesWithControls() : []

                delegate: Column {
                    required property var modelData

                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: entityCard._shortEntityName(modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            elide: Text.ElideRight
                            width: parent.width - (removeExtraButton.visible ? removeExtraButton.width + Theme.spacingS : 0)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EditActionButton {
                            id: removeExtraButton
                            width: 28
                            height: 28
                            visible: entityCard.isEditing
                            iconName: "close"
                            iconSize: 13
                            iconColor: Theme.primaryText
                            backgroundColor: Theme.error || "transparent"
                            onClicked: entityCard.removeExtraEntity(modelData.entityId)
                        }
                    }

                    EntityControlsView {
                        width: parent.width
                        height: implicitHeight
                        entityData: modelData
                        compactLabels: true
                    }
                }
            }
        }

        StyledRect {
            width: parent.width
            height: 36
            radius: Theme.cornerRadius
            visible: entityCard.isEditing
            color: Theme.surfaceContainerHigh

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: entityCard.showExtraEntityPicker ? "expand_less" : "add_circle"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: entityCard.showExtraEntityPicker
                        ? I18n.tr("Hide addable entities", "Button label")
                        : I18n.tr("Add device entity", "Button label")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: entityCard.showExtraEntityPicker = !entityCard.showExtraEntityPicker
            }
        }

        EntityRelatedSection {
            width: parent.width
            relatedEntities: entityCard._availableRelatedEntities()
            isEditing: entityCard.isEditing
            pickerVisible: entityCard.showExtraEntityPicker
            selectedEntityIds: entityCard.extraEntityIds
            baseName: entityCard.entityData && entityCard.entityData.friendlyName ? entityCard.entityData.friendlyName : ""
            onAddEntity: entityId => entityCard.addExtraEntity(entityId)
            onRemoveEntity: entityId => entityCard.removeExtraEntity(entityId)
        }

        EntityDetailsSection {
            width: parent.width
            entityData: entityCard.entityData
            detailsExpanded: entityCard.detailsExpanded
            showAttributes: entityCard.showAttributes
            onToggleDetails: entityCard.toggleDetails()
        }
    }

    EntityQuickActionButton {
        id: controlButton
        anchors.right: expandIcon.left
        anchors.rightMargin: Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: (entityCard.baseHeight - height) / 2
        z: 10
        visibleWhenActive: isControllable && !isEditing
        actionPending: entityCard.actionPending
        actionError: entityCard.actionError
        activeState: entityCard.activeState
        activeColor: Theme.primary
        inactiveColor: Theme.surfaceVariant
        activeIconColor: Theme.primaryText
        inactiveIconColor: Theme.surfaceText
        iconName: {
            const domain = entityData && entityData.domain ? entityData.domain : "";
            const state = entityCard._getEffectiveState();
            if (entityCard.actionError) return "error";
            if (domain === "script" || domain === "automation") return "play_arrow";
            if (domain === "scene") return "palette";
            if (domain === "cover") return state === "open" ? "expand_more" : "expand_less";
            if (domain === "lock") return state === "locked" ? "lock" : "lock_open";
            if (domain === "climate") return state !== "off" ? "local_fire_department" : "power_settings_new";
            return "power_settings_new";
        }
        onClicked: entityCard._triggerQuickAction()
    }
    Rectangle {
        id: expandIcon
        width: 40
        height: 40
        radius: 20
        color: Qt.rgba(0, 0, 0, 0)
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: (entityCard.baseHeight - height) / 2
        z: 10
        visible: !isEditing && canExpand

        DankIcon {
            name: isExpanded ? "expand_less" : "expand_more"
            size: 20
            color: Theme.surfaceText
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            propagateComposedEvents: false
            onClicked: entityCard.toggleExpand()
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: (entityCard.baseHeight - height) / 2
        spacing: 2
        visible: isEditing
        z: 20

        EditActionButton {
            width: 32
            height: 32
            iconName: "push_pin"
            iconSize: 16
            iconColor: isPinned ? (Theme.primary || "transparent") : Theme.surfaceText
            backgroundColor: isPinned ? (Theme.primary || "transparent") : (Theme.surfaceContainerHigh || "transparent")
            backgroundOpacity: isPinned ? 0.3 : 0.7
            iconRotation: isPinned ? 0 : 45
            onClicked: entityCard.togglePin()
        }

        EditActionButton {
            width: 32
            height: 32
            readonly property bool showWhenActive: !!(entityCard.visibilityRule && entityCard.visibilityRule.op === "active")
            // Toggle: always shown  <->  only shown on the bar when the entity is "active"
            // (state is not off/idle/none/closed/empty). Full op set lives in EntityHelper.entityVisible.
            iconName: showWhenActive ? "filter_alt" : "visibility"
            iconSize: 16
            iconColor: showWhenActive ? (Theme.primary || "transparent") : Theme.surfaceText
            backgroundColor: showWhenActive ? (Theme.primary || "transparent") : (Theme.surfaceContainerHigh || "transparent")
            backgroundOpacity: showWhenActive ? 0.3 : 0.7
            onClicked: entityCard.setVisibility(showWhenActive ? null : { "op": "active" })
        }

        EditActionButton {
            width: 32
            height: 32
            iconName: "vertical_align_top"
            iconSize: 16
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: HomeAssistantService.moveEntityToTop(entityData.entityId)
        }

        EditActionButton {
            width: 32
            height: 32
            iconName: "arrow_upward"
            iconSize: 16
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: HomeAssistantService.moveEntity(entityData.entityId, "up")
        }

        EditActionButton {
            width: 32
            height: 32
            iconName: "arrow_downward"
            iconSize: 16
            iconColor: Theme.surfaceText
            backgroundColor: Theme.surfaceContainerHigh || "transparent"
            onClicked: HomeAssistantService.moveEntity(entityData.entityId, "down")
        }

        EditActionButton {
            width: 32
            height: 32
            iconName: "close"
            iconSize: 14
            iconColor: Theme.primaryText
            backgroundColor: Theme.error || "transparent"
            onClicked: entityCard.removeEntity()
        }
    }

    MouseArea {
        id: entityMouse
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: entityCard.baseHeight
        hoverEnabled: true
        cursorShape: canToggleExpand ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        z: 1
        enabled: !isRenaming

        onClicked: {
            if (canToggleExpand)
                entityCard.toggleExpand();
        }

        onDoubleClicked: {
            if (isEditing) {
                entityCard._startRename();
            } else if (canExpand) {
                entityCard.toggleExpand();
            }
        }
    }

    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: Theme.expressiveDurations["expressiveFastSpatial"]; easing.type: Theme.standardEasing } }
}
