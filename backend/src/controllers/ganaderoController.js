const { db, FieldValue } = require('../config/firebaseAdmin');
const { FieldPath, Timestamp } = require('firebase-admin/firestore');
const { object, text, integer, documentId, hexId, HttpError, respondError } = require('../utils/validation');
const { createIotService } = require('../services/iotService');
const iot = createIotService(db);

function serializeTimestamp(value) {
    if (!value) return null;
    if (typeof value.toDate === 'function') return value.toDate().toISOString();
    if (value instanceof Date) return value.toISOString();

    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function toInt(value) {
    if (typeof value === 'number') return Math.trunc(value);
    return Number.parseInt(value, 10) || 0;
}

function toDouble(value) {
    if (typeof value === 'number') return value;
    return Number.parseFloat(value) || 0;
}

function getRefs(uid) {
    const userRef = db.collection('Usuarios').doc(uid);

    return {
        userRef,
        configRef: userRef.collection('ConfiguracionSistema').doc('general'),
        deviceRef: userRef.collection('DispositivosConteo').doc('prototipo'),
        conteosRef: userRef.collection('Conteos'),
        alertasRef: userRef.collection('Alertas'),
    };
}

function mapConfiguracion(doc) {
    if (!doc.exists) return null;
    const data = doc.data() || {};

    return {
        id: doc.id,
        nombre_finca: (data.nombre_finca || '').toString(),
        cantidad_esperada: toInt(data.cantidad_esperada),
        fecha_actualizacion: serializeTimestamp(data.fecha_actualizacion),
    };
}

function mapDispositivo(doc) {
    if (!doc.exists) return null;
    const data = doc.data() || {};

    return {
        id: doc.id,
        nombre_dispositivo: (data.nombre_dispositivo || '').toString(),
        tipo_dispositivo: (data.tipo_dispositivo || '').toString(),
        estado_conexion: (data.estado_conexion || 'desconocido').toString(),
        ultima_sincronizacion: serializeTimestamp(data.ultima_sincronizacion),
        version_modelo: (data.version_modelo || '').toString(),
        estado_operativo: (data.estado_operativo || '').toString(),
        nivel_bateria: toDouble(data.nivel_bateria),
        coordenadas_gps: (data.coordenadas_gps || '').toString(),
        modo_operacion: (data.modo_operacion || 'lora').toString(),
    };
}

function isPlaceholderDispositivo(data) {
    const estadoConexion = (data.estado_conexion || '').toString();
    const estadoOperativo = (data.estado_operativo || '').toString();
    const nombre = (data.nombre_dispositivo || '').toString();

    return (
        nombre === 'BoviSense Bridge' &&
        estadoConexion === 'desconocido' &&
        estadoOperativo === 'pendiente'
    );
}

function mapConteo(doc) {
    const data = doc.data() || {};

    return {
        id: doc.id,
        fecha_hora_inicio: serializeTimestamp(data.fecha_hora_inicio),
        fecha_hora_fin: serializeTimestamp(data.fecha_hora_fin),
        cantidad_detectada: toInt(data.cantidad_detectada),
        cantidad_esperada: toInt(data.cantidad_esperada),
        diferencia: toInt(data.diferencia),
        estado_conteo: (data.estado_conteo || '').toString(),
        origen: (data.origen || 'lora').toString(),
        resumen: (data.resumen || '').toString(),
    };
}

function mapAlerta(doc) {
    const data = doc.data() || {};

    return {
        id: doc.id,
        mensaje: (data.mensaje || '').toString(),
        fecha_hora: serializeTimestamp(data.fecha_hora),
        tipo: (data.tipo || 'informativa').toString(),
        nivel: (data.nivel || 'baja').toString(),
        leida: Boolean(data.leida),
    };
}

function logGanadero(req, message, data = {}) {
    console.log('[GANADERO]', {
        requestId: req.requestId,
        uid: req.user?.uid,
        step: message,
        ...data,
    });
}

function timestampMillis(value) {
    if (!value) return 0;
    if (typeof value.toMillis === 'function') return value.toMillis();
    if (typeof value.toDate === 'function') return value.toDate().getTime();
    if (value instanceof Date) return value.getTime();
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? 0 : parsed.getTime();
}

async function getConfigDoc(uid, refs) {
    const current = await refs.configRef.get();
    if (current.exists) return current;

    const legacy = await db.collection('ConfiguracionSistema')
        .where('uid', '==', uid)
        .limit(1)
        .get();
    return legacy.docs[0] || current;
}

async function getRecentConteos(uid, refs, limit = 5) {
    const [current, legacy] = await Promise.all([
        refs.conteosRef.orderBy('fecha_hora_inicio', 'desc').limit(limit).get(),
        db.collection('Conteos').where('uid', '==', uid).limit(100).get(),
    ]);
    const docsById = new Map();
    for (const doc of [...legacy.docs, ...current.docs]) docsById.set(doc.id, doc);
    return [...docsById.values()]
        .sort((a, b) => timestampMillis(b.data()?.fecha_hora_inicio) - timestampMillis(a.data()?.fecha_hora_inicio))
        .slice(0, limit);
}

async function getRecentAlertas(uid, refs, limit = 5) {
    const [current, legacy] = await Promise.all([
        refs.alertasRef.orderBy('fecha_hora', 'desc').limit(limit).get(),
        db.collection('Alertas').where('uid', '==', uid).limit(100).get(),
    ]);
    const docsById = new Map();
    for (const doc of [...legacy.docs, ...current.docs]) docsById.set(doc.id, doc);
    return [...docsById.values()]
        .sort((a, b) => timestampMillis(b.data()?.fecha_hora) - timestampMillis(a.data()?.fecha_hora))
        .slice(0, limit);
}

// Cursor compuesto `fechaEnMillis_id`. La fecha sola no basta cuando varios
// registros comparten el mismo instante (importaciones o conteos seguidos):
// el cursor temporal excluia todo el grupo y los registros restantes quedaban
// inaccesibles. Se sigue aceptando un cursor antiguo (solo fecha): en ese caso
// se omite el grupo completo, como antes.
function parseCursor(value) {
    if (!value) return null;
    const text = String(value);
    const separator = text.indexOf('_');
    if (separator > 0) {
        const millis = Number(text.slice(0, separator));
        const id = text.slice(separator + 1);
        if (Number.isFinite(millis) && id) return { millis, id };
    }
    const parsed = new Date(text);
    return Number.isNaN(parsed.getTime()) ? null : { millis: parsed.getTime(), id: '' };
}

function isBeforeCursor(doc, sortField, cursor) {
    if (!cursor) return true;
    const millis = timestampMillis(doc.data()?.[sortField]);
    if (millis !== cursor.millis) return millis < cursor.millis;
    return doc.id < cursor.id;
}

// Lista mezclando la subcoleccion del usuario con la coleccion heredada y
// devuelve un cursor real.
//
// Antes solo se pedia `limit + 1` de la subcoleccion y el cursor excluia toda
// la fecha: con mas registros que la pagina compartiendo fecha, los sobrantes
// no se recuperaban en ninguna pagina. Ahora el cursor es (fecha, id), el
// orden desempata por id descendente y la subcoleccion se consulta con
// `startAfter` compuesto, sin partir grupos: un grupo mas grande que la pagina
// se recorre en varias paginas. La coleccion heredada (sin indice para
// ordenar) se filtra en memoria con el mismo criterio dentro de una ventana
// acotada.
const LEGACY_SCAN_LIMIT = 200;
async function listOwnedMerged(uid, refs, name, sortField, cursorValue, limit = 30) {
    const ref = name === 'Conteos' ? refs.conteosRef : refs.alertasRef;
    const cursor = parseCursor(cursorValue);
    const fetchLimit = limit + 1;
    let request = ref.orderBy(sortField, 'desc')
        .orderBy(FieldPath.documentId(), 'desc')
        .limit(fetchLimit);
    if (cursor) request = request.startAfter(Timestamp.fromMillis(cursor.millis), cursor.id);

    const [current, legacy] = await Promise.all([
        request.get(),
        db.collection(name).where('uid', '==', uid).limit(LEGACY_SCAN_LIMIT).get(),
    ]);

    const docsById = new Map();
    for (const doc of [...legacy.docs, ...current.docs]) {
        if (!isBeforeCursor(doc, sortField, cursor)) continue;
        docsById.set(doc.id, doc);
    }
    const docs = [...docsById.values()].sort((a, b) => {
        const difference = timestampMillis(b.data()?.[sortField]) - timestampMillis(a.data()?.[sortField]);
        if (difference !== 0) return difference;
        return a.id < b.id ? 1 : a.id > b.id ? -1 : 0;
    });

    const page = docs.slice(0, limit);
    const last = page[page.length - 1];
    const hasMore = docs.length > page.length || current.docs.length >= fetchLimit;
    return {
        docs: page,
        next_cursor: hasMore && last
            ? `${timestampMillis(last.data()?.[sortField])}_${last.id}`
            : null,
    };
}

async function getOwnedDoc(uid, refs, name, id) {
    const ref = name === 'Conteos' ? refs.conteosRef : refs.alertasRef;
    const current = await ref.doc(id).get();
    if (current.exists) return current;

    const legacy = await db.collection(name).doc(id).get();
    if (legacy.exists && legacy.data()?.uid === uid) return legacy;
    return current;
}

async function getDispositivo(uid) {
    const { deviceRef } = getRefs(uid);
    const current = await deviceRef.get();

    if (!current.exists) return null;

    const data = current.data() || {};
    if (isPlaceholderDispositivo(data)) return null;

    return mapDispositivo(current);
}

function calcularDiferencia(cantidadEsperada, cantidadDetectada) {
    return cantidadDetectada - cantidadEsperada;
}

function buildResumen(cantidadDetectada, cantidadEsperada, diferencia) {
    if (diferencia === 0) {
        return `Conteo exitoso. Se detectaron ${cantidadDetectada} animales, coincidiendo con la cantidad esperada.`;
    }

    if (diferencia > 0) {
        return `Conteo finalizado. Se detectaron ${cantidadDetectada} animales, es decir ${diferencia} más de lo esperado.`;
    }

    return `Conteo finalizado. Se detectaron ${cantidadDetectada} animales, faltando ${Math.abs(diferencia)} respecto a lo esperado.`;
}

function buildAlertData(diferencia) {
    if (diferencia === 0) return null;

    const abs = Math.abs(diferencia);

    return {
        mensaje:
            diferencia > 0
                ? `Se detectó un excedente de ${abs} animales respecto a la cantidad esperada.`
                : `Se detectó un faltante de ${abs} animales respecto a la cantidad esperada.`,
        tipo: diferencia > 0 ? 'excedente' : 'faltante',
        nivel: abs >= 10 ? 'alta' : abs >= 4 ? 'media' : 'baja',
        leida: false,
        fecha_hora: FieldValue.serverTimestamp(),
    };
}

async function obtenerDashboard(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        logGanadero(req, 'dashboard:start');
        const [config, device, counts, alerts, legacyCounts, legacyAlerts, recent, recentAlerts] = await Promise.all([
            getConfigDoc(req.user.uid, refs), getDispositivo(req.user.uid),
            refs.conteosRef.count().get(), refs.alertasRef.where('leida', '==', false).count().get(),
            db.collection('Conteos').where('uid', '==', req.user.uid).count().get(),
            db.collection('Alertas').where('uid', '==', req.user.uid).where('leida', '==', false).count().get(),
            getRecentConteos(req.user.uid, refs),
            getRecentAlertas(req.user.uid, refs),
        ]);
        const conteos = recent.map(mapConteo);
        const currentCount = counts.data().count;
        const legacyCount = legacyCounts.data().count;
        const currentPendingAlerts = alerts.data().count;
        const legacyPendingAlerts = legacyAlerts.data().count;
        logGanadero(req, 'dashboard:loaded', {
            hasConfig: config.exists,
            hasDevice: Boolean(device),
            conteosActuales: currentCount,
            conteosLegacy: legacyCount,
            alertasActuales: currentPendingAlerts,
            alertasLegacy: legacyPendingAlerts,
            recientes: conteos.length,
        });
        return res.json({
            configuracion: mapConfiguracion(config), dispositivo: device,
            conteos_recientes: conteos, alertas_recientes: recentAlerts.map(mapAlerta),
            ultimo_conteo: conteos[0] || null, cantidad_conteos: currentCount + legacyCount,
            alertas_pendientes: currentPendingAlerts + legacyPendingAlerts, ultima_diferencia: conteos[0]?.diferencia || 0,
        });
    } catch (error) { return respondError(res, error); }
}

