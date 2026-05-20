import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/paciente.dart';
import '../models/notificacion.dart';
import '../models/excepcion.dart';
import '../providers/agenda_provider.dart';
import '../providers/auth_provider.dart';
import '../models/sede.dart';
import '../models/tipo_consulta.dart';
import '../utils/calculador_slots.dart';
import '../utils/formato_hora.dart';
import '../services/firestore_service.dart';

class NuevaCitaScreen extends StatefulWidget {
  final VoidCallback? onCitaCreada;
  final Paciente? pacienteInicial;

  const NuevaCitaScreen({super.key, this.onCitaCreada, this.pacienteInicial});

  @override
  State<NuevaCitaScreen> createState() => _NuevaCitaScreenState();
}

class _NuevaCitaScreenState extends State<NuevaCitaScreen> {
  final _service = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _docCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  int _step = 0;
  bool _cargando = true;
  String? _profesionalId;

  Sede? _sedeSeleccionada;
  DateTime? _fechaSeleccionada;
  String? _horaSeleccionada;
  List<String> _slotsDisponibles = [];
  List<Sede> _sedes = [];
  List<int> _diasLaborales = [];
  List<Excepcion> _excepciones = [];
  DateTime _desde = DateTime.now();
  DateTime _hasta = DateTime.now();
  Paciente? _pacienteExistente;
  String? _tipoConsulta;
  List<TipoConsulta> _tiposConsulta = [];

  @override
  void initState() {
    super.initState();
    _profesionalId = context.read<AuthProvider>().user?.uid;
    if (widget.pacienteInicial != null) {
      final p = widget.pacienteInicial!;
      _docCtrl.text = p.documento;
      _nombresCtrl.text = p.nombres;
      _telCtrl.text = p.telefono;
      _emailCtrl.text = p.email ?? '';
      _pacienteExistente = p;
    }
    _cargarDatos();
  }

  @override
  void dispose() {
    _docCtrl.dispose();
    _nombresCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    _sedes = await _service.getSedes();
    if (_sedes.isNotEmpty) _sedeSeleccionada = _sedes.first;
    try {
      _tiposConsulta = await _service.getTiposConsulta();
    } catch (_) {}
    setState(() => _cargando = false);
  }

  Future<void> _onSedeSeleccionada(Sede sede) async {
    if (_profesionalId == null) return;
    setState(() {
      _cargando = true;
      _sedeSeleccionada = sede;
    });

    final horarios = await _service.getHorariosPorProfesional(_profesionalId!);
    final excepciones = await _service.getExcepciones(_profesionalId!);
    final hoy = DateTime.now();
    _desde = hoy.add(const Duration(days: 1));
    _hasta = DateTime(hoy.year, hoy.month + 3, hoy.day);
    final diasLaborales = CalculadorSlots.diasLaborales(
      horariosDelProfesional: horarios,
      sedeId: sede.id,
    );

    _diasLaborales = diasLaborales;
    _excepciones = excepciones;

    setState(() => _cargando = false);
    _irPaso(1);
  }

  Future<void> _onFechaSeleccionada(DateTime fecha) async {
    if (_profesionalId == null) return;
    setState(() {
      _cargando = true;
      _fechaSeleccionada = fecha;
    });

    final horarios = await _service.getHorariosPorProfesional(_profesionalId!);
    final citas = await _service.getCitasPorFecha(fecha);

    final horariosDelDia = horarios
        .where((h) => h.sedeId == _sedeSeleccionada!.id && h.diaSemana == fecha.weekday)
        .toList();
    final citasDelDia = citas
        .where((c) => c.sedeId == _sedeSeleccionada!.id)
        .toList();

    _slotsDisponibles = CalculadorSlots.calcular(
      horariosDelDia: horariosDelDia,
      citasDelDia: citasDelDia,
    );

    setState(() => _cargando = false);
    _irPaso(2);
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profesionalId == null || _sedeSeleccionada == null || _fechaSeleccionada == null || _horaSeleccionada == null) return;

