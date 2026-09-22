const { COMMANDS, commandFrame, responseFrame } = require('./iotProtocol');
const { FieldValue } = require('firebase-admin/firestore');
const { HttpError, object, hexId, documentId, integer, text } = require('../utils/validation');

function createIotService(db) {
    const deviceId = () => documentId(process.env.IOT_DEVICE_ID || 'jetson-01');
    const deviceRef = () => db.collection('IotDevices').doc(deviceId());
    const sessions = db.collection('IotSessions');
    const tickets = db.collection('IotCommands');

    async function issue(uid, input) {
        const body = object(input);
        const requestId = hexId(body.request_id);
        const requested = typeof body.command === 'string' && Object.hasOwn(COMMANDS, body.command)
            ? COMMANDS[body.command]
            : null;
        if (!requested) throw new HttpError(400, 'Comando no permitido.');
        const now = Math.floor(Date.now() / 1000);
        return db.runTransaction(async tx => {
            const ticketRef = tickets.doc(requestId);
            const prior = await tx.get(ticketRef);
            if (prior.exists) {
                const data = prior.data();
                if (data.uid !== uid || data.requested !== requested
                    || (body.session_id && body.session_id !== data.session_id)) {
                    throw new HttpError(409, 'Solicitud ya utilizada.');
                }
                if (data.expires < now) throw new HttpError(409, 'La solicitud vencio. Consulta el estado del equipo.');
                return data;
            }
            let command = requested;
            let sessionId = '-';
            const device = await tx.get(deviceRef());
            const active = device.data() || {};
            if (['S', 'T', 'Q', 'R'].includes(command)) {
                if (command === 'S') {
                    if (active.lease_until > now) {
                        if (active.uid !== uid) throw new HttpError(409, 'El equipo esta ocupado por otra sesion.');
                        sessionId = active.session_id;
                        command = 'Q';
                    } else {
                        const config = await tx.get(db.collection('Usuarios').doc(uid).collection('ConfiguracionSistema').doc('general'));
                        if (!config.exists) throw new HttpError(400, 'Configura la finca antes del conteo.');
                        sessionId = requestId;
                        tx.create(sessions.doc(sessionId), {
                            uid, device_id: deviceId(),
                            cantidad_esperada: integer(config.data().cantidad_esperada, 'Cantidad esperada', 1),
                            nombre_finca: text(config.data().nombre_finca, 'Nombre de finca'),
                            started_at: new Date(), status: 'PENDING',
                        });
                        tx.set(deviceRef(), { uid, session_id: sessionId, lease_until: now + 900 });
                    }
                } else {
                    sessionId = body.session_id ? hexId(body.session_id) : active.session_id;
                    if (!sessionId) throw new HttpError(409, 'No hay una sesion de conteo.');
                    const session = await tx.get(sessions.doc(sessionId));
                    if (!session.exists || session.data().uid !== uid) throw new HttpError(403, 'La sesion no pertenece al usuario.');
                    if (active.session_id !== sessionId) throw new HttpError(409, 'Esta sesion ya no esta en el equipo.');
                }
            }
            const expires = now + 60;
            const frame = commandFrame({ requestId, expires, command, sessionId });
            const data = { uid, requested, command, request_id: requestId, session_id: sessionId, frame, issued: now, expires, expires_at: new Date((now + 86400) * 1000) };
            tx.create(ticketRef, data);
            return data;
        });
    }

    async function verify(uid, raw) {
        const result = responseFrame(raw);
        return db.runTransaction(async tx => {
            const ticket = await tx.get(tickets.doc(result.requestId));
            const data = ticket.data();
            if (!data || data.uid !== uid || data.session_id !== result.sessionId) throw new HttpError(403, 'Respuesta ajena a la solicitud.');
            const now = Math.floor(Date.now() / 1000);
            if (data.response && data.response !== raw) throw new HttpError(409, 'La solicitud ya tiene otra respuesta.');
            if (!data.response && (result.timestamp < data.issued - 5 || result.timestamp > data.expires + 30 || Math.abs(now - result.timestamp) > 300)) {
                throw new HttpError(409, 'Respuesta vencida. Consulta de nuevo el resultado.');
            }
            const terminal = ['STOPPED', 'RESULT'].includes(result.status) && result.count !== null;
            let session;
            if (result.sessionId !== '-') session = await tx.get(sessions.doc(result.sessionId));
            const device = await tx.get(deviceRef());
            if (session && (!session.exists || session.data().uid !== uid)) throw new HttpError(403, 'Sesion invalida.');
            if (session && terminal && session.data().proof && session.data().count !== result.count) throw new HttpError(409, 'El resultado final ya fue registrado con otra cantidad.');
            if (terminal && (!session || !result.completedAt || result.completedAt > result.timestamp + 5 || result.completedAt * 1000 < session.data().started_at.toDate().getTime() - 5000)) throw new HttpError(400, 'Fecha de finalizacion invalida.');
            tx.update(ticket.ref, { response: raw });
            if (session && !session.data().proof) {
                tx.update(session.ref, terminal
                    ? { status: result.status, count: result.count, proof: raw, finished_at: new Date(result.completedAt * 1000) }
                    : { status: result.status, ...(data.command === 'S' && result.status === 'STARTED' ? { started_at: new Date(result.timestamp * 1000) } : {}) });
                if ((terminal || result.status === 'ERROR') && device.data()?.session_id === result.sessionId) {
                    tx.update(device.ref, { lease_until: 0 });
                }
            }
            // El equipo informo que no tiene sesion activa (por ejemplo, se
            // reinicio o el worker termino fuera de la app). Si no se libera
            // aqui, el siguiente INICIARCONTEO se convierte en ESTADOCONTEO
            // contra una sesion que ya no existe y la app queda atascada.
            if (result.status === 'IDLE' && device.data()?.session_id) {
                tx.update(device.ref, { lease_until: 0, session_id: FieldValue.delete() });
            }
            return { status: result.status, session: result.sessionId, count: result.count === null ? 'unknown' : String(result.count), device_id: deviceId(), proof: terminal ? raw : null };
        });
    }

    return { issue, verify };
}

module.exports = { createIotService };