async function obtenerConfiguracion(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        const config = await getConfigDoc(req.user.uid, refs);
        logGanadero(req, 'configuracion:loaded', { hasConfig: config.exists });
        return res.json({ configuracion: mapConfiguracion(config) });
    } catch (error) { return respondError(res, error); }
}

async function guardarConfiguracion(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        const body = object(req.body);
        const payload = {
            nombre_finca: text(body.nombre_finca, 'Nombre de finca'),
            cantidad_esperada: integer(body.cantidad_esperada, 'Cantidad esperada', 1),
        };
        await refs.configRef.set({ ...payload, fecha_actualizacion: FieldValue.serverTimestamp() }, { merge: true });
        return res.json({ configuracion: mapConfiguracion(await refs.configRef.get()), message: 'Configuracion guardada.' });
    } catch (error) { return respondError(res, error); }
}

async function obtenerDispositivo(req, res) {
    try { return res.json({ dispositivo: await getDispositivo(req.user.uid) }); }
    catch (error) { return respondError(res, error); }
}

async function registrarConteoReal(req, res) {
    try {
        const body = object(req.body);
        const sessionId = hexId(body.session_id);
        const verified = await iot.verify(req.user.uid, body.proof);
        if (verified.session !== sessionId || !verified.proof) throw new HttpError(400, 'Se requiere un resultado final autenticado.');
        const refs = getRefs(req.user.uid);
        const conteoRef = refs.conteosRef.doc(sessionId);
        const alertRef = refs.alertasRef.doc(sessionId);
        const created = await db.runTransaction(async tx => {
            const session = await tx.get(db.collection('IotSessions').doc(sessionId));
            const existing = await tx.get(conteoRef);
            if (!session.exists || session.data().uid !== req.user.uid) throw new HttpError(403, 'Sesion invalida.');
            if (existing.exists) return false;
            const data = session.data();
            if (!data.proof || data.count !== Number(verified.count)) throw new HttpError(409, 'El resultado de la sesion no coincide.');
            const cantidad = integer(data.count, 'Cantidad detectada');
            const esperada = integer(data.cantidad_esperada, 'Cantidad esperada', 1);
            const diferencia = calcularDiferencia(esperada, cantidad);
            tx.create(conteoRef, {
                fecha_hora_inicio: data.started_at, fecha_hora_fin: data.finished_at,
                cantidad_detectada: cantidad, cantidad_esperada: esperada, diferencia,
                estado_conteo: 'finalizado', origen: 'lora_autenticado', session_id: sessionId,
                device_id: data.device_id, nombre_finca: data.nombre_finca,
                resumen: buildResumen(cantidad, esperada, diferencia),
            });
            const alert = buildAlertData(diferencia);
            if (alert) tx.create(alertRef, alert);
            tx.set(refs.deviceRef, {
                nombre_dispositivo: 'BoviSense Bridge', tipo_dispositivo: 'ESP32 + LoRa + Jetson',
                ultima_sincronizacion: FieldValue.serverTimestamp(),
                estado_conexion: 'desconocido', estado_operativo: 'conteo_finalizado', modo_operacion: 'lora',
            }, { merge: true });
            tx.update(session.ref, { saved: true });
            return true;
        });
        return res.status(created ? 201 : 200).json({
            conteo: mapConteo(await conteoRef.get()), message: created ? 'Conteo guardado.' : 'El conteo ya estaba guardado.',
        });
    } catch (error) { return respondError(res, error); }
}

