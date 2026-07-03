import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AVISO DE PRIVACIDAD',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ley 1581 de 2012 - Protección de Datos Personales',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const Divider(height: 32),
            _section(
              context,
              '1. Responsable del Tratamiento',
              'Acropolis Visso SAS\n'
                  'NIT: 901238905-1\n'
                  'Correo electrónico: acropolisvissopqrs@gmail.com',
            ),
            _section(
              context,
              '2. Datos Recolectados',
              'Los datos personales que recopilamos son exclusivamente los '
                  'necesarios para el agendamiento de citas:\n\n'
                  '• Nombres y apellidos\n'
                  '• Número de documento de identidad\n'
                  '• Número de teléfono\n'
                  '• Correo electrónico (opcional)',
            ),
            _section(
              context,
              '3. Finalidad del Tratamiento',
              'Los datos proporcionados serán utilizados única y '
                  'exclusivamente para:\n\n'
                  '• Agendar, confirmar y gestionar citas de optometría\n'
                  '• Enviar recordatorios de citas\n'
                  '• Contactar al paciente en caso de cambios o cancelaciones\n\n'
                  'No se utilizarán los datos para fines distintos sin '
                  'autorización previa del titular.',
            ),
            _section(
              context,
              '4. Almacenamiento y Seguridad',
              'Los datos se almacenan en Firebase (Google Cloud), con '
                  'servidores ubicados en Estados Unidos. Se implementan '
                  'medidas de seguridad técnicas y organizativas para '
                  'proteger la información contra acceso no autorizado, '
                  'pérdida o alteración.',
            ),
            _section(
              context,
              '5. Derechos del Titular (ARCO)',
              'De acuerdo con la Ley 1581 de 2012, usted tiene derecho a:\n\n'
                  '• Acceder a sus datos personales\n'
                  '• Solicitar la corrección de datos inexactos\n'
                  '• Solicitar la eliminación de sus datos\n'
                  '• Oponerse al tratamiento de sus datos\n'
                  '• Solicitar prueba de la autorización otorgada\n\n'
                  'Para ejercer estos derechos, envíe un correo a:\n'
                  'acropolisvissopqrs@gmail.com',
            ),
            _section(
              context,
              '6. Transferencia de Datos',
              'Sus datos no serán compartidos con terceros no vinculados '
                  'a la prestación del servicio de agendamiento de citas. '
                  'No se realiza transferencia internacional de datos '
                  'distinta al almacenamiento en los servidores de Google '
                  'Cloud (Firebase).',
            ),
            _section(
              context,
              '7. Vigencia y Conservación',
              'Los datos serán conservados mientras sean necesarios para '
                  'la finalidad descrita, y posteriormente durante los '
                  'plazos establecidos por la legislación colombiana. '
                  'Una vez cumplido dicho plazo, los datos serán eliminados '
                  'de forma segura.',
            ),
            _section(
              context,
              '8. Aceptación',
              'Al utilizar esta aplicación y proporcionar sus datos, '
                  'usted manifiesta su aceptación de los términos de '
                  'esta política de privacidad.',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Última actualización: Mayo 2026',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryContainer,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: Colors.grey.shade800,
                ),
          ),
        ],
      ),
    );
  }
}
