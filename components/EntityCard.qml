import "." as Components
import "../services"
import "./controls"
import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
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
    readonly property bool hasExpandableContent: _computeHasExpandableContent()
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
        const stateText = Components.HassConstants.formatStateValue(effectiveState, entityData && entityData.unitOfMeasurement ? entityData.unitOfMeasurement : "");
        if (actionError) return stateText + " • " + I18n.tr("Failed", "Entity action failed");
        return stateText;
    }
    property var entityActionState: ({ status: "idle", action: "", message: "", updatedAt: 0 })
    readonly property bool actionPending: entityActionState.status === "pending"
    readonly property bool actionError: entityActionState.status === "error"
    property int pendingDotsPhase: 0
    property bool _hasExpandedOnce: false
    property bool _hasActualContent: false
    property var historyData: []
    property var relatedEntities: []
    property bool isEditing: false
    property bool isRenaming: false
    property string _renameBaseline: ""

    onIsEditingChanged: if (!isEditing) isRenaming = false

    signal toggleExpand()
    signal togglePin()
    signal toggleDetails()
    signal removeEntity()
    signal openIconPicker()

    function _getEffectiveState() {
        return EntityHelper.getEffectiveState(entityData);
    }

    function _getEffectiveAttr(attr, real) {
        return EntityHelper.getEffectiveValue(entityData, attr, real);
    }

    function _updateRelatedEntities() {
        if (!isExpanded) { relatedEntities = []; return; }
        if (!entityData || !HomeAssistantService.entityToDeviceCache) { relatedEntities = []; return; }
        const deviceName = HomeAssistantService.entityToDeviceCache[entityData.entityId];
        if (!deviceName) { relatedEntities = []; return; }
        const deviceEntityIds = HomeAssistantService.devicesCache[deviceName] || [];
        const all = globalAllEntities.value || [];
        const entityMap = {};
        for (const e of all)
            entityMap[e.entityId] = e;
        relatedEntities = deviceEntityIds
            .filter((id) => id !== entityData.entityId)
            .map((id) => entityMap[id])
            .filter((e) => e !== undefined);
    }

    function _hasControls() {
        if (!entityData) return false;
        const attrs = entityData.attributes || {};
        const domain = entityData.domain;
        if (["climate", "cover", "fan", "light", "media_player", "number", "input_number", "select", "input_select", "button"].includes(domain))
            return true;
        return attrs.brightness !== undefined || attrs.color_temp !== undefined || attrs.percentage !== undefined || attrs.current_position !== undefined || attrs.options !== undefined || attrs.effect_list !== undefined;
    }

    function _computeHasExpandableContent() {
        if (!entityData) return false;
        if (_hasExpandedOnce) return _hasActualContent;
        const attrs = entityData.attributes || {};
        const domain = entityData.domain;
        if (hasControls) return true;
        if (domain === "sensor" || domain === "binary_sensor") return true;
        if (showAttributes) {
            const ignoredKeys = ["friendly_name", "icon", "unit_of_measurement", "device_class", "supported_features", "entity_id", "entity", "last_changed", "last_updated"];
            const keys = Object.keys(attrs).filter(function(key) { return !ignoredKeys.includes(key); });
            if (keys.length > 0) return true;
        }
        return false;
    }

    function _updateActualContent() {
        if (!_hasExpandedOnce) return;
        const attrs = entityData ? entityData.attributes : {};
        const hasAttrs = showAttributes && attrs && Object.keys(attrs).filter(function(key) {
            return key !== "friendly_name" && key !== "icon" && key !== "unit_of_measurement" && key !== "device_class";
        }).length > 0;
        _hasActualContent = hasControls || hasAttrs || historyData.length > 0 || (relatedEntities && relatedEntities.length > 0);
    }

    function _resetExpandCache() {
        _hasExpandedOnce = false;
        _hasActualContent = false;
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
        _updateRelatedEntities();
        _refreshActionState();
        if (!isRenaming)
            _renameBaseline = entityData && entityData.friendlyName ? entityData.friendlyName : "";
    }
    Component.onCompleted: {
        _renameBaseline = entityData && entityData.friendlyName ? entityData.friendlyName : "";
        _refreshActionState();
    }
    onIsExpandedChanged: {
        if (!_hasExpandedOnce && isExpanded) _hasExpandedOnce = true;
        _updateRelatedEntities();
        if (isExpanded && entityData) {
            const domain = entityData.domain;
            if (domain === "sensor" || domain === "binary_sensor")
                HomeAssistantService.fetchHistory(entityData.entityId, function(data) { historyData = data; _updateActualContent(); });
        }
        _updateActualContent();
    }
    onHistoryDataChanged: if (_hasExpandedOnce) _updateActualContent()
    onRelatedEntitiesChanged: if (_hasExpandedOnce) _updateActualContent()
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

    PluginGlobalVar {
        id: globalAllEntities
        varName: "allEntities"
        defaultValue: []
    }

    Timer {
        id: pendingDotsTimer
        interval: 300
        repeat: true
        running: entityCard.actionPending
        onTriggered: entityCard.pendingDotsPhase = (entityCard.pendingDotsPhase + 1) % 3
    }

    property int _lastRefreshCounter: 0

    PluginGlobalVar {
        id: globalRefreshCounter
        varName: "haRefreshCounter"
        defaultValue: 0
        onValueChanged: {
            if (value > entityCard._lastRefreshCounter) {
                entityCard._lastRefreshCounter = value;
                entityCard._resetExpandCache();
            }
        }
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
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingL + Theme.spacingS
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL + Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: entityCard.baseHeight
        visible: isExpanded && hasControls
        active: isExpanded && hasControls
        opacity: visible ? 1 : 0
        height: (visible && item) ? item.implicitHeight : 0
        z: 15
        sourceComponent: {
            if (!entityData) return null;
            const domain = entityData.domain;
            if (domain === "light") return lightControlsComp;
            if (domain === "climate") return climateControlsComp;
            if (domain === "fan") return fanControlsComp;
            if (domain === "cover") return coverControlsComp;
            if (domain === "media_player") return mediaPlayerControlsComp;
            return generalControlsComp;
        }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Component { id: lightControlsComp; LightControls { entityData: entityCard.entityData } }
    Component { id: climateControlsComp; ClimateControls { entityData: entityCard.entityData } }
    Component { id: fanControlsComp; FanControls { entityData: entityCard.entityData } }
    Component { id: coverControlsComp; CoverControls { entityData: entityCard.entityData } }
    Component { id: mediaPlayerControlsComp; MediaPlayerControls { entityData: entityCard.entityData } }
    Component { id: generalControlsComp; GeneralControls { entityData: entityCard.entityData } }

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

        EntityHistorySection {
            width: parent.width
            historyData: entityCard.historyData
            unit: entityData && entityData.unitOfMeasurement ? entityData.unitOfMeasurement : ""
        }

        EntityRelatedSection {
            width: parent.width
            relatedEntities: entityCard.relatedEntities
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
        visible: !isEditing && hasExpandableContent

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
        cursorShape: hasExpandableContent ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        z: 1
        enabled: !isRenaming

        onClicked: {
            if (!isEditing && hasExpandableContent)
                entityCard.toggleExpand();
        }

        onDoubleClicked: {
            if (isEditing) {
                entityCard._startRename();
            } else if (hasExpandableContent) {
                entityCard.toggleExpand();
            }
        }
    }

    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: Theme.expressiveDurations["expressiveFastSpatial"]; easing.type: Theme.standardEasing } }
}
