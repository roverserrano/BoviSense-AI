const { db, FieldValue } = require('../config/firebaseAdmin');

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
        modo_operacion: (data.modo_operacion || 'simulacion').toString(),
    };
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
        origen: (data.origen || 'simulacion').toString(),
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

async function ensureDispositivo(uid) {
    const { deviceRef } = getRefs(uid);
    const current = await deviceRef.get();

    if (current.exists) {
        return mapDispositivo(current);
    }

    await deviceRef.set({
        nombre_dispositivo: 'Prototipo Bobisense',
        tipo_dispositivo: 'ESP32 + LoRa',
        estado_conexion: 'conectado',
        ultima_sincronizacion: FieldValue.serverTimestamp(),
        version_modelo: 'v1.0.0',
        estado_operativo: 'disponible',
        nivel_bateria: 0.95,
        coordenadas_gps: '',
        modo_operacion: 'simulacion',
    });

    const created = await deviceRef.get();
    return mapDispositivo(created);
}

function validarConfiguracion(body) {
    const nombreFinca = (body.nombre_finca || body.nombreFinca || '').toString().trim();
    const cantidadEsperada = toInt(body.cantidad_esperada ?? body.cantidadEsperada);

    if (!nombreFinca) {
        throw new Error('El nombre de la finca es obligatorio.');
    }

    if (!Number.isInteger(cantidadEsperada) || cantidadEsperada <= 0) {
        throw new Error('La cantidad esperada debe ser un número mayor a cero.');
    }

    return {
        nombre_finca: nombreFinca,
        cantidad_esperada: cantidadEsperada,
    };
}

function calcularDiferencia(cantidadEsperada, cantidadDetectada) {
    return cantidadDetectada - cantidadEsperada;
}

function generarCantidadDetectada(cantidadEsperada) {
    const margen = Math.max(1, Math.round(cantidadEsperada * 0.08));
    const variacion = Math.floor(Math.random() * ((margen * 2) + 1)) - margen;
    return Math.max(0, cantidadEsperada + variacion);
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
        const uid = req.user.uid;
        const refs = getRefs(uid);

        const [
            configuracionSnap,
            dispositivoData,
            conteosCountSnap,
            alertasPendientesSnap,
            conteosRecientesSnap,
            alertasRecientesSnap,
        ] = await Promise.all([
            refs.configRef.get(),
            ensureDispositivo(uid),
            refs.conteosRef.get(),
            refs.alertasRef.where('leida', '==', false).get(),
            refs.conteosRef.orderBy('fecha_hora_inicio', 'desc').limit(5).get(),
            refs.alertasRef.orderBy('fecha_hora', 'desc').limit(5).get(),
        ]);

        const configuracion = mapConfiguracion(configuracionSnap);
        const conteosRecientes = conteosRecientesSnap.docs.map(mapConteo);
        const alertasRecientes = alertasRecientesSnap.docs.map(mapAlerta);
        const ultimoConteo = conteosRecientes.length > 0 ? conteosRecientes[0] : null;

        return res.status(200).json({
            configuracion,
            dispositivo: dispositivoData,
            conteos_recientes: conteosRecientes,
            alertas_recientes: alertasRecientes,
            ultimo_conteo: ultimoConteo,
            cantidad_conteos: conteosCountSnap.size,
            alertas_pendientes: alertasPendientesSnap.size,
            ultima_diferencia: ultimoConteo ? ultimoConteo.diferencia : 0,
        });
    } catch (error) {
        console.error('Error obteniendo dashboard del ganadero:', error);
        return res.status(500).json({
            message: error.message || 'No se pudo obtener el dashboard.',
        });
    }
}

async function obtenerConfiguracion(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        const snapshot = await refs.configRef.get();

        return res.status(200).json({
            configuracion: mapConfiguracion(snapshot),
        });
    } catch (error) {
        return res.status(500).json({
            message: error.message || 'No se pudo obtener la configuración.',
        });
    }
}

async function guardarConfiguracion(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        const payload = validarConfiguracion(req.body);

        await refs.configRef.set(
            {
                ...payload,
                fecha_actualizacion: FieldValue.serverTimestamp(),
            },
            { merge: true },
        );

        await ensureDispositivo(req.user.uid);

        const saved = await refs.configRef.get();

        return res.status(200).json({
            message: 'Configuración guardada correctamente.',
            configuracion: mapConfiguracion(saved),
        });
    } catch (error) {
        return res.status(400).json({
            message: error.message || 'No se pudo guardar la configuración.',
        });
    }
}

async function obtenerDispositivo(req, res) {
    try {
        const dispositivo = await ensureDispositivo(req.user.uid);

        return res.status(200).json({
            dispositivo,
        });
    } catch (error) {
        return res.status(500).json({
            message: error.message || 'No se pudo obtener el estado del dispositivo.',
        });
    }
}

