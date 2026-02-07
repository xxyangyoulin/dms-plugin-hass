pragma ComponentBehavior: Bound

import QtQuick
import "../services"

/**
 * EntityDataProvider - Provides unified access to entity data
 *
 * This component should be instantiated once and shared between
 * status bar and monitored list to ensure they show the same states.
 */
Item {
    id: root

    // Reference to HomeAssistantService (set by parent)
    property var service: HomeAssistantService

    // Pinned entity IDs (set by parent)
    property var pinnedEntityIds: []

    // Signal when entity data changes
    signal entityDataChanged(string entityId)

    // Get entity data by ID with all states applied (optimistic, pending confirmation, etc.)
    function getEntityData(entityId) {
        if (!service || !service.cachedAllEntities) return null;

        for (let i = 0; i < service.cachedAllEntities.length; i++) {
            if (service.cachedAllEntities[i].entityId === entityId) {
                const base = service.cachedAllEntities[i];
                const effectiveState = service.getEffectiveValue(entityId, "state", base.state);

                return {
                    entityId: base.entityId,
                    state: effectiveState,
                    domain: base.domain,
                    friendlyName: base.friendlyName,
                    unitOfMeasurement: base.unitOfMeasurement || "",
                    attributes: base.attributes || {},
                    lastUpdated: base.lastUpdated
                };
            }
        }
        return null;
    }

    // Get all pinned entities with all states applied
    function getPinnedEntities() {
        if (!service) return [];

        const entities = service.cachedAllEntities || [];
        const pinnedIds = pinnedEntityIds || [];
        const result = [];

        for (let i = 0; i < pinnedIds.length; i++) {
            const id = pinnedIds[i];
            const data = getEntityData(id);
            if (data) {
                result.push(data);
            }
        }
        return result;
    }

    // Get all monitored entities with all states applied
    function getMonitoredEntities() {
        if (!service || !service.cachedAllEntities) return [];

        const result = [];
        const entities = service.cachedAllEntities;

        for (let i = 0; i < entities.length; i++) {
            const base = entities[i];
            const effectiveState = service.getEffectiveValue(base.entityId, "state", base.state);

            result.push({
                entityId: base.entityId,
                state: effectiveState,
                domain: base.domain,
                friendlyName: base.friendlyName,
                unitOfMeasurement: base.unitOfMeasurement || "",
                attributes: base.attributes || {},
                lastUpdated: base.lastUpdated
            });
        }
        return result;
    }

    // Connections to listen for state changes
    Connections {
        target: service
        function onOptimisticStateChanged(entityId, key, value) {
            if (key === "state") {
                entityDataChanged(entityId);
            }
        }
    }

    Connections {
        target: service
        function onPendingConfirmationResolved(entityId) {
            entityDataChanged(entityId);
        }
    }
}
