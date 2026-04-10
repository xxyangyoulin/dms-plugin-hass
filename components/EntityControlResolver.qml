pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "../services"

QtObject {
    readonly property var controlConfig: ({
        light: {
            brightnessIcon: "brightness_6",
            colorTempIcon: "thermostat",
            colorTempStepKelvin: 50
        },
        general: {
            numberIcon: "tune",
            buttonIcon: "touch_app",
            buttonLabel: "Press"
        },
        climate: {
            hvacLabel: "Mode",
            fanLabel: "Fan Mode",
            fanIcon: "mode_fan",
            presetLabel: "Preset",
            swingLabel: "Swing"
        },
        fan: {
            speedIcon: "mode_fan",
            presetLabel: "Preset"
        },
        cover: {
            positionIcon: "roller_shades"
        }
    })

    function _effectiveAttr(entityData, key, fallbackValue) {
        return EntityHelper.getEffectiveValue(entityData, key, fallbackValue);
    }

    function _attr(entityData, key, fallbackValue) {
        if (!entityData || !entityData.attributes || entityData.attributes[key] === undefined || entityData.attributes[key] === null)
            return fallbackValue;
        return entityData.attributes[key];
    }

    function _colorTempKelvin(entityData) {
        const kelvin = _effectiveAttr(entityData, "color_temp_kelvin", null);
        if (kelvin && kelvin > 0)
            return kelvin;

        const colorTemp = _effectiveAttr(entityData, "color_temp", null);
        if (colorTemp !== null && colorTemp > 0)
            return Math.round(1000000 / colorTemp);

        return 0;
    }

    function _minColorTempKelvin(entityData) {
        const minKelvin = _attr(entityData, "min_color_temp_kelvin", null);
        if (minKelvin && minKelvin > 0)
            return minKelvin;

        const maxMireds = _attr(entityData, "max_mireds", null);
        if (maxMireds !== null && maxMireds > 0)
            return Math.round(1000000 / maxMireds);

        return Math.round(1000000 / HassConstants.defaultColorTempMax);
    }

    function _maxColorTempKelvin(entityData) {
        const maxKelvin = _attr(entityData, "max_color_temp_kelvin", null);
        if (maxKelvin && maxKelvin > 0)
            return maxKelvin;

        const minMireds = _attr(entityData, "min_mireds", null);
        if (minMireds !== null && minMireds > 0)
            return Math.round(1000000 / minMireds);

        return Math.round(1000000 / HassConstants.defaultColorTempMin);
    }

    function getLightSections(entityData) {
        if (!entityData)
            return [];

        const sections = [];

        if (HassConstants.lightSupportsBrightness(entityData)) {
            sections.push({
                type: "brightness",
                value: EntityHelper.getEffectiveValue(entityData, "brightness", 0),
                maxValue: HassConstants.defaultBrightnessMax,
                icon: controlConfig.light.brightnessIcon,
                displayValue: Math.round((EntityHelper.getEffectiveValue(entityData, "brightness", 0) / HassConstants.defaultBrightnessMax) * 100) + "%"
            });
        }

        if (HassConstants.lightSupportsColorTemp(entityData)) {
            sections.push({
                type: "color_temp",
                value: _colorTempKelvin(entityData),
                minValue: _minColorTempKelvin(entityData),
                maxValue: _maxColorTempKelvin(entityData),
                step: controlConfig.light.colorTempStepKelvin,
                icon: controlConfig.light.colorTempIcon,
                displayValue: Math.round(_colorTempKelvin(entityData)) + "K"
            });
        }

        if (HassConstants.lightSupportsColor(entityData)) {
            sections.push({
                type: "color",
                palette: HassConstants.lightColorPalette
            });
        }

        const effectList = EntityHelper.getEffectiveValue(entityData, "effect_list", []);
        if (effectList && effectList.length > 0) {
            sections.push({
                type: "effect",
                options: effectList,
                value: EntityHelper.getEffectiveValue(entityData, "effect", "")
            });
        }

        return sections;
    }

    function getGeneralSections(entityData) {
        if (!entityData)
            return [];

        const sections = [];
        const domain = entityData.domain || "";
        const options = EntityHelper.getEffectiveValue(entityData, "options", []);

        if (domain === "number" || domain === "input_number") {
            const numericValue = parseFloat(EntityHelper.getEffectiveValue(entityData, "state", 0)) || 0;
            const unit = entityData.unitOfMeasurement || "";
            sections.push({
                type: "number",
                value: numericValue,
                minValue: EntityHelper.getEffectiveValue(entityData, "min", 0),
                maxValue: EntityHelper.getEffectiveValue(entityData, "max", 100),
                step: EntityHelper.getEffectiveValue(entityData, "step", 1),
                icon: controlConfig.general.numberIcon,
                displayValue: Math.round(numericValue * 10) / 10 + unit
            });
        }

        if (domain === "select" || domain === "input_select") {
            sections.push({
                type: "select",
                value: EntityHelper.getEffectiveValue(entityData, "state", ""),
                options: options || []
            });
        }

        if (domain === "button") {
            sections.push({
                type: "button",
                icon: controlConfig.general.buttonIcon,
                label: controlConfig.general.buttonLabel
            });
        }

        if (options && options.length > 0 && domain !== "select" && domain !== "input_select" && domain !== "climate") {
            sections.push({
                type: "options",
                value: EntityHelper.getEffectiveValue(entityData, "state", ""),
                options: options
            });
        }

        return sections;
    }

    function getClimateSections(entityData) {
        if (!entityData)
            return [];

        const sections = [];

        sections.push({
            type: "temperature",
            value: EntityHelper.getEffectiveValue(entityData, "temperature", 20),
            step: EntityHelper.getEffectiveValue(entityData, "target_temp_step", 0.5),
            unit: EntityHelper.getEffectiveValue(entityData, "temperature_unit", "°C"),
            currentTemperature: EntityHelper.getEffectiveValue(entityData, "current_temperature", undefined)
        });

        const hvacModes = EntityHelper.getEffectiveValue(entityData, "hvac_modes", []);
        if (hvacModes && hvacModes.length > 0) {
            sections.push({
                type: "hvac_modes",
                value: EntityHelper.getEffectiveValue(entityData, "state", ""),
                options: hvacModes,
                label: controlConfig.climate.hvacLabel
            });
        }

        const fanModes = EntityHelper.getEffectiveValue(entityData, "fan_modes", []);
        if (fanModes && fanModes.length > 0) {
            sections.push({
                type: "fan_modes",
                value: EntityHelper.getEffectiveValue(entityData, "fan_mode", ""),
                options: fanModes,
                label: controlConfig.climate.fanLabel,
                icon: controlConfig.climate.fanIcon
            });
        }

        const presetModes = EntityHelper.getEffectiveValue(entityData, "preset_modes", []);
        if (presetModes && presetModes.length > 0) {
            sections.push({
                type: "preset_modes",
                value: EntityHelper.getEffectiveValue(entityData, "preset_mode", ""),
                options: presetModes,
                label: controlConfig.climate.presetLabel
            });
        }

        const swingModes = EntityHelper.getEffectiveValue(entityData, "swing_modes", []);
        if (swingModes && swingModes.length > 0) {
            sections.push({
                type: "swing_modes",
                value: EntityHelper.getEffectiveValue(entityData, "swing_mode", ""),
                options: swingModes,
                label: controlConfig.climate.swingLabel
            });
        }

        return sections;
    }

    function getFanSections(entityData) {
        if (!entityData)
            return [];

        const sections = [];

        if (HassConstants.supportsFeature(entityData, HassConstants.fanFeature.SET_SPEED)) {
            const state = EntityHelper.getEffectiveValue(entityData, "state", "");
            const isOn = state === "on";
            const percentage = EntityHelper.getEffectiveValue(entityData, "percentage", 0);
            const percentageStep = EntityHelper.getEffectiveValue(entityData, "percentage_step", 1);
            if (HassConstants.fanShouldUseButtons(entityData)) {
                let options = [];
                let value = percentageStep || 33.33;
                while (value <= 100.1) {
                    options.push(value);
                    value += percentageStep || 33.33;
                }
                sections.push({
                    type: "speed_buttons",
                    value: isOn ? percentage : null,
                    options: options
                });
            } else {
                sections.push({
                    type: "speed_slider",
                    value: isOn ? percentage : 0,
                    step: percentageStep,
                    maxValue: 100,
                    icon: controlConfig.fan.speedIcon,
                    displayValue: (isOn ? Math.round(percentage) : 0) + "%"
                });
            }
        }

        if (HassConstants.supportsFeature(entityData, HassConstants.fanFeature.OSCILLATE)) {
            sections.push({
                type: "oscillation",
                value: EntityHelper.getEffectiveValue(entityData, "oscillating", false)
            });
        }

        const presetModes = EntityHelper.getEffectiveValue(entityData, "preset_modes", []);
        if (presetModes && presetModes.length > 0) {
            sections.push({
                type: "preset_modes",
                value: EntityHelper.getEffectiveValue(entityData, "preset_mode", ""),
                options: presetModes,
                label: controlConfig.fan.presetLabel
            });
        }

        return sections;
    }

    function getCoverSections(entityData) {
        if (!entityData)
            return [];

        const sections = [];
        const currentPosition = EntityHelper.getEffectiveValue(entityData, "current_position", undefined);
        if (currentPosition !== undefined) {
            sections.push({
                type: "position",
                value: currentPosition,
                maxValue: 100,
                icon: controlConfig.cover.positionIcon,
                displayValue: currentPosition + "%"
            });
        }

        return sections;
    }
}
