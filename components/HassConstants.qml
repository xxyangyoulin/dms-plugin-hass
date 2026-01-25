pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: constants

    // Domain icon mappings - single source of truth
    readonly property var domainIcons: ({
        "light": "lightbulb",
        "switch": "toggle_on",
        "sensor": "sensors",
        "binary_sensor": "motion_sensor_active",
        "climate": "thermostat",
        "cover": "roller_shades",
        "fan": "mode_fan",
        "lock": "lock",
        "media_player": "play_circle",
        "camera": "videocam",
        "weather": "wb_sunny",
        "person": "person",
        "device_tracker": "my_location",
        "automation": "smart_button",
        "script": "code",
        "scene": "palette",
        "input_boolean": "toggle_on",
        "input_number": "pin",
        "input_select": "list",
        "input_text": "text_fields",
        "button": "radio_button_checked",
        "vacuum": "cleaning_services",
        "humidifier": "water_drop",
        "water_heater": "water",
        "remote": "settings_remote",
        "siren": "notifications_active",
        "valve": "valve",
        "number": "dialpad",
        "select": "arrow_drop_down_circle",
        "text": "edit"
    })

    // Controllable domains
    readonly property var controllableDomains: [
        "light", "switch", "fan", "cover", "climate", "lock",
        "input_boolean", "script", "automation", "scene", "media_player",
        "button", "vacuum", "humidifier", "water_heater", "remote",
        "siren", "valve", "number", "select", "text", "input_number",
        "input_select", "input_text"
    ]

    // Common icon list
    readonly property var commonIcons: [
        "lightbulb", "toggle_on", "sensors", "thermostat", "home",
        "power_settings_new", "bolt", "water_drop", "local_fire_department", "ac_unit",
        "wb_sunny", "nights_stay", "cloud", "air", "eco",
        "lock", "lock_open", "door_front", "window", "garage",
        "videocam", "motion_sensor_active", "security", "notifications", "alarm",
        "tv", "speaker", "music_note", "play_circle", "cast",
        "router", "wifi", "bluetooth", "smartphone", "computer",
        "battery_full", "battery_charging_full", "electrical_services", "outlet", "power",
        "cleaning_services", "local_laundry_service", "kitchen", "microwave", "blender",
        "mode_fan", "roller_shades", "curtains", "blinds", "vertical_shades",
        "humidity_mid", "water_heater", "heat_pump", "hvac", "air_purifier",
        "person", "group", "pets", "child_care", "elderly",
        "car_rental", "directions_car", "two_wheeler", "pedal_bike", "airport_shuttle",
        "timer", "schedule", "calendar_today", "event", "alarm_on",
        "light_mode", "dark_mode", "brightness_high", "brightness_low", "contrast",
        "speed", "trending_up", "trending_down", "show_chart", "bar_chart",
        "info", "warning", "error", "check_circle", "cancel",
        "settings", "tune", "build", "construction", "handyman",
        "favorite", "star", "bookmark", "flag", "label",
        "location_on", "my_location", "explore", "map", "navigation",
        "volume_up", "volume_off", "mic", "headphones", "radio",
        "image", "photo_camera", "movie", "smart_display", "monitor",
        "description", "article", "feed", "rss_feed", "newspaper",
        "smart_button", "radio_button_checked", "touch_app", "ads_click", "switch_access_shortcut",
        "format_list_numbered", "list", "view_list", "grid_view", "dashboard"
    ]

    // Timings
    readonly property int optimisticTimeout: 3000
    readonly property int refreshDelay: 500
    readonly property int historyHours: 24

    // Helper functions
    function getIconForDomain(domain) {
        return domainIcons[domain] || "sensors";
    }

    function isControllableDomain(domain) {
        return controllableDomains.indexOf(domain) >= 0;
    }

    function getStateColor(domain, state, theme) {
        if (domain === "light" || domain === "switch") {
            return state === "on" ? theme.primary : theme.surfaceVariantText;
        } else if (domain === "binary_sensor") {
            return state === "on" ? theme.warning : theme.surfaceVariantText;
        } else if (domain === "climate") {
            return (state === "heat" || state === "cool") ? theme.primary : theme.surfaceVariantText;
        }
        return theme.primary;
    }

    function getIconBackgroundColor(domain, state, theme) {
        if (domain === "light" || domain === "switch") {
            return state === "on"
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.15)
                : theme.surfaceVariant;
        } else if (domain === "binary_sensor") {
            return state === "on"
                ? Qt.rgba(theme.warning.r, theme.warning.g, theme.warning.b, 0.15)
                : theme.surfaceVariant;
        } else if (domain === "climate") {
            return (state === "heat" || state === "cool")
                ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.15)
                : theme.surfaceVariant;
        }
        return Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.1);
    }

    function formatStateValue(state, unitOfMeasurement) {
        var val = state || "?";
        var unit = unitOfMeasurement || "";
        return unit ? val + unit : val;
    }

    function safeAttr(entity, attrName, defaultValue) {
        return (entity && entity.attributes && entity.attributes[attrName] !== undefined)
            ? entity.attributes[attrName]
            : defaultValue;
    }
}
