pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "../services"

QtObject {
    id: root

    /**
     * Get the effective value for an entity attribute, considering optimistic UI updates.
     * @param entityData - The entity data object
     * @param attr - The attribute name to retrieve
     * @param defaultValue - The default value if attribute is not found
     * @returns The effective value (optimistic or real)
     */
    function getEffectiveValue(entityData, attr, defaultValue) {
        if (!entityData) return defaultValue;

        // Special case for "state" - use entity.state directly
        if (attr === "state") {
            return HomeAssistantService.getEffectiveValue(
                entityData.entityId,
                "state",
                entityData.state || defaultValue
            );
        }

        const realValue = (entityData.attributes && entityData.attributes[attr] !== undefined)
            ? entityData.attributes[attr]
            : defaultValue;

        return HomeAssistantService.getEffectiveValue(
            entityData.entityId,
            attr,
            realValue
        );
    }

    /**
     * Get the effective state for an entity, considering optimistic UI updates.
     * @param entityData - The entity data object
     * @returns The effective state
     */
    function getEffectiveState(entityData) {
        if (!entityData) return "";
        return HomeAssistantService.getEffectiveValue(
            entityData.entityId,
            "state",
            entityData.state || ""
        );
    }

    /**
     * Safely retrieve an attribute value from an entity.
     * @param entity - The entity object
     * @param attrName - The attribute name
     * @param defaultValue - The default value if not found
     * @returns The attribute value or default
     */
    function safeAttr(entity, attrName, defaultValue) {
        return (entity && entity.attributes && entity.attributes[attrName] !== undefined)
            ? entity.attributes[attrName]
            : defaultValue;
    }

    /**
     * Check if an entity is in an active state.
     * @param entityData - The entity data object
     * @returns true if the entity is active, false otherwise
     */
    function isActive(entityData) {
        if (!entityData) return false;
        return HassConstants.isActiveState(entityData.domain, getEffectiveState(entityData));
    }

    /**
     * Get the appropriate color for an entity based on its domain and state.
     * @param entityData - The entity data object
     * @param theme - The theme object
     * @returns The color for the entity
     */
    function getStateColor(entityData, theme) {
        if (!entityData) return theme.primary;
        return HassConstants.getStateColor(entityData.domain, getEffectiveState(entityData), theme);
    }

    /**
     * Get the icon for an entity.
     * @param entityData - The entity data object
     * @param customIcons - Optional custom icon overrides
     * @returns The icon name
     */
    function getEntityIcon(entityData, customIcons) {
        if (!entityData) return "sensors";
        const entityId = entityData.entityId || "";
        const domain = entityData.domain || "";
        return (customIcons && customIcons[entityId]) || HassConstants.getIconForDomain(domain);
    }

    /**
     * Format the entity state value with unit of measurement.
     * @param entityData - The entity data object
     * @returns The formatted state value
     */
    function formatStateValue(entityData) {
        if (!entityData) return "?";
        const state = getEffectiveState(entityData);
        const unit = entityData.unitOfMeasurement || "";
        return HassConstants.formatStateValue(state, unit);
    }

    /**
     * Get the icon background color for an entity.
     * @param entityData - The entity data object
     * @param theme - The theme object
     * @returns The background color
     */
    function getIconBackgroundColor(entityData, theme) {
        if (!entityData) return theme.surfaceVariant;
        return HassConstants.getIconBackgroundColor(
            entityData.domain,
            getEffectiveState(entityData),
            theme
        );
    }
}