async function listarConteos(req, res) {
    try {
        const limit = integer(req.query.limit ?? 30, 'Limite', 1, 50);
        const result = await listOwnedMerged(
            req.user.uid, getRefs(req.user.uid), 'Conteos', 'fecha_hora_inicio', req.query.cursor, limit,
        );
        logGanadero(req, 'conteos:list', { total: result.docs.length, hasMore: Boolean(result.next_cursor) });
        return res.json({ conteos: result.docs.map(mapConteo), next_cursor: result.next_cursor });
    } catch (error) { return respondError(res, error); }
}

async function obtenerConteoDetalle(req, res) {
    try {
        const result = await getOwnedDoc(req.user.uid, getRefs(req.user.uid), 'Conteos', documentId(req.params.id));
        if (!result.exists) throw new HttpError(404, 'Conteo no encontrado.');
        return res.json({ conteo: mapConteo(result) });
    } catch (error) { return respondError(res, error); }
}

async function listarAlertas(req, res) {
    try {
        const limit = integer(req.query.limit ?? 30, 'Limite', 1, 50);
        const result = await listOwnedMerged(
            req.user.uid, getRefs(req.user.uid), 'Alertas', 'fecha_hora', req.query.cursor, limit,
        );
        logGanadero(req, 'alertas:list', { total: result.docs.length, hasMore: Boolean(result.next_cursor) });
        return res.json({ alertas: result.docs.map(mapAlerta), next_cursor: result.next_cursor });
    } catch (error) { return respondError(res, error); }
}

