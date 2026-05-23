const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();



// Configuración Resend
// firebase functions:config:set resend.apikey="re_xxx" resend.from="onboarding@resend.dev"
function getResendConfig() {
  const config = functions.config().resend || {};
  return {
    apiKey: config.apikey || '',
    from: config.from || '',
  };
}

async function obtenerDatosCita(citaId) {
  const citaSnap = await admin.firestore().collection('citas').doc(citaId).get();
  if (!citaSnap.exists) throw new Error('Cita no encontrada');
  const cita = citaSnap.data();

  const sedeSnap = await admin.firestore().collection('sedes').doc(cita.sedeId).get();
  const sede = sedeSnap.data() || { nombre: 'Sede', direccion: '' };

  const pacienteSnap = await admin.firestore().collection('pacientes').doc(cita.pacienteId).get();
  const paciente = pacienteSnap.data() || { nombres: 'Paciente', email: '' };

  return { cita, sede, paciente };
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

function plantillaEmail({ titulo, nombrePaciente, fechaFormateada, hora, sede, mensajePersonalizado, esCancelacion, esReagendamiento }) {
  const contacto = SEDES_CONTACTO[sede.id] || {};
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
            Llama o escríbenos al Whatsapp <strong>315 342 5703</strong>
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
  if (!to) {
    functions.logger.warn(`Sin destinatario para cita ${citaId}`);
    return null;
  }

  const { apiKey, from } = getResendConfig();
  if (!apiKey || !from) {
    functions.logger.warn('Resend no configurado: faltan apiKey o from');
    return null;
  }

  const respuesta = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from, to: [to], subject, html }),
  });

  if (!respuesta.ok) {
    const texto = await respuesta.text();
    throw new Error(`Resend error ${respuesta.status}: ${texto}`);
  }

  return respuesta.json();
}

// ─── CONFIRMACIÓN ────────────────────────────────────────
exports.enviarConfirmacion = functions.firestore
  .document('citas/{citaId}')
  .onCreate(async (snap, context) => {
    try {
      const { cita, sede, paciente } = await Promise.race([
        obtenerDatosCita(context.params.citaId),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout obteniendo datos')), 25000)),
      ]);
      const fechaFormateada = formatearFecha(cita.fecha);
      const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');

      const html = plantillaEmail({
        titulo: 'Cita Agendada',
        nombrePaciente,
        fechaFormateada,
        hora: cita.hora,
        sede,
        mensajePersonalizado: cita.mensajePersonalizado,
        esCancelacion: false,
      });

      // Solo intentar email si hay destinatario
      if (paciente.email) {
        try {
          await Promise.race([
            enviarCorreo({
              to: paciente.email,
              subject: `Cita confirmada - ${sede.nombre} - ${formatoHora12h(cita.hora)}`,
              html,
              citaId: context.params.citaId,
            }),
            new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout email')), 15000)),
          ]);
          functions.logger.log(`Confirmación enviada a ${paciente.email}`);
        } catch (err) {
          functions.logger.error('Error enviando confirmación:', err);
        }
      } else {
        functions.logger.warn(`Sin email para cita ${context.params.citaId}`);
      }

      // Enviar notificación push al profesional
      try {
        const nombrePaciente = (paciente.nombres || 'Paciente').split(' ').slice(0, 2).join(' ');
        await Promise.race([
          admin.messaging().send({
            topic: 'profesional_notificaciones',
            notification: {
              title: 'Nueva cita agendada',
              body: `${nombrePaciente} - ${sede.nombre} - ${cita.fecha} ${cita.hora}`,
            },
            data: {
              tipo: 'nueva_cita',
              citaId: context.params.citaId,
            },
          }),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout push')), 15000)),
        ]);
        functions.logger.log('Push enviado al profesional');
      } catch (err) {
        functions.logger.error('Error enviando push:', err);
      }

      // Marcar como notificada
      try {
        await Promise.race([
          snap.ref.update({ notificada: true }),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout update')), 10000)),
        ]);
      } catch (err) {
        functions.logger.error('Error actualizando notificada:', err);
      }
    } catch (err) {
      functions.logger.error('Error en enviarConfirmacion:', err);
    }
  });

