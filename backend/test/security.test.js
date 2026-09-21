const { test } = require('node:test');
const assert = require('node:assert/strict');
const { integer, documentId, object } = require('../src/utils/validation');
const { commandFrame, responseFrame, sign } = require('../src/services/iotProtocol');
const { generarPasswordInicial } = require('../src/utils/passwordGenerator');

const key = Buffer.alloc(32, 17);
const id = 'a'.repeat(32);

test('strict validation rejects coercion and path injection', () => {
    for (const value of ['12abc', '1.1', '1e3', -1, NaN, Infinity, 1.5, null, true, {}, []]) {
        assert.throws(() => integer(value, 'count'));
    }
    assert.equal(integer('12', 'count'), 12);
    for (const value of ['../other', 'a/b', '', [], {}]) assert.throws(() => documentId(value));
    for (const value of [null, [], 'hello']) assert.throws(() => object(value));
});

test('initial credentials are cryptographically random', () => {
    const values = new Set(Array.from({ length: 100 }, () => generarPasswordInicial('Ana', 'Perez')));
    assert.equal(values.size, 100);
    assert.ok([...values].every(value => value.length >= 40));
});

test('authenticated frames reject manipulation and foreign keys', () => {
    const command = commandFrame({ requestId: id, sessionId: id, expires: 2000000060, command: 'S' }, key);
    assert.ok(command.length <= 180);
    const payload = `R1|${id}|${id}|RESULT|27|2000000000|1999999999`;
    const frame = `${payload}|${sign(payload, key)}`;
    assert.equal(responseFrame(frame, key).count, 27);
    assert.throws(() => responseFrame(frame.replace('|27|', '|28|'), key));
    assert.throws(() => responseFrame(frame, Buffer.alloc(32, 18)));
});
