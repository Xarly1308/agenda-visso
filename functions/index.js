const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getMessaging } = require('firebase-admin/messaging');
const { defineString } = require('firebase-functions/params');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

initializeApp();
const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();

const resendApiKey = defineString('RESEND_API_KEY');
const resendFrom = defineString('RESEND_FROM');

async function obtenerDatosCita(citaId) {
  const citaSnap = await db.collection('citas').doc(citaId).get();
  if (!citaSnap.exists) throw new Error('Cita no encontrada');
  const cita = citaSnap.data();

  const sedeSnap = await db.collection('sedes').doc(cita.sedeId).get();
  const sede = sedeSnap.data() || { nombre: 'Sede', direccion: '' };

  const pacienteSnap = await db.collection('pacientes').doc(cita.pacienteId).get();
  const paciente = pacienteSnap.data() || { nombres: 'Paciente', email: '' };

  let franquicia = null;
  if (cita.franquiciaId) {
    const franquiciaSnap = await db.collection('franquicias').doc(cita.franquiciaId).get();
    franquicia = franquiciaSnap.data() || null;
  }

  return { cita, sede, paciente, franquicia };
}

function formatearFecha(fechaStr) {
  const [y, m, d] = fechaStr.split('-');
  const fecha = new Date(parseInt(y), parseInt(m) - 1, parseInt(d));
  const opciones = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
  return fecha.toLocaleDateString('es-ES', opciones);
}

const SEDES_CONTACTO = {
  'acropolis-visso': {
    telefono: '315 342 5703',
    direccion: 'Cra 45 #24-26, Barrio Quintaparedes, Bogotá D.C.',
  },
  'visso-funza': {
    telefono: '(601) 823-7298 - 315 342 5703',
    direccion: 'Cra 13 #16-85, C.C Micentro Funza. Funza, Cundinamarca',
  },
};

const LOGO_URL = 'https://raw.githubusercontent.com/Xarly1308/agenda-visso/main/agenda_visso_paciente/assets/logo-visso-white-tr.png';

function formatoHora12h(hora24) {
  const [h, m] = hora24.split(':').map(Number);
  const periodo = h >= 12 ? 'PM' : 'AM';
  const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h);
  return `${h12}:${m.toString().padStart(2, '0')} ${periodo}`;
}

function obtenerContacto(sede, franquicia) {
  const legacy = SEDES_CONTACTO[sede.id] || {};
  return {
    direccion: sede.direccion || (franquicia && franquicia.direccion) || legacy.direccion || '',
    telefono: sede.telefono || (franquicia && franquicia.telefonoContacto) || legacy.telefono || '',
    whatsapp: (franquicia && franquicia.telefonoContacto) || legacy.telefono || '315 342 5703',
  };
}

function plantillaEmail({ titulo, nombrePaciente, fechaFormateada, hora, sede, contacto, mensajePersonalizado, esCancelacion, esReagendamiento }) {
  const horaFormateada = formatoHora12h(hora);
  return `
  <!DOCTYPE html>
  <html>
  <head><meta charset="utf-8"></head>
  <body style="margin:0;padding:0;font-family:Arial,Helvetica,sans-serif;background:#f5f5f5;">
    <table role="presentation" style="width:100%;max-width:600px;margin:0 auto;background:white;border-radius:12px;overflow:hidden;">
      <tr>
        <td style="background:#2a4379;padding:24px 30px;text-align:center;">
          <img src="${LOGO_URL}" alt="Visso" style="height:52px;" />
          <h1 style="color:white;margin:12px 0 0;font-size:22px;">${titulo}</h1>
        </td>
      </tr>
      <tr>
        <td style="padding:30px;">
          <p style="font-size:16px;margin:0 0 16px;">Hola <strong>${nombrePaciente}</strong>,</p>
          <p style="font-size:16px;margin:0 0 20px;">
            ${esCancelacion ? 'Tu cita ha sido cancelada.' : esReagendamiento ? 'Tu cita ha sido reagendada:' : 'Tu cita ha sido agendada exitosamente:'}
          </p>
          <table role="presentation" style="width:100%;background:#e0f2f1;border-radius:8px;padding:20px;margin:0 0 20px;">
            <tr><td style="padding:4px 0;"><strong>Fecha:</strong> ${fechaFormateada}</td></tr>
            <tr><td style="padding:4px 0;"><strong>Hora:</strong> ${horaFormateada}</td></tr>
            <tr><td style="padding:4px 0;"><strong>Sede:</strong> ${sede.nombre}</td></tr>
            <tr><td style="padding:4px 0;"><strong>Dirección:</strong> ${contacto.direccion || sede.direccion}</td></tr>
            <tr><td style="padding:4px 0;"><strong>Teléfono:</strong> ${contacto.telefono || ''}</td></tr>
          </table>
          ${mensajePersonalizado ? `<p style="font-style:italic;color:#666;margin:0 0 16px;">${mensajePersonalizado}</p>` : ''}
          ${!esCancelacion ? `
          <hr style="border:none;border-top:1px solid #ddd;margin:20px 0;" />
          <p style="font-size:14px;color:#666;margin:0;">
            <strong>¿Necesitas cancelar o reagendar?</strong><br/>
            Llama o escríbenos al Whatsapp <strong>${contacto.whatsapp}</strong>
          </p>
          ` : ''}
          <p style="font-size:12px;color:#999;margin-top:24px;text-align:center;">
            Visso Optometría — ${sede.nombre}
          </p>
        </td>
      </tr>
    </table>
  </body>
  </html>`;
}

