.pragma library

function fields(entity, sections) {
    if (!entity) return [];
    const domain = entity.domain;
    const attrs = entity.attributes || {};
    const result = [];
    if (["fan", "light", "switch", "input_boolean"].includes(domain))
        result.push({key: "power", label: "Power", options: ["on", "off"]});
    const mapping = {
        hvac_modes: ["hvac_mode", "set_hvac_mode", "Mode"],
        fan_modes: ["fan_mode", "set_fan_mode", "Fan speed"],
        preset_modes: ["preset_mode", "set_preset_mode", "Preset"],
        swing_modes: ["swing_mode", "set_swing_mode", "Swing"],
        speed_buttons: ["percentage", "turn_on", "Speed (%)"],
        speed_slider: ["percentage", "turn_on", "Speed (%)"],
        temperature: ["temperature", "set_temperature", "Temperature"],
        brightness: ["brightness", "turn_on", "Brightness"],
        oscillation: ["oscillating", "oscillate", "Oscillation"]
    };
    for (const section of sections) {
        const map = mapping[section.type];
        if (!map) continue;
        const field = {key: map[0], service: map[1], label: map[2]};
        if (section.options) field.options = section.options;
        if (section.type === "oscillation") field.options = [true, false];
        if (section.type === "temperature") {
            field.min = attrs.min_temp === undefined ? 7 : attrs.min_temp;
            field.max = attrs.max_temp === undefined ? 35 : attrs.max_temp;
            field.step = attrs.target_temp_step || 1;
        }
        if (field.key === "percentage") {
            field.min = attrs.percentage_step || 1;
            field.max = 100;
            field.step = attrs.percentage_step || 1;
            const count = Math.round(100 / field.step);
            if (attrs.percentage_step > 1 && count > 0 && count <= 100 && Math.abs(count * field.step - 100) < 0.2) {
                field.options = Array.from({length: count}, (_, i) => Math.min(100, Math.round((i + 1) * 100 / count)));
                field.gears = true;
                field.label = "Speed";
            }
        }
        if (field.key === "brightness") { field.min = 1; field.max = 255; field.step = 1; }
        result.push(field);
    }
    if (["select", "input_select"].includes(domain) && attrs.options && attrs.options.length)
        result.push({key: "option", service: "select_option", label: "Option", options: attrs.options});
    if (["number", "input_number"].includes(domain))
        result.push({key: "value", service: "set_value", label: "Value", min: attrs.min, max: attrs.max, step: attrs.step || 1});
    return result;
}

function validValue(field, value) {
    if (!field) return false;
    if (field.options) return field.options.includes(value);
    if (typeof value !== "number" || !isFinite(value) || value < field.min || value > field.max) return false;
    const steps = (value - field.min) / field.step;
    return Math.abs(steps - Math.round(steps)) < 0.001;
}

function action(entity, field, value, label) {
    return {entityId: entity.entityId, domain: entity.domain, key: field.key,
        service: field.key === "power" ? "turn_" + value : field.service,
        data: field.key === "power" ? {} : {[field.key]: value}, value: value, label: label};
}

function ordered(actions) {
    // Preserve entity order, but apply climate mode before its other settings.
    const ids = [...new Set(actions.map(a => a.entityId))];
    let result = [];
    for (const id of ids) {
        const group = actions.filter(a => a.entityId === id).sort((a, b) => {
            const rank = item => item.key === "hvac_mode" || item.key === "power" ? 0 : item.key === "temperature" ? 1 : 2;
            return rank(a) - rank(b);
        });
        result = result.concat(group);
    }
    return result;
}