    setState(() => _cargando = true);

    final agenda = context.read<AgendaProvider>();
    final auth = context.read<AuthProvider>();
    final doc = _docCtrl.text.trim();
    final nombres = _nombresCtrl.text.trim();
    final tel = _telCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    Paciente paciente;
    if (_pacienteExistente != null) {
      paciente = _pacienteExistente!;
    } else {
      final existente = await _service.getPacientePorDocumento(doc);
      if (existente != null) {
        paciente = existente;
      } else {
        paciente = await _service.addPaciente(Paciente(
          id: '',
          documento: doc,
          nombres: nombres,
          telefono: tel,
          email: email.isEmpty ? null : email,
        ));
      }
    }

    await agenda.agendarCita(
      sedeId: _sedeSeleccionada!.id,
      pacienteId: paciente.id,
      fecha: _fechaSeleccionada!,
      hora: _horaSeleccionada!,
      creadoPor: auth.user?.uid,
      pacienteNombre: paciente.nombres,
      tipoConsulta: _tipoConsulta,
    );

    final fechaStr = DateFormat('d/M/yyyy').format(_fechaSeleccionada!);
    try {
      final profesionales = await _service.getProfesionales();
      for (final p in profesionales) {
        if (p['id'] == _profesionalId) continue;
        await _service.addNotificacion(
          Notificacion(
            id: '',
            profesionalId: p['id'] as String,
            citaId: '',
            tipo: 'nueva_cita',
            mensaje: 'Nueva cita agendada para el $fechaStr a las ${formato12h(_horaSeleccionada!)}',
            subtitulo: 'Creado por ${auth.nombreUsuario}',
          ),
        );
      }
    } catch (_) {}

