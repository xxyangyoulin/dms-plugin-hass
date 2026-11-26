import QtQuick
import QtTest
import "../components/CombinationActions.js" as Actions

TestCase {
    name: "CombinationActions"

    function test_orderBeforeSave() {
        const actions = [
            {entityId: "climate.test", key: "fan_mode", data: {fan_mode: "6"}},
            {entityId: "fan.test", key: "percentage", data: {percentage: 67}},
            {entityId: "climate.test", key: "temperature", data: {temperature: 26}},
            {entityId: "climate.test", key: "hvac_mode", data: {hvac_mode: "cool"}}
        ];
        const ordered = Actions.ordered(actions);
        compare(ordered.length, 4);
        compare(ordered.map(a => a.key).join(","), "hvac_mode,temperature,fan_mode,percentage");
        compare(ordered[1].data.temperature, 26);
        compare(ordered[2].data.fan_mode, "6");
        compare(actions[0].key, "fan_mode");
        compare(Actions.ordered([]).length, 0);
    }
}
