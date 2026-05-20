import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/paciente_service.dart';
import '../models/sede.dart';
import '../models/excepcion.dart';
import '../utils/calculador_slots.dart';
import '../utils/colombian_holidays.dart';

class AgendarCitaScreen extends StatefulWidget {
  const AgendarCitaScreen({super.key});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _service = PacienteService();

  int _step = 0;
  bool _cargando = true;

  late List<Sede> _sedes;
  late Map<String, String> _profesionales;
  String? _profesionalId;
  String? _profesionalNombre;
  Sede? _sedeSeleccionada;
  DateTime? _fechaSeleccionada;
  String? _horaSeleccionada;
  List<String> _slotsDisponibles = [];
  List<DateTime> _fechasDisponibles = [];
  final Map<DateTime, String> _fechasNoDisponibles = {};

  final _docCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _yaEraPaciente = false;
  String? _tipoConsulta;

  final _formKey = GlobalKey<FormState>();

  static const _tiposConsulta = [
    'Consulta para lentes oftálmicos',
    'Consulta para lentes de contacto',
    'Ortóptica',
  ];

  static const _pasos = [
    'Sede', 'Fecha', 'Hora', 'Datos'
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _docCtrl.dispose();
    _nombresCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      _sedes = await _service.getSedes();
      _profesionales = await _service.getProfesionales();

      for (final c in _profesionales.entries) {
        final horarios = await _service.getHorarios(c.key);
        if (horarios.isNotEmpty) {
          _profesionalId = c.key;
          _profesionalNombre = c.value;
          break;
        }
      }

      if (_profesionalId == null && _profesionales.isNotEmpty) {
        _profesionalId = _profesionales.keys.first;
        _profesionalNombre = _profesionales.values.first;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _cargando = false);
  }

  void _irPaso(int paso) {
    setState(() => _step = paso);
  }

  Future<void> _onSedeSeleccionada(Sede sede) async {
    if (_profesionalId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: no hay profesional asignado'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    setState(() {
      _cargando = true;
      _sedeSeleccionada = sede;
    });

