const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configuración SMTP desde variables de entorno de Firebase
// Configurar con: firebase functions:config:set smtp.host="..." smtp.user="..." smtp.pass="..." smtp.from="..."
function getSMTPConfig() {
  const config = functions.config().smtp || {};
  return {
    host: config.host || 'smtp.gmail.com',
    port: parseInt(config.port || '587'),
    user: config.user || '',
    pass: config.pass || '',
    fromName: config.from_name || 'Agenda Visso',
    fromEmail: config.from || '',
  };
}

function crearTransporte() {
  const smtp = getSMTPConfig();
  return nodemailer.createTransport({
    host: smtp.host,
    port: smtp.port,
    secure: smtp.port === 465,
    auth: {
      user: smtp.user,
      pass: smtp.pass,
    },
  });
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

async function enviarCorreo({ to, subject, html, citaId }) {
  if (!to) {
    functions.logger.warn(`Sin destinatario para cita ${citaId}`);
    return null;
  }

  const smtp = getSMTPConfig();
  const transporter = crearTransporte();
  return transporter.sendMail({
    from: `"${smtp.fromName}" <${smtp.fromEmail}>`,
    to,
    subject,
    html,
  });
}

// ─── CONFIRMACIÓN ────────────────────────────────────────
exports.enviarConfirmacion = functions.firestore
  .document('citas/{citaId}')
  .onCreate(async (snap, context) => {
    const { cita, sede, paciente } = await obtenerDatosCita(context.params.citaId);
    const fechaFormateada = formatearFecha(cita.fecha);
    const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');

    const html = `
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body style="font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px;">
      <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden;">
        <div style="background: #009688; padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 24px;">Cita Confirmada</h1>
        </div>
        <div style="padding: 30px;">
          <p style="font-size: 16px;">Hola <strong>${nombrePaciente}</strong>,</p>
          <p style="font-size: 16px;">Tu cita ha sido agendada exitosamente:</p>
          <div style="background: #e0f2f1; border-radius: 8px; padding: 20px; margin: 20px 0;">
            <p style="margin: 4px 0;"><strong>Fecha:</strong> ${fechaFormateada}</p>
            <p style="margin: 4px 0;"><strong>Hora:</strong> ${cita.hora} hs</p>
            <p style="margin: 4px 0;"><strong>Sede:</strong> ${sede.nombre}</p>
            <p style="margin: 4px 0;"><strong>Dirección:</strong> ${sede.direccion}</p>
          </div>
          ${cita.mensajePersonalizado ? `<p style="font-style: italic; color: #666;">${cita.mensajePersonalizado}</p>` : ''}
          <p style="font-size: 14px; color: #888; margin-top: 20px;">
            Si no puedes asistir, por favor cancela tu cita llamando a recepción.
          </p>
        </div>
      </div>
    </body>
    </html>`;

    try {
      await enviarCorreo({
        to: paciente.email,
        subject: `Cita confirmada - ${sede.nombre} - ${cita.hora} hs`,
        html,
        citaId: context.params.citaId,
      });
      await snap.ref.update({ notificada: true });
      functions.logger.log(`Confirmación enviada a ${paciente.email}`);
    } catch (err) {
      functions.logger.error('Error enviando confirmación:', err);
    }

    // Enviar notificación push al profesional
    try {
      const nombrePaciente = (paciente.nombres || 'Paciente').split(' ').slice(0, 2).join(' ');
      await admin.messaging().send({
        topic: 'profesional_notificaciones',
        notification: {
          title: 'Nueva cita agendada',
          body: `${nombrePaciente} - ${sede.nombre} - ${cita.fecha} ${cita.hora}`,
        },
        data: {
          tipo: 'nueva_cita',
          citaId: context.params.citaId,
        },
      });
      functions.logger.log('Push enviado al profesional');
    } catch (err) {
      functions.logger.error('Error enviando push:', err);
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

    const html = `
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body style="font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px;">
      <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden;">
        <div style="background: #1565c0; padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 24px;">Recordatorio de Cita</h1>
        </div>
        <div style="padding: 30px;">
          <p style="font-size: 16px;">Hola <strong>${nombrePaciente}</strong>,</p>
          <p style="font-size: 16px;">Te recordamos que mañana tienes una cita:</p>
          <div style="background: #e3f2fd; border-radius: 8px; padding: 20px; margin: 20px 0;">
            <p style="margin: 4px 0;"><strong>Fecha:</strong> ${fechaFormateada}</p>
            <p style="margin: 4px 0;"><strong>Hora:</strong> ${cita.hora} hs</p>
            <p style="margin: 4px 0;"><strong>Sede:</strong> ${sede.nombre}</p>
            <p style="margin: 4px 0;"><strong>Dirección:</strong> ${sede.direccion}</p>
          </div>
          <p style="font-size: 14px; color: #666;">Por favor llega 10 minutos antes de tu hora agendada.</p>
        </div>
      </div>
    </body>
    </html>`;

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

// ─── RE-AGENDAMIENTO ──────────────────────────────────────
exports.enviarReagendamiento = functions.firestore
  .document('citas/{citaId}')
  .onUpdate(async (change, context) => {
    const antes = change.before.data();
    const despues = change.after.data();

    if (antes.estado !== 'cancelada' && despues.estado === 'cancelada') {
      const { cita, sede, paciente } = await obtenerDatosCita(context.params.citaId);

      if (!paciente.email) return;

      const fechaFormateada = formatearFecha(cita.fecha);
      const nombrePaciente = paciente.nombres.split(' ').slice(0, 2).join(' ');

      const html = `
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"></head>
      <body style="font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px;">
        <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden;">
          <div style="background: #e65100; padding: 30px; text-align: center;">
            <h1 style="color: white; margin: 0; font-size: 24px;">Cita Cancelada</h1>
          </div>
          <div style="padding: 30px;">
            <p style="font-size: 16px;">Hola <strong>${nombrePaciente}</strong>,</p>
            <p style="font-size: 16px;">Tu cita del <strong>${fechaFormateada}</strong> a las <strong>${cita.hora} hs</strong> en <strong>${sede.nombre}</strong> ha sido cancelada.</p>
            <p style="font-size: 16px;">Si deseas reagendar, puedes agendar una nueva cita escaneando el código QR en recepción o contactándonos directamente.</p>
            <div style="text-align: center; margin: 30px 0;">
              <a href="https://agendavisso.web.app" style="background: #e65100; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-size: 16px;">Agendar nueva cita</a>
            </div>
            <p style="font-size: 14px; color: #888;">Disculpa las molestias. Estamos para ayudarte.</p>
          </div>
        </div>
      </body>
      </html>`;

      try {
        await enviarCorreo({
          to: paciente.email,
          subject: `Cita cancelada - Reagenda cuando quieras`,
          html,
          citaId: context.params.citaId,
        });
        functions.logger.log(`Reagendamiento enviado a ${paciente.email}`);
      } catch (err) {
        functions.logger.error('Error enviando reagendamiento:', err);
      }
    }
  });