// ─── RECORDATORIO ─────────────────────────────────────────
// Programar con Cloud Scheduler: todos los días a las 8:00 AM
// Endpoint: https://us-central1-agendavisso.cloudfunctions.net/enviarRecordatorios
exports.enviarRecordatorios = functions.https.onRequest(async (req, res) => {
  const manana = new Date();
  manana.setDate(manana.getDate() + 1);
  const mananaStr = manana.toISOString().split('T')[0];

  const snapshot = await admin.firestore().collection('citas')
    .where('fecha', '==', mananaStr)
    .where('estado', 'in', ['pendiente', 'confirmada'])
    .get();

  let enviados = 0;
  for (const doc of snapshot.docs) {
    const cita = doc.data();
    const sedeSnap = await admin.firestore().collection('sedes').doc(cita.sedeId).get();
    const sede = sedeSnap.data() || { nombre: 'Sede', direccion: '' };
    const pacienteSnap = await admin.firestore().collection('pacientes').doc(cita.pacienteId).get();
    const paciente = pacienteSnap.data() || { nombres: 'Paciente', email: '' };

    if (!paciente.email) continue;

    const fechaFormateada = formatearFecha(cita.fecha);
    const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');

    const html = plantillaEmail({
      titulo: 'Recordatorio de Cita',
      nombrePaciente,
      fechaFormateada,
      hora: cita.hora,
      sede,
      mensajePersonalizado: 'Por favor llega 10 minutos antes de tu hora agendada.',
      esCancelacion: false,
    });

    try {
      await enviarCorreo({
        to: paciente.email,
        subject: `Recordatorio: tienes cita mañana ${cita.hora} hs`,
        html,
        citaId: doc.id,
      });
      enviados++;
    } catch (err) {
      functions.logger.error('Error enviando recordatorio:', err);
    }
  }

  res.status(200).send(`Recordatorios enviados: ${enviados}`);
});

// ─── RE-AGENDAMIENTO / CANCELACIÓN ────────────────────────
exports.enviarReagendamiento = functions.firestore
  .document('citas/{citaId}')
  .onUpdate(async (change, context) => {
    const antes = change.before.data();
    const despues = change.after.data();

    // Cancelación
    if (antes.estado !== 'cancelada' && despues.estado === 'cancelada') {
      const { cita, sede, paciente } = await obtenerDatosCita(context.params.citaId);
      if (!paciente.email) return;
      const fechaFormateada = formatearFecha(cita.fecha);
      const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');
      const html = plantillaEmail({
        titulo: 'Cita Cancelada', nombrePaciente, fechaFormateada, hora: cita.hora, sede,
        esCancelacion: true,
      });
      try {
        await enviarCorreo({
          to: paciente.email, subject: `Cita cancelada - Reagenda cuando quieras`, html, citaId: context.params.citaId,
        });
        functions.logger.log(`Cancelación enviada a ${paciente.email}`);
      } catch (err) {
        functions.logger.error('Error enviando cancelación:', err);
      }
      return;
    }

    // Reagendamiento (cambio de fecha u hora en cita no cancelada)
    const fechaCambio = antes.fecha !== despues.fecha || antes.hora !== despues.hora;
    if (fechaCambio && despues.estado !== 'cancelada') {
      const { cita, sede, paciente } = await obtenerDatosCita(context.params.citaId);
      if (!paciente.email) return;
      const fechaFormateada = formatearFecha(cita.fecha);
      const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');
      const html = plantillaEmail({
        titulo: 'Cita Reagendada', nombrePaciente, fechaFormateada, hora: cita.hora, sede,
        esReagendamiento: true,
      });
      try {
        await enviarCorreo({
          to: paciente.email, subject: `Tu cita ha sido reagendada - ${sede.nombre} - ${formatoHora12h(cita.hora)}`, html, citaId: context.params.citaId,
        });
        functions.logger.log(`Reagendamiento enviado a ${paciente.email}`);
      } catch (err) {
        functions.logger.error('Error enviando reagendamiento:', err);
      }
    }
  });