    setState(() => _cargando = false);
    _irPaso(3);
  }

  void _irPaso(int paso) {
    setState(() => _step = paso);
  }

  Future<void> _buscarPacienteDialog() async {
    final seleccionado = await showModalBottomSheet<Paciente>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _BuscarPacienteSheet(),
    );

    if (seleccionado != null) {
      _docCtrl.text = seleccionado.documento;
      _nombresCtrl.text = seleccionado.nombres;
      _telCtrl.text = seleccionado.telefono;
      _emailCtrl.text = seleccionado.email ?? '';
      _pacienteExistente = seleccionado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva cita')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _buildStep(),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildPaso1();
      case 1: return _buildPaso2();
      case 2: return _buildPaso3();
      case 3: return _buildConfirmacion();
      default: return const SizedBox();
    }
  }

  Widget _buildPaso1() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Selecciona la sede:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ..._sedes.map((s) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.store)),
            title: Text(s.nombre),
            subtitle: Text(s.direccion),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _onSedeSeleccionada(s),
          ),
        )),
      ],
    );
  }

  Widget _buildPaso2() {
    final fechas = <_FechaInfo>[];
    var actual = _desde;
    while (!actual.isAfter(_hasta)) {
      if (_diasLaborales.contains(actual.weekday)) {
        final fechaStr = DateFormat('yyyy-MM-dd').format(actual);
        final ex = _excepciones.cast<Excepcion?>().firstWhere(
          (e) => DateFormat('yyyy-MM-dd').format(e!.fecha) == fechaStr,
          orElse: () => null,
        );
        fechas.add(_FechaInfo(
          fecha: actual,
          disponible: ex == null,
          motivo: ex?.motivo,
        ));
      }
      actual = actual.add(const Duration(days: 1));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_sedeSeleccionada!.nombre,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Expanded(
          child: fechas.isEmpty
              ? const Center(child: Text('No hay fechas disponibles', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: fechas.length,
                  itemBuilder: (_, i) {
                    final f = fechas[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: f.disponible ? Colors.teal.shade100 : Colors.grey.shade200,
                        child: Text('${f.fecha.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: f.disponible ? null : Colors.grey,
                            )),
                      ),
                      title: Text(
                        DateFormat('EEEE', 'es').format(f.fecha),
                        style: TextStyle(color: f.disponible ? null : Colors.grey),
                      ),
                      subtitle: Text(
                        f.disponible
                            ? DateFormat('d \'de\' MMMM \'de\' yyyy', 'es').format(f.fecha)
                            : '${DateFormat('d \'de\' MMMM', 'es').format(f.fecha)} — ${f.motivo ?? 'No disponible'}',
                        style: TextStyle(color: f.disponible ? null : Colors.grey),
                      ),
                      trailing: f.disponible
                          ? const Icon(Icons.chevron_right)
                          : const Icon(Icons.block, color: Colors.red),
                      enabled: f.disponible,
                      onTap: f.disponible ? () => _onFechaSeleccionada(f.fecha) : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaso3() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            DateFormat('EEEE d \'de\' MMMM', 'es').format(_fechaSeleccionada!),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _slotsDisponibles.isEmpty
              ? const Center(child: Text('No hay horarios disponibles', style: TextStyle(color: Colors.grey)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _slotsDisponibles.map((h) {
                            final sel = h == _horaSeleccionada;
                            return ElevatedButton(
                              onPressed: () => setState(() => _horaSeleccionada = h),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: sel ? Colors.teal : null,
                                foregroundColor: sel ? Colors.white : null,
                              ),
                              child: Text(formato12h(h)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Buscar paciente existente'),
                            onPressed: _buscarPacienteDialog,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _docCtrl,
                          decoration: const InputDecoration(labelText: 'Documento', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nombresCtrl,
                          decoration: const InputDecoration(labelText: 'Nombres y apellidos', border: OutlineInputBorder()),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ ]'))],
                          validator: (v) => (v?.trim().isEmpty ?? true) && (_docCtrl.text.isNotEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telCtrl,
                          decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_TelefonoFormatter()],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            return emailRegex.hasMatch(v.trim()) ? null : 'Email inválido';
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _tipoConsulta,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de consulta',
                            border: OutlineInputBorder(),
                          ),
                          items: _tiposConsulta.map((t) => DropdownMenuItem(
                            value: t.nombre,
                            child: Text(t.nombre),
                          )).toList(),
                          onChanged: (v) => setState(() => _tipoConsulta = v),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _horaSeleccionada != null ? _confirmar : null,
                            child: const Text('Agendar cita'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildConfirmacion() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text('Cita agendada', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(_sedeSeleccionada!.nombre),
            Text(_sedeSeleccionada!.direccion),
            const SizedBox(height: 12),
            Text(
              '${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year} a las ${formato12h(_horaSeleccionada!)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (widget.onCitaCreada != null) {
                  widget.onCitaCreada!.call();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FechaInfo {
  final DateTime fecha;
  final bool disponible;
  final String? motivo;
  _FechaInfo({required this.fecha, required this.disponible, this.motivo});
}

class _BuscarPacienteSheet extends StatefulWidget {
  const _BuscarPacienteSheet();

  @override
  State<_BuscarPacienteSheet> createState() => _BuscarPacienteSheetState();
}

class _BuscarPacienteSheetState extends State<_BuscarPacienteSheet> {
  final _searchCtrl = TextEditingController();
  final _service = FirestoreService();
  List<Paciente> _resultados = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _resultados = []);
      return;
    }
    final r = await _service.buscarPacientes(q.trim());
    setState(() => _resultados = r);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o documento',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: _buscar,
          ),
          const SizedBox(height: 12),
          if (_resultados.isEmpty && _searchCtrl.text.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No se encontraron pacientes', style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _resultados.length,
                itemBuilder: (_, i) {
                  final p = _resultados[i];
                  return ListTile(
                    title: Text(p.nombres),
                    subtitle: Text('Doc: ${p.documento}${p.telefono.isNotEmpty ? ' | Tel: ${p.telefono}' : ''}'),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
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