async function iniciarConteo(req, res) {
    try {
        const uid = req.user.uid;
        const refs = getRefs(uid);

        const [configSnap, dispositivo] = await Promise.all([
            refs.configRef.get(),
            ensureDispositivo(uid),
        ]);

        if (!configSnap.exists) {
            return res.status(400).json({
                message: 'Debes configurar el sistema antes de iniciar un conteo.',
            });
        }

        if (
            dispositivo.estado_conexion === 'desconectado' &&
            dispositivo.modo_operacion !== 'simulacion'
        ) {
            return res.status(400).json({
                message: 'El prototipo no está conectado.',
            });
        }

        const configuracion = mapConfiguracion(configSnap);
        const cantidadDetectada = generarCantidadDetectada(configuracion.cantidad_esperada);
        const diferencia = calcularDiferencia(
            configuracion.cantidad_esperada,
            cantidadDetectada,
        );

        const now = new Date();
        const conteoRef = refs.conteosRef.doc();
        const alertData = buildAlertData(diferencia);
        const alertRef = alertData ? refs.alertasRef.doc() : null;
        const batch = db.batch();

        batch.set(conteoRef, {
            fecha_hora_inicio: now,
            fecha_hora_fin: now,
            cantidad_detectada: cantidadDetectada,
            cantidad_esperada: configuracion.cantidad_esperada,
            diferencia,
            estado_conteo: 'finalizado',
            origen: dispositivo.modo_operacion,
            resumen: buildResumen(
                cantidadDetectada,
                configuracion.cantidad_esperada,
                diferencia,
            ),
        });

        batch.set(
            refs.deviceRef,
            {
                ultima_sincronizacion: FieldValue.serverTimestamp(),
                estado_conexion: 'conectado',
                estado_operativo: 'disponible',
                nivel_bateria: Math.max(
                    0.10,
                    Number((dispositivo.nivel_bateria - 0.01).toFixed(2)),
                ),
            },
            { merge: true },
        );

        if (alertRef && alertData) {
            batch.set(alertRef, alertData);
        }

        await batch.commit();

        const createdConteo = await conteoRef.get();
        const createdAlert = alertRef ? await alertRef.get() : null;

        return res.status(201).json({
            message: 'Conteo realizado correctamente.',
            conteo: mapConteo(createdConteo),
            alerta: createdAlert ? mapAlerta(createdAlert) : null,
        });
    } catch (error) {
        console.error('Error iniciando conteo:', error);
        return res.status(500).json({
            message: error.message || 'No se pudo iniciar el conteo.',
        });
    }
}

async function listarConteos(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        const snapshot = await refs.conteosRef.orderBy('fecha_hora_inicio', 'desc').get();

        return res.status(200).json({
            conteos: snapshot.docs.map(mapConteo),
        });
    } catch (error) {
        return res.status(500).json({
            message: error.message || 'No se pudo obtener el historial de conteos.',
        });
    }
}

async function obtenerConteoDetalle(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        const snapshot = await refs.conteosRef.doc(req.params.id).get();

        if (!snapshot.exists) {
            return res.status(404).json({
                message: 'Conteo no encontrado.',
            });
        }

        return res.status(200).json({
            conteo: mapConteo(snapshot),
        });
    } catch (error) {
        return res.status(500).json({
            message: error.message || 'No se pudo obtener el detalle del conteo.',
        });
    }
}

async function listarAlertas(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        const snapshot = await refs.alertasRef.orderBy('fecha_hora', 'desc').limit(30).get();

        return res.status(200).json({
            alertas: snapshot.docs.map(mapAlerta),
        });
    } catch (error) {
        return res.status(500).json({
            message: error.message || 'No se pudieron obtener las alertas.',
        });
    }
}

async function marcarAlertaLeida(req, res) {
    try {
        const refs = getRefs(req.user.uid);
        const alertaRef = refs.alertasRef.doc(req.params.id);
        const alertaSnap = await alertaRef.get();

        if (!alertaSnap.exists) {
            return res.status(404).json({
                message: 'Alerta no encontrada.',
            });
        }

        await alertaRef.set(
            {
                leida: true,
            },
            { merge: true },
        );

        const updated = await alertaRef.get();

        return res.status(200).json({
            message: 'Alerta actualizada correctamente.',
            alerta: mapAlerta(updated),
        });
    } catch (error) {
        return res.status(500).json({
            message: error.message || 'No se pudo actualizar la alerta.',
        });
    }
}

module.exports = {
    obtenerDashboard,
    obtenerConfiguracion,
    guardarConfiguracion,
    obtenerDispositivo,
    iniciarConteo,
    listarConteos,
    obtenerConteoDetalle,
    listarAlertas,
    marcarAlertaLeida,
};