async function enviarCorreo({ to, subject, html, citaId }) {
  logger.info(`Email deshabilitado: skip envío a ${to} para cita ${citaId}`);
  return null;
}

// ─── CONFIRMACIÓN ────────────────────────────────────────
exports.enviarConfirmacion = onDocumentCreated('citas/{citaId}', async (event) => {
  const snap = event.data;
  const citaId = event.params.citaId;
  try {
    const { cita, sede, paciente, franquicia } = await Promise.race([
      obtenerDatosCita(citaId),
      new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout obteniendo datos')), 25000)),
    ]);
    const fechaFormateada = formatearFecha(cita.fecha);
    const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');
    const contacto = obtenerContacto(sede, franquicia);

    const html = plantillaEmail({
      titulo: 'Cita Agendada',
      nombrePaciente,
      fechaFormateada,
      hora: cita.hora,
      sede,
      contacto,
      mensajePersonalizado: cita.mensajePersonalizado,
      esCancelacion: false,
    });

    if (paciente.email) {
      try {
        await Promise.race([
          enviarCorreo({ to: paciente.email, subject: `Cita confirmada - ${sede.nombre} - ${formatoHora12h(cita.hora)}`, html, citaId }),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout email')), 15000)),
        ]);
        logger.log(`Confirmación enviada a ${paciente.email}`);
      } catch (err) {
        logger.error('Error enviando confirmación:', err);
      }
    } else {
      logger.warn(`Sin email para cita ${citaId}`);
    }

    try {
      const nombrePaciente = (paciente.nombres || 'Paciente').split(' ').slice(0, 2).join(' ');
      const franquiciaId = cita.franquiciaId || '1000';
      await Promise.race([
        messaging.send({
          topic: `profesional_notificaciones_${franquiciaId}`,
          notification: { title: 'Nueva cita agendada', body: `${nombrePaciente} - ${sede.nombre} - ${cita.fecha} ${cita.hora}` },
          android: {
            notification: {
              channelId: 'nuevas_citas',
              clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
          data: { tipo: 'nueva_cita', citaId, franquiciaId },
        }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout push')), 15000)),
      ]);
      logger.log(`Push enviado al profesional (franquicia ${franquiciaId})`);
    } catch (err) {
      logger.error('Error enviando push:', err);
    }

    try {
      await Promise.race([
        snap.ref.update({ notificada: true }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout update')), 10000)),
      ]);
    } catch (err) {
      logger.error('Error actualizando notificada:', err);
    }
  } catch (err) {
    logger.error('Error en enviarConfirmacion:', err);
  }
});

// ─── RECORDATORIO ─────────────────────────────────────────
exports.enviarRecordatorios = onRequest(async (req, res) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return res.status(405).send('Method not allowed');
  }

  const manana = new Date();
  manana.setDate(manana.getDate() + 1);
  const mananaStr = manana.toISOString().split('T')[0];

  logger.log(`Enviando recordatorios para mañana ${mananaStr}...`);

  const snapshot = await db.collection('citas')
    .where('fecha', '==', mananaStr)
    .where('estado', 'in', ['pendiente', 'confirmada'])
    .get();

  let enviados = 0;
  let total = 0;
  for (const doc of snapshot.docs) {
    total++;
    const cita = doc.data();
    const [sedeSnap, pacienteSnap] = await Promise.all([
      db.collection('sedes').doc(cita.sedeId).get(),
      db.collection('pacientes').doc(cita.pacienteId).get(),
    ]);
    const sede = sedeSnap.data() || { nombre: 'Sede', direccion: '' };
    const paciente = pacienteSnap.data() || { nombres: 'Paciente', email: '' };
    let franquicia = null;
    if (cita.franquiciaId) {
      const franquiciaSnap = await db.collection('franquicias').doc(cita.franquiciaId).get();
      franquicia = franquiciaSnap.data() || null;
    }

    if (!paciente.email) continue;

    const fechaFormateada = formatearFecha(cita.fecha);
    const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');
    const contacto = obtenerContacto(sede, franquicia);

    const html = plantillaEmail({
      titulo: 'Recordatorio de Cita',
      nombrePaciente,
      fechaFormateada,
      hora: cita.hora,
      sede,
      contacto,
      mensajePersonalizado: 'Por favor llega 10 minutos antes de tu hora agendada.',
      esCancelacion: false,
    });

    try {
      await enviarCorreo({ to: paciente.email, subject: `Recordatorio: tienes cita mañana ${formatoHora12h(cita.hora)}`, html, citaId: doc.id });
      enviados++;
    } catch (err) {
      logger.error('Error enviando recordatorio a ${paciente.email}:', err);
    }
  }

  logger.log(`Recordatorios: ${enviados} enviados de ${total} citas para mañana`);
  res.status(200).send(`Recordatorios enviados: ${enviados} de ${total}`);
});

// ─── RE-AGENDAMIENTO / CANCELACIÓN ────────────────────────
exports.enviarReagendamiento = onDocumentUpdated('citas/{citaId}', async (event) => {
  const change = event.data;
  const citaId = event.params.citaId;
  const antes = change.before.data();
  const despues = change.after.data();

  // Cancelación
  if (antes.estado !== 'cancelada' && despues.estado === 'cancelada') {
    const { cita, sede, paciente, franquicia } = await obtenerDatosCita(citaId);

    try {
      const nombrePaciente = (paciente.nombres || 'Paciente').split(' ').slice(0, 2).join(' ');
      const franquiciaId = cita.franquiciaId || '1000';
      await messaging.send({
        topic: `profesional_notificaciones_${franquiciaId}`,
        notification: { title: 'Cita cancelada', body: `${nombrePaciente} - ${sede.nombre} - ${cita.fecha} ${cita.hora}` },
        android: {
          notification: {
            channelId: 'nuevas_citas',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        data: { tipo: 'cita_cancelada', citaId, franquiciaId },
      });
      logger.log(`Push cancelación enviado (franquicia ${franquiciaId})`);
    } catch (err) {
      logger.error('Error push cancelación:', err);
    }

    if (!paciente.email) return;
    const fechaFormateada = formatearFecha(cita.fecha);
    const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');
    const contacto = obtenerContacto(sede, franquicia);
    const html = plantillaEmail({
      titulo: 'Cita Cancelada', nombrePaciente, fechaFormateada, hora: cita.hora, sede, contacto,
      esCancelacion: true,
    });
    try {
      await enviarCorreo({ to: paciente.email, subject: `Cita cancelada - Reagenda cuando quieras`, html, citaId });
      logger.log(`Cancelación enviada a ${paciente.email}`);
    } catch (err) {
      logger.error('Error enviando cancelación:', err);
    }
    return;
  }

  // Reagendamiento (cambio de fecha u hora en cita no cancelada)
  const fechaCambio = antes.fecha !== despues.fecha || antes.hora !== despues.hora;
  if (fechaCambio && despues.estado !== 'cancelada') {
    const { cita, sede, paciente, franquicia } = await obtenerDatosCita(citaId);

    try {
      const nombrePaciente = (paciente.nombres || 'Paciente').split(' ').slice(0, 2).join(' ');
      const franquiciaId = cita.franquiciaId || '1000';
      await messaging.send({
        topic: `profesional_notificaciones_${franquiciaId}`,
        notification: { title: `Cita reagendada`, body: `${nombrePaciente} - ${sede.nombre} - ${cita.fecha} ${cita.hora}` },
        android: {
          notification: {
            channelId: 'nuevas_citas',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        data: { tipo: 'cita_reagendada', citaId, franquiciaId },
      });
      logger.log(`Push reagendamiento enviado (franquicia ${franquiciaId})`);
    } catch (err) {
      logger.error('Error push reagendamiento:', err);
    }

    if (!paciente.email) return;
    const fechaFormateada = formatearFecha(cita.fecha);
    const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');
    const contacto = obtenerContacto(sede, franquicia);
    const html = plantillaEmail({
      titulo: 'Cita Reagendada', nombrePaciente, fechaFormateada, hora: cita.hora, sede, contacto,
      esReagendamiento: true,
    });
    try {
      await enviarCorreo({ to: paciente.email, subject: `Tu cita ha sido reagendada - ${sede.nombre} - ${formatoHora12h(cita.hora)}`, html, citaId });
      logger.log(`Reagendamiento enviado a ${paciente.email}`);
    } catch (err) {
      logger.error('Error enviando reagendamiento:', err);
    }
  }
});

// ─── ADMIN (onCall protegidas por desarrolladores) ──────────
async function requerirDesarrollador(auth) {
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión');
  }
  const snap = await db.collection('desarrolladores').doc(auth.uid).get();
  if (!snap.exists || snap.data().activo === false) {
    throw new HttpsError('permission-denied', 'Solo desarrolladores pueden realizar esta acción');
  }
  return snap.data();
}

exports.crearFranquicia = onCall(async (request) => {
  await requerirDesarrollador(request.auth);

  const data = request.data || {};
  const codigo = data.codigo ? String(data.codigo).trim() : '';
  const nombre = data.nombre ? String(data.nombre).trim() : '';
  if (!codigo || !nombre) {
    throw new HttpsError('invalid-argument', 'codigo y nombre son obligatorios');
  }

  const ref = db.collection('franquicias').doc(codigo);
  const actual = await ref.get();
  if (actual.exists) {
    throw new HttpsError('already-exists', `La franquicia ${codigo} ya existe`);
  }

  const direccion = data.direccion || '';
  const telefono = data.telefonoContacto || '';

  // 1. Crear franquicia
  await ref.set({
    codigo,
    nombre,
    activo: true,
    direccion,
    telefonoContacto: telefono,
    usuarios: [],
    creadoEn: FieldValue.serverTimestamp(),
  });

  // 2. Crear sede por defecto con los mismos datos de la franquicia
  const sedeId = db.collection('sedes').doc().id;
  const iconos = ['store', 'medical_services', 'visibility', 'local_hospital', 'home', 'business', 'location_city', 'apartment'];
  const iconoAleatorio = iconos[Math.floor(Math.random() * iconos.length)];
  await db.collection('sedes').doc(sedeId).set({
    id: sedeId,
    nombre,
    direccion,
    telefono: telefono || null,
    activa: true,
    icono: iconoAleatorio,
    franquiciaId: codigo,
    creadoEn: FieldValue.serverTimestamp(),
  });

  // 3. Crear tipos de consulta por defecto
  const defaultTipos = [
    'Control', 'Lentes oftálmicos', 'Lentes de contacto',
    'Pediátrico', 'Patología', 'Ortóptica', 'Certificado',
  ];
  for (const nombreTipo of defaultTipos) {
    const tipoId = db.collection('tipos_consulta').doc().id;
    await db.collection('tipos_consulta').doc(tipoId).set({
      id: tipoId,
      nombre: nombreTipo,
      activo: true,
      franquiciaId: codigo,
      creadoEn: FieldValue.serverTimestamp(),
    });
  }

  // 4. Crear horarios por defecto para la sede (L-V 8-12, 14-18 / Sáb 8-12)
  const horariosDefault = [];
  for (let dia = 1; dia <= 5; dia++) {
    horariosDefault.push(
      { diaSemana: dia, horaInicio: '08:00', horaFin: '12:00' },
      { diaSemana: dia, horaInicio: '14:00', horaFin: '18:00' },
    );
  }
  horariosDefault.push({ diaSemana: 6, horaInicio: '08:00', horaFin: '12:00' });

  for (const h of horariosDefault) {
    const horarioId = db.collection('horarios').doc().id;
    await db.collection('horarios').doc(horarioId).set({
      id: horarioId,
      profesionalId: '',
      sedeId,
      diaSemana: h.diaSemana,
      horaInicio: h.horaInicio,
      horaFin: h.horaFin,
      franquiciaId: codigo,
      creadoEn: FieldValue.serverTimestamp(),
    });
  }

  return { ok: true, franquiciaId: codigo, sedeId };
});

exports.crearProfesional = onCall(async (request) => {
  await requerirDesarrollador(request.auth);

  const data = request.data || {};
  const email = data.email ? String(data.email).trim() : '';
  const password = data.password ? String(data.password).trim() : '';
  const nombre = data.nombre ? String(data.nombre).trim() : '';
  const documento = data.documento ? String(data.documento).trim() : '';
  const franquiciaId = data.franquiciaId ? String(data.franquiciaId).trim() : '';
  if (!email || !password || !nombre || !franquiciaId) {
    throw new HttpsError('invalid-argument', 'email, password, nombre y franquiciaId son obligatorios');
  }
  if (password.length < 6) {
    throw new HttpsError('invalid-argument', 'La contraseña debe tener al menos 6 caracteres');
  }

  const franquiciaRef = db.collection('franquicias').doc(franquiciaId);
  const franquiciaSnap = await franquiciaRef.get();
  if (!franquiciaSnap.exists) {
    throw new HttpsError('not-found', `La franquicia ${franquiciaId} no existe`);
  }

  try {
    await auth.getUserByEmail(email);
    throw new HttpsError('already-exists', `Ya existe una cuenta con el email ${email}`);
  } catch (e) {
    if (e instanceof HttpsError) throw e;
  }

  const userRecord = await auth.createUser({ email, password, displayName: nombre });

  await db.collection('profesionales').doc(userRecord.uid).set({
    id: userRecord.uid, nombre, email, documento, activo: true, franquiciaId,
    creadoEn: FieldValue.serverTimestamp(),
  });

  await franquiciaRef.update({ usuarios: FieldValue.arrayUnion(userRecord.uid) });

  return { ok: true, uid: userRecord.uid, email, franquiciaId };
});

exports.asignarProfesionalAFranquicia = onCall(async (request) => {
  await requerirDesarrollador(request.auth);

  const data = request.data || {};
  const uid = data.uid ? String(data.uid).trim() : '';
  const franquiciaId = data.franquiciaId ? String(data.franquiciaId).trim() : '';
  if (!uid || !franquiciaId) {
    throw new HttpsError('invalid-argument', 'uid y franquiciaId son obligatorios');
  }

  const franquiciaRef = db.collection('franquicias').doc(franquiciaId);
  const franquiciaSnap = await franquiciaRef.get();
  if (!franquiciaSnap.exists) {
    throw new HttpsError('not-found', `La franquicia ${franquiciaId} no existe`);
  }

  const profesionalRef = db.collection('profesionales').doc(uid);
  const profesionalSnap = await profesionalRef.get();
  if (!profesionalSnap.exists) {
    throw new HttpsError('not-found', 'El profesional no existe en la colección profesionales');
  }

  await profesionalRef.update({ franquiciaId });
  await franquiciaRef.update({ usuarios: FieldValue.arrayUnion(uid) });

  return { ok: true, uid, franquiciaId };
});

exports.editarProfesional = onCall(async (request) => {
  await requerirDesarrollador(request.auth);

  const data = request.data || {};
  const uid = data.uid ? String(data.uid).trim() : '';
  if (!uid) throw new HttpsError('invalid-argument', 'uid es obligatorio');

  const profesionalRef = db.collection('profesionales').doc(uid);
  const profesionalSnap = await profesionalRef.get();
  if (!profesionalSnap.exists) {
    throw new HttpsError('not-found', 'El profesional no existe');
  }

  const updates = {};
  const authUpdates = {};

  if (data.nombre) {
    updates.nombre = String(data.nombre).trim();
    authUpdates.displayName = updates.nombre;
  }
  if (data.email) {
    const newEmail = String(data.email).trim();
    updates.email = newEmail;
    authUpdates.email = newEmail;
    try {
      const existing = await auth.getUserByEmail(newEmail);
      if (existing && existing.uid !== uid) {
        throw new HttpsError('already-exists', `El email ${newEmail} ya está en uso`);
      }
    } catch (e) {
      if (e instanceof HttpsError) throw e;
    }
  }
  if (data.password) {
    authUpdates.password = String(data.password).trim();
    if (authUpdates.password.length < 6) {
      throw new HttpsError('invalid-argument', 'La contraseña debe tener al menos 6 caracteres');
    }
  }
  if (data.documento !== undefined) updates.documento = String(data.documento).trim();
  if (data.franquiciaId) {
    const newFid = String(data.franquiciaId).trim();
    const oldFid = profesionalSnap.data().franquiciaId;
    updates.franquiciaId = newFid;
    if (oldFid && oldFid !== newFid) {
      const oldRef = db.collection('franquicias').doc(oldFid);
      const newRef = db.collection('franquicias').doc(newFid);
      await oldRef.update({ usuarios: FieldValue.arrayRemove(uid) }).catch(() => {});
      await newRef.update({ usuarios: FieldValue.arrayUnion(uid) }).catch(() => {});
    }
  }

  if (Object.keys(authUpdates).length > 0) {
    await auth.updateUser(uid, authUpdates);
  }
  if (Object.keys(updates).length > 0) {
    await profesionalRef.update(updates);
  }

  return { ok: true, uid };
});

exports.eliminarProfesional = onCall(async (request) => {
  try {
    await requerirDesarrollador(request.auth);

    const data = request.data || {};
    const uid = data.uid ? String(data.uid).trim() : '';
    if (!uid) throw new HttpsError('invalid-argument', 'uid es obligatorio');

    const profesionalSnap = await db.collection('profesionales').doc(uid).get();
    if (!profesionalSnap.exists) {
      throw new HttpsError('not-found', 'El profesional no existe');
    }

    const fid = profesionalSnap.data().franquiciaId;
    if (fid) {
      await db.collection('franquicias').doc(fid).update({
        usuarios: FieldValue.arrayRemove(uid),
      }).catch(() => {});
    }

    await db.collection('profesionales').doc(uid).delete();

    try {
      await auth.deleteUser(uid);
    } catch (e) {
      logger.warn('Auth user not found or already deleted', { uid, error: e.message });
    }

    return { ok: true, uid };
  } catch (err) {
    logger.error('Error en eliminarProfesional:', err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError('internal', err.message || 'Error interno al eliminar profesional');
  }
});

exports.sembrarTiposConsultaDefault = onCall(async (request) => {
  await requerirDesarrollador(request.auth);

  const data = request.data || {};
  const franquiciaId = data.franquiciaId ? String(data.franquiciaId).trim() : '';
  if (!franquiciaId) throw new HttpsError('invalid-argument', 'franquiciaId es obligatorio');

  const defaultTypes = [
    'Control', 'Lentes oftálmicos', 'Lentes de contacto',
    'Pediátrico', 'Patología', 'Ortóptica', 'Certificado',
  ];

  const snap = await db.collection('tipos_consulta')
    .where('franquiciaId', '==', franquiciaId).where('activo', '==', true).get();
  const existentes = new Set(snap.docs.map(d => d.data().nombre));

  let creados = 0;
  for (const nombre of defaultTypes) {
    if (existentes.has(nombre)) continue;
    const id = db.collection('tipos_consulta').doc().id;
    await db.collection('tipos_consulta').doc(id).set({
      id, nombre, activo: true, franquiciaId,
      creadoEn: FieldValue.serverTimestamp(),
    });
    creados++;
  }

  return { ok: true, creados, total: defaultTypes.length };
});