async function marcarAlertaLeida(req, res) {
    try {
        // Puede ser una alerta de la subcoleccion actual o de la coleccion
        // heredada; getOwnedDoc comprueba la propiedad en ambos casos.
        const found = await getOwnedDoc(
            req.user.uid, getRefs(req.user.uid), 'Alertas', documentId(req.params.id),
        );
        if (!found.exists) throw new HttpError(404, 'Alerta no encontrada.');
        await found.ref.update({ leida: true });
        return res.json({ alerta: mapAlerta(await found.ref.get()) });
    } catch (error) { return respondError(res, error); }
}

async function emitirComando(req, res) {
    try {
        const result = await iot.issue(req.user.uid, req.body);
        return res.json({ frame: result.frame, request_id: result.request_id, session_id: result.session_id, command: result.command });
    } catch (error) { return respondError(res, error); }
}

async function verificarRespuesta(req, res) {
    try { return res.json(await iot.verify(req.user.uid, object(req.body).frame)); }
    catch (error) { return respondError(res, error); }
}

module.exports = { obtenerDashboard, obtenerConfiguracion, guardarConfiguracion, obtenerDispositivo, registrarConteoReal, listarConteos, obtenerConteoDetalle, listarAlertas, marcarAlertaLeida, emitirComando, verificarRespuesta };
