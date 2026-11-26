const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, '..');
const actions = fs.readFileSync(path.join(root, 'components/CombinationActions.js'), 'utf8').replace('.pragma library', '');
const context = vm.createContext({});
vm.runInContext(actions, context);
const fan = {entityId: 'fan.test', domain: 'fan', attributes: {percentage_step: 33.33}};
const speed = context.fields(fan, [{type: 'speed_buttons', options: [33.33, 66.66, 99.99]}])[1];
assert.equal(speed.gears, true);
assert.equal(speed.options[1], 67);
assert.equal(context.validValue(speed, 67), true);
assert.equal(context.validValue(speed, 6), false);
const climate = {entityId: 'climate.test', domain: 'climate', attributes: {min_temp: 16, max_temp: 30, target_temp_step: 0.5}};
const fields = context.fields(climate, [{type: 'temperature'}, {type: 'hvac_modes', options: ['off', 'cool']}, {type: 'fan_modes', options: ['auto', '6']}]);
assert.equal(context.validValue(fields[0], 26), true);
assert.equal(context.validValue(fields[0], 26.1), false);
assert.equal(context.validValue(fields[0], 31), false);
assert.equal(context.validValue(fields[2], '6'), true);
assert.equal(context.validValue(fields[2], 6), false);
const temp = context.action(climate, fields[0], 26, 'temperature');
const mode = context.action(climate, fields[1], 'cool', 'mode');
const fanMode = context.action(climate, fields[2], '6', 'fan');
const ordered = context.ordered([temp, fanMode, mode]);
assert.equal(ordered.map(a => a.key).join(','), 'hvac_mode,temperature,fan_mode');
assert.equal(temp.data.temperature, 26);
assert.equal(fanMode.data.fan_mode, '6');
assert.equal(context.action(fan, {key: 'power'}, 'off', 'off').service, 'turn_off');

const source = fs.readFileSync(path.join(root, 'services/HomeAssistantService.qml'), 'utf8');
function extract(name) {
    const start = source.indexOf('    function ' + name + '(');
    const end = source.indexOf('\n    function ', start + 1);
    return source.slice(start, end < 0 ? source.length : end);
}
const calls = [], queue = [], notifications = [], saved = [];
const timers = [];
const service = vm.createContext({
    shortcuts: [{id: 'combo', name: 'Summer', actions: ordered}], runningCombinations: {},
    connectionGeneration: 1, suppressReconnect: false, root: {},
    Components: {HassConstants: {httpRequestTimeout: 100, callbackTimeout: 100}},
    Qt: {callLater: callback => queue.push(callback)},
    ToastService: {showInfo: (...args) => notifications.push(['success', ...args]), showError: (...args) => notifications.push(['error', ...args])},
    I18n: {trFor: (_, text) => text},
    callService: (...args) => calls.push(args),
    requestTimerComponent: {createObject: () => {
        const timer = {triggered: {connect: cb => timer.fire = cb}, start() {}, stop() {}, destroy() {}};
        timers.push(timer);
        return timer;
    }},
    _syncShortcutsModel() {}, savePersistentPluginValue: (...args) => saved.push(args)
});
vm.runInContext(extract('runCombination'), service);
vm.runInContext(extract('saveCombination'), service);
service.saveCombination('new', ' New ', ordered);
assert.equal(calls.length, 0, 'saving must not control devices');
assert.equal(saved.length, 1);
service.runCombination('combo');
service.runCombination('combo');
assert.equal(calls.length, 1, 'busy combination must not run twice');
assert.equal(calls[0][1], 'set_hvac_mode');
calls[0][4](true, '');
queue.shift()();
assert.equal(calls[1][1], 'set_temperature');
calls[1][4](false, 'device unavailable');
queue.shift()();
assert.equal(calls[2][1], 'set_fan_mode', 'continue after an individual failure');
calls[2][4](true, '');
queue.shift()();
assert.equal(notifications[0][0], 'error');
assert.match(notifications[0][2], /temperature: device unavailable/);
assert.equal(service.runningCombinations.combo, undefined);
service.runCombination('combo');
service.connectionGeneration++;
calls[3][4](true, '');
queue.shift()();
assert.equal(calls.length, 4, 'stop submitting commands after connection changes');
assert.equal(service.runningCombinations.combo, undefined);
service.runCombination('combo');
timers.at(-1).fire();
calls[4][4](true, '');
assert.equal(queue.length, 1, 'late responses must not advance the sequence twice');
console.log('Combination mapping, persistence, ordering, failure and interruption checks passed.');
const requests = [];
const transport = vm.createContext({
    connectionResetQueued: false, suppressReconnect: false, hassUrl: 'http://test', hassToken: 'test',
    canUseWebSocketApi: () => true,
    sendWsMessage: (message, cb) => requests.push({message, cb}),
    setEntityActionState() {}, fetchEntity() {}, getEntityActionState: () => ({status: 'pending'}),
    canAssumeImmediateSuccess: () => false, actionStateTimeoutTimer: {start() {}},
    formatServiceError: response => response.error,
    makeRequest: (method, endpoint, data, cb) => requests.push({method, endpoint, data, cb}),
    I18n: {trFor: (_, text) => text}, console: {error() {}}
});
vm.runInContext(extract('callService'), transport);
const results = [];
const data = {temperature: 26};
transport.callService('climate', 'set_temperature', 'climate.test', data, (...args) => results.push(args));
assert.equal(data.entity_id, undefined, 'transport must not mutate saved action data');
assert.equal(requests[0].message.service_data.entity_id, 'climate.test');
requests.shift().cb({success: true});
assert.equal(results.pop()[0], true);
transport.callService('climate', 'set_temperature', 'climate.test', data, (...args) => results.push(args));
requests.shift().cb({success: false, error: 'offline'});
assert.deepEqual(results.pop(), [false, 'offline']);
transport.canUseWebSocketApi = () => false;
transport.callService('climate', 'set_temperature', 'climate.test', data, (...args) => results.push(args));
assert.equal(requests[0].endpoint, '/api/services/climate/set_temperature');
requests.shift().cb('{}', 0);
assert.equal(results.pop()[0], true);
transport.callService('climate', 'set_temperature', 'climate.test', data, (...args) => results.push(args));
requests.shift().cb('', 500);
assert.equal(results.pop()[0], false);
transport.hassToken = '';
transport.callService('climate', 'set_temperature', 'climate.test', data, (...args) => results.push(args));
assert.equal(results.pop()[0], false);
console.log('WebSocket and HTTP completion callbacks and data isolation checks passed.');