    try {
      final horarios = await _service.getHorarios(_profesionalId!);
      final excepciones = await _service.getExcepciones(_profesionalId!);
      final hoy = DateTime.now();
      final tresMeses = DateTime(hoy.year, hoy.month + 3, hoy.day);
      final festivos = ColombianHolidays.getHolidaysInRange(hoy, tresMeses);
      final todasExcepciones = [
        ...excepciones,
        ...festivos.map((f) => Excepcion(id: '', profesionalId: '', fecha: f, motivo: 'Festivo')),
      ];
      final diasLaborales = CalculadorSlots.diasLaborales(
        horariosDelProfesional: horarios,
        sedeId: sede.id,
      );

      final excepcionesMap = {for (final e in todasExcepciones) e.fecha.toIso8601String().split('T')[0]: e.motivo};
      _fechasDisponibles = [];
      _fechasNoDisponibles.clear();
      final desde = hoy.add(const Duration(days: 1));
      var actual = desde;
      while (!actual.isAfter(tresMeses)) {
        final fechaStr = actual.toIso8601String().split('T')[0];
        final esLaboral = diasLaborales.contains(actual.weekday);
        if (esLaboral && !excepcionesMap.containsKey(fechaStr)) {
          _fechasDisponibles.add(actual);
        } else {
          _fechasNoDisponibles[actual] = !esLaboral
              ? (actual.weekday == 7 ? 'Domingo' : 'Sábado')
              : (excepcionesMap[fechaStr] ?? 'No disponible');
        }
        actual = actual.add(const Duration(days: 1));
      }

      setState(() => _cargando = false);
      _irPaso(1);
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onFechaSeleccionada(DateTime fecha) async {
    if (_profesionalId == null) return;
    setState(() {
      _cargando = true;
      _fechaSeleccionada = fecha;
    });

    try {
      final horarios = await _service.getHorarios(_profesionalId!);
      final citas = await _service.getCitas(_profesionalId!, fecha);

      final horariosDelDia = horarios
          .where((h) => h.sedeId == _sedeSeleccionada!.id && h.diaSemana == fecha.weekday)
          .toList();

      _slotsDisponibles = CalculadorSlots.calcular(
        horariosDelDia: horariosDelDia,
        citasDelDia: citas,
      );

      setState(() => _cargando = false);
      _irPaso(2);
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar horarios: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profesionalId == null || _sedeSeleccionada == null || _fechaSeleccionada == null || _horaSeleccionada == null) return;

    setState(() => _cargando = true);

    final paciente = await _service.crearPaciente(
      documento: _docCtrl.text.trim(),
      nombres: _nombresCtrl.text.trim(),
      telefono: _telCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      yaEraPaciente: _yaEraPaciente,
    );

    await _service.crearCita(
      profesionalId: _profesionalId!,
      sedeId: _sedeSeleccionada!.id,
      pacienteId: paciente.id,
      fecha: _fechaSeleccionada!,
      hora: _horaSeleccionada!,
      pacienteNombre: _nombresCtrl.text.trim(),
      tipoConsulta: _tipoConsulta,
    );

    setState(() => _cargando = false);
    _irPaso(4);
  }

  String _fechaFormateada(DateTime d) => DateFormat('EEEE d \'de\' MMMM \'de\' yyyy', 'es').format(d);

  String _toAmPm(String hora24) {
    final partes = hora24.split(':');
    final h = int.parse(partes[0]);
    final m = partes[1];
    final periodo = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $periodo';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _step == 0) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profesionales.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agendar cita')),
        body: const Center(child: Text('No hay profesionales disponibles', style: TextStyle(color: Colors.grey))),
      );
    }

    if (_profesionalId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agendar cita')),
        body: const Center(child: Text('Error: no se pudo identificar el profesional', style: TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar cita'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _buildStepper(),
        ),
      ),
      body: _buildCurrentStep(),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_pasos.length, (i) {
          final activo = i == _step;
          final completado = i < _step;
          return Expanded(
            child: Row(
              children: [
                if (i > 0) Expanded(child: Container(height: 2, color: completado ? Colors.teal : Colors.grey.shade300)),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: completado ? Colors.teal : (activo ? Colors.teal.shade100 : Colors.grey.shade300),
                  child: Text(
                    completado ? '✓' : '${i + 1}',
                    style: TextStyle(fontSize: 12, color: completado || activo ? Colors.white : Colors.grey),
                  ),
                ),
                if (i < _pasos.length - 1) Expanded(child: Container(height: 2, color: completado ? Colors.teal : Colors.grey.shade300)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_step >= 4) return _buildResultado();
    switch (_step) {
      case 0: return _buildPaso1Sede();
      case 1: return _buildPaso2Fecha();
      case 2: return _buildPaso3Hora();
      case 3: return _buildPaso4Datos();
      default: return const SizedBox();
    }
  }

  Widget _buildPaso1Sede() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sedes.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_profesionalNombre != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('Profesional asignado: $_profesionalNombre',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              Text('Selecciona tu sede:', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
            ],
          );
        }
        final sede = _sedes[i - 1];
        return Material(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onSedeSeleccionada(sede),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.teal.shade100,
                    child: Icon(Icons.store, color: Colors.teal.shade700),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sede.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(sede.direccion, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaso2Fecha() {
    final todasFechas = [
      ..._fechasDisponibles.map((f) => (fecha: f, disponible: true, motivo: null)),
      ..._fechasNoDisponibles.entries.map((e) => (fecha: e.key, disponible: false, motivo: e.value)),
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(_sedeSeleccionada!.nombre, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (_profesionalNombre != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Profesional asignado: $_profesionalNombre',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
        const Divider(height: 1),
        Expanded(
          child: todasFechas.isEmpty
              ? const Center(child: Text('No hay fechas disponibles', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: todasFechas.length,
                  itemBuilder: (_, i) {
                    final item = todasFechas[i];
                    final fecha = item.fecha;
                    final esFestivo = ColombianHolidays.esFestivo(fecha);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.disponible
                            ? Colors.teal.shade100
                            : Colors.grey.shade200,
                        child: item.disponible
                            ? Text('${fecha.day}',
                                style: const TextStyle(fontWeight: FontWeight.bold))
                            : const Icon(Icons.block, size: 18, color: Colors.grey),
                      ),
                      title: Text(
                        DateFormat('EEEE', 'es').format(fecha),
                        style: TextStyle(
                          color: item.disponible ? null : Colors.grey,
                          fontWeight: item.disponible ? FontWeight.normal : FontWeight.w300,
                        ),
                      ),
                      subtitle: Text(
                        item.disponible
                            ? DateFormat('d \'de\' MMMM \'de\' yyyy', 'es').format(fecha)
                            : '${DateFormat('d \'de\' MMMM', 'es').format(fecha)} — ${item.motivo}',
                        style: TextStyle(
                          color: item.disponible ? null : Colors.grey.shade500,
                          fontStyle: item.disponible ? null : FontStyle.italic,
                        ),
                      ),
                      trailing: item.disponible
                          ? const Icon(Icons.chevron_right)
                          : Icon(Icons.block, size: 18, color: Colors.grey.shade300),
                      enabled: item.disponible,
                      onTap: item.disponible && fecha.isAfter(DateTime.now().subtract(const Duration(days: 1)))
                          ? () => _onFechaSeleccionada(fecha)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaso3Hora() {
    final esFestivo = _fechaSeleccionada != null &&
        ColombianHolidays.esFestivo(_fechaSeleccionada!);
    final nombreFest = esFestivo
        ? ColombianHolidays.nombreFestivo(_fechaSeleccionada!)
        : null;
    return Column(
      children: [
        if (esFestivo)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: Text('Festivo: $nombreFest',
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _fechaFormateada(_fechaSeleccionada!),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _slotsDisponibles.isEmpty
              ? const Center(child: Text('No hay horarios disponibles', style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _slotsDisponibles.length,
                  itemBuilder: (_, i) {
                    final hora = _slotsDisponibles[i];
                    final selected = hora == _horaSeleccionada;
                    final ampm = _toAmPm(hora);
                    return Material(
                      color: selected ? Colors.teal : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() => _horaSeleccionada = hora);
                          _irPaso(3);
                        },
                        child: Center(
                          child: Text(ampm,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.white : Colors.teal.shade700,
                              )),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaso4Datos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tus datos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_profesionalNombre ?? 'Profesional',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            Text('${_sedeSeleccionada!.nombre} - ${_fechaFormateada(_fechaSeleccionada!)} a las ${_toAmPm(_horaSeleccionada!)}'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _docCtrl,
              decoration: const InputDecoration(labelText: 'Documento de identidad', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v?.trim().isEmpty ?? true) return 'Requerido';
                if (v!.trim().length < 5) return 'Mínimo 5 dígitos';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombresCtrl,
              decoration: const InputDecoration(labelText: 'Nombres y apellidos', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.words,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ ]'))],
              validator: (v) => v?.trim().isEmpty ?? true ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telCtrl,
              decoration: const InputDecoration(labelText: 'Teléfono de contacto', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
              inputFormatters: [_TelefonoFormatter()],
              validator: (v) => v?.trim().isEmpty ?? true ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico (opcional)',
                border: OutlineInputBorder(),
                hintText: 'Para enviar recordatorio',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                return emailRegex.hasMatch(v.trim()) ? null : 'Email inválido';
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _tipoConsulta,
              decoration: const InputDecoration(
                labelText: 'Tipo de consulta',
                border: OutlineInputBorder(),
              ),
              items: _tiposConsulta.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _tipoConsulta = v),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Ya soy paciente'),
              value: _yaEraPaciente,
              onChanged: (v) => setState(() => _yaEraPaciente = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _confirmar,
                child: const Text('Confirmar cita'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text('¡Cita agendada!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(_sedeSeleccionada!.nombre, style: Theme.of(context).textTheme.titleMedium),
            Text(_sedeSeleccionada!.direccion),
            if (_profesionalNombre != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Profesional asignado: $_profesionalNombre',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ),
            const SizedBox(height: 8),
            Text(_fechaFormateada(_fechaSeleccionada!), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('A las ${_toAmPm(_horaSeleccionada!)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 32),
            Text('Te enviaremos un recordatorio a tu correo',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _irPaso(0),
              icon: const Icon(Icons.add),
              label: const Text('Agendar otra cita'),
            ),
          ],
        ),
      ),
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
