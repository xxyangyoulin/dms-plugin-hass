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
    readonly property int optimisticCleanupInterval: 2000
    readonly property int optimisticStateTimeout: 30000
    readonly property int confirmationDelay: 1000  // 1 second delay for pending confirmations
    readonly property int refreshDelay: 500
    readonly property int historyHours: 24
    readonly property int historyCacheDuration: 300000  // 5 minutes
    readonly property int historyCleanupInterval: 600000  // 10 minutes

    // WebSocket
    readonly property int wsPingInterval: 30000  // 30 seconds
    readonly property int callbackGcInterval: 30000  // 30 seconds
    readonly property int callbackTimeout: 60000  // 60 seconds
    readonly property int initialReconnectInterval: 5000  // 5 seconds
    readonly property int maxReconnectInterval: 60000  // 1 minute

    // Light defaults
    readonly property int defaultBrightnessMin: 0
    readonly property int defaultBrightnessMax: 255
    readonly property int defaultColorTempMin: 153  // mireds
    readonly property int defaultColorTempMax: 500  // mireds

    // HTTP request
    readonly property int httpRequestTimeout: 10000  // 10 seconds
    readonly property int maxRequestRetries: 2

    // ========== Feature Bitmasks (from Home Assistant) ==========
    // Fan Features: https://github.com/home-assistant/core/blob/dev/homeassistant/components/fan/__init__.py
    readonly property var fanFeature: ({
        SET_SPEED: 1,
        OSCILLATE: 2,
        DIRECTION: 4,
        PRESET_MODE: 8,
        TURN_OFF: 16,
        TURN_ON: 32
    })

    // Media Player Features
    readonly property var mediaFeature: ({
        PAUSE: 1,
        SEEK: 2,
        VOLUME_SET: 4,
        VOLUME_MUTE: 8,
        PREVIOUS_TRACK: 16,
        NEXT_TRACK: 32,
        TURN_ON: 128,
        TURN_OFF: 256,
        PLAY_MEDIA: 512,
        VOLUME_STEP: 1024,
        SELECT_SOURCE: 2048,
        STOP: 4096,
        CLEAR_PLAYLIST: 8192,
        PLAY: 16384,
        SHUFFLE_SET: 32768,
        SELECT_SOUND_MODE: 65536,
        BROWSE_MEDIA: 131072,
        REPEAT_SET: 262144,
        GROUPING: 524288
    })

    // Light Color Modes
    readonly property var lightColorMode: ({
        UNKNOWN: "unknown",
        ONOFF: "onoff",
        BRIGHTNESS: "brightness",
        COLOR_TEMP: "color_temp",
        HS: "hs",
        XY: "xy",
        RGB: "rgb",
        RGBW: "rgbw",
        RGBWW: "rgbww",
        WHITE: "white"
    })

    // Modes that support brightness
    readonly property var lightModesSupportingBrightness: [
        "brightness", "color_temp", "hs", "xy", "rgb", "rgbw", "rgbww", "white"
    ]

    // Modes that support color
    readonly property var lightModesSupportingColor: [
        "hs", "xy", "rgb", "rgbw", "rgbww"
    ]

    // Max speed count before switching from buttons to slider
    readonly property int fanSpeedCountMaxForButtons: 4

    // Helper functions
    function getIconForDomain(domain) {
        return domainIcons[domain] || "sensors";
    }

    // Predefined color palette for light color selection
    readonly property var lightColorPalette: [
        { name: "White", r: 255, g: 255, b: 255 },
        { name: "Red", r: 255, g: 0, b: 0 },
        { name: "Orange", r: 255, g: 127, b: 0 },
        { name: "Yellow", r: 255, g: 255, b: 0 },
        { name: "Green", r: 0, g: 255, b: 0 },
        { name: "Cyan", r: 0, g: 255, b: 255 },
        { name: "Blue", r: 0, g: 0, b: 255 },
        { name: "Purple", r: 127, g: 0, b: 255 },
        { name: "Pink", r: 255, g: 0, b: 127 }
    ]

    function isControllableDomain(domain) {
        return controllableDomains.indexOf(domain) >= 0;
    }

    // Check if entity is in "active" state (on, heat, cool, playing, etc.)
    function isActiveState(domain, state) {
        if (!state || state === "unknown" || state === "unavailable") return false;
        
        // Climate devices: active if not "off"
        if (domain === "climate") {
            return state !== "off";
        }
        
        // Cover: active if open
        if (domain === "cover") {
            return state === "open";
        }
        
        // Lock: active if locked
        if (domain === "lock") {
            return state === "locked";
        }
        
        // Media player: active if playing
        if (domain === "media_player") {
            return state === "playing" || state === "on";
        }
        
        // Default: check for "on" state
        return state === "on";
    }

    function getStateColor(domain, state, theme) {
        if (domain === "light" || domain === "switch") {
            return state === "on" ? theme.primary : theme.surfaceVariantText;
        } else if (domain === "binary_sensor") {
            return state === "on" ? theme.warning : theme.surfaceVariantText;
        } else if (domain === "climate") {
            return state !== "off" ? theme.primary : theme.surfaceVariantText;
        } else if (domain === "cover") {
            return state === "open" ? theme.primary : theme.surfaceVariantText;
        } else if (domain === "lock") {
            return state === "locked" ? theme.primary : theme.surfaceVariantText;
        }
        return theme.primary;
    }

    function getIconBackgroundColor(domain, state, theme) {
        const active = isActiveState(domain, state);
        
        if (domain === "binary_sensor") {
            return active
                ? Qt.rgba(theme.warning.r, theme.warning.g, theme.warning.b, 0.15)
                : theme.surfaceVariant;
        }
        
        // For all controllable domains
        if (active) {
            return Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.15);
        }
        return theme.surfaceVariant;
    }

    function formatStateValue(state, unitOfMeasurement) {
        var val = state || "?";
        var unit = unitOfMeasurement || "";
        // Hide unit when state is unavailable or unknown
        if (val === "unavailable" || val === "unknown") return val;
        return unit ? val + unit : val;
    }

    function safeAttr(entity, attrName, defaultValue) {
        return (entity && entity.attributes && entity.attributes[attrName] !== undefined)
            ? entity.attributes[attrName]
            : defaultValue;
    }

    // ========== Feature Detection Helpers ==========
    // Check if entity supports a specific feature (bitmask check)
    function supportsFeature(entity, feature) {
        if (!entity || !entity.attributes) return false;
        var features = entity.attributes.supported_features || 0;
        return (features & feature) !== 0;
    }

    // Check if light supports brightness
    function lightSupportsBrightness(entity) {
        if (!entity || !entity.attributes) return false;
        var modes = entity.attributes.supported_color_modes || [];
        for (var i = 0; i < modes.length; i++) {
            if (lightModesSupportingBrightness.indexOf(modes[i]) >= 0) {
                return true;
            }
        }
        return false;
    }

    // Check if light supports color
    function lightSupportsColor(entity) {
        if (!entity || !entity.attributes) return false;
        var modes = entity.attributes.supported_color_modes || [];
        for (var i = 0; i < modes.length; i++) {
            if (lightModesSupportingColor.indexOf(modes[i]) >= 0) {
                return true;
            }
        }
        return false;
    }

    // Check if light supports color temp
    function lightSupportsColorTemp(entity) {
        if (!entity || !entity.attributes) return false;
        var modes = entity.attributes.supported_color_modes || [];
        return modes.indexOf("color_temp") >= 0;
    }

    // Compute fan speed count from percentage_step
    function computeFanSpeedCount(entity) {
        var step = safeAttr(entity, "percentage_step", 1);
        return Math.round(100 / step) + 1;
    }

    // Check if fan should use buttons (few speeds) or slider (many speeds)
    function fanShouldUseButtons(entity) {
        return computeFanSpeedCount(entity) <= fanSpeedCountMaxForButtons;
    }
}
