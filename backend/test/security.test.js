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

test('initial passwords use the first name initial and first surname', () => {
    assert.equal(generarPasswordInicial('Pedro', 'Carbon'), 'pcarbon');
    assert.equal(generarPasswordInicial(' Pedro José ', ' Carbón López '), 'pcarbon');
    assert.equal(generarPasswordInicial('JOSÉ', 'PÉREZ'), 'jperez');
    assert.equal(generarPasswordInicial('Ángela', 'Núñez'), 'anunez');
    assert.equal(generarPasswordInicial('Ana', "O'Connor"), 'aoconnor');
});

test('short initial passwords meet the Firebase minimum length', () => {
    assert.equal(generarPasswordInicial('Ana', 'Li'), 'ali000');
    assert.equal(generarPasswordInicial('Luis', 'Paz'), 'lpaz00');
});

test('initial passwords reject names without usable characters', () => {
    for (const [nombre, apellidos] of [[null, 'Carbon'], ['Pedro', undefined], ['', 'Carbon'], ['Pedro', '   '], ['!!!', 'Carbon']]) {
        assert.throws(() => generarPasswordInicial(nombre, apellidos), error => error.status === 400);
    }
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

test('protocol frames reject malformed, expired and unknown values', () => {
    assert.throws(() => commandFrame({ requestId: id, sessionId: '-', expires: 0, command: 'H' }, key));
    assert.throws(() => commandFrame({ requestId: id, sessionId: '-', expires: 2000000060, command: 'Z' }, key));
    assert.throws(() => commandFrame({ requestId: 'A'.repeat(32), sessionId: '-', expires: 2000000060, command: 'H' }, key));

    const signed = (payload) => `${payload}|${sign(payload, key)}`;
    const partial = signed(`R1|${id}|${id}|RUNNING|-|2000000000|-`);
    const parsed = responseFrame(partial, key);
    assert.equal(parsed.count, null);
    assert.equal(parsed.completedAt, null);

    assert.throws(() => responseFrame(signed(`R1|${id}|${id}|BROKEN|1|2000000000|-`), key));
    assert.throws(() => responseFrame(signed(`R1|${id}|${id}|STOPPED|-1|2000000000|1999999999`), key));
    assert.throws(() => responseFrame(signed(`R1|${id}|${id}|RESULT|27|2000000000`), key));
    assert.throws(() => responseFrame(`R1|${id}|${id}|RESULT|27|2000000000|1999999999|${'z'.repeat(32)}`, key));
    assert.throws(() => responseFrame(`R1|${id}|${id}|RESULT|27|2000000000|-|${sign(`R1|${id}|${id}|RESULT|27|2000000000|-`, key)}`.padEnd(220, 'x'), key));
    assert.throws(() => responseFrame(`R1|${id}|${id}|RESULT|27|2000\u00070000|-|${'0'.repeat(32)}`, key));
});
