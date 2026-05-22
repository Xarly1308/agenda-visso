import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';

class PasoDatos extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController docCtrl;
  final TextEditingController nombresCtrl;
  final TextEditingController telCtrl;
  final TextEditingController emailCtrl;
  final String? tipoConsulta;
  final ValueChanged<String?> onTipoConsultaChanged;
  final bool yaEraPaciente;
  final ValueChanged<bool> onYaEraPacienteChanged;
  final VoidCallback onConfirmar;
  final bool cargando;

  const PasoDatos({
    super.key,
    required this.formKey,
    required this.docCtrl,
    required this.nombresCtrl,
    required this.telCtrl,
    required this.emailCtrl,
    required this.tipoConsulta,
    required this.onTipoConsultaChanged,
    required this.yaEraPaciente,
    required this.onYaEraPacienteChanged,
    required this.onConfirmar,
    required this.cargando,
  });

  static const _tiposConsulta = [
    'Consulta para lentes oftálmicos',
    'Consulta para lentes de contacto',
    'Ortóptica',
  ];

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tus datos',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completa la información para finalizar la reserva.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: nombresCtrl,
                  label: 'Nombres y apellidos',
                  icon: Icons.person_outline,
                  capitalization: TextCapitalization.words,
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ ]'))],
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Campo requerido' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: docCtrl,
                  label: 'Documento de identidad',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Campo requerido';
                    if (v!.trim().length < 5) return 'Mínimo 5 dígitos';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: telCtrl,
                  label: 'Teléfono',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  formatters: [_TelefonoFormatter()],
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Campo requerido' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: emailCtrl,
                  label: 'Correo electrónico (opcional)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    return emailRegex.hasMatch(v.trim()) ? null : 'Correo inválido';
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: tipoConsulta,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryContainer),
            decoration: InputDecoration(
              labelText: 'Tipo de consulta',
              prefixIcon: const Icon(Icons.health_and_safety_outlined, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
            ),
            items: _tiposConsulta.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: onTipoConsultaChanged,
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CheckboxListTile(
              title: const Text('Ya soy paciente de Visso Optometría'),
              value: yaEraPaciente,
              onChanged: (v) => onYaEraPacienteChanged(v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: cargando ? null : onConfirmar,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: cargando 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirmar Reserva', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      inputFormatters: formatters,
      validator: validator,
    );
  }
}

class _TelefonoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) return oldValue;
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) formatted += ' ';
      formatted += digits[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
