import 'package:flutter/material.dart';
import '../services/paciente_service.dart';
import '../models/sede.dart';
import '../models/excepcion.dart';
import '../utils/calculador_slots.dart';
import '../utils/colombian_holidays.dart';

import 'layout/paciente_layout.dart';
import 'widgets/paso_sucursal.dart';
import 'widgets/paso_fecha_hora.dart';
import 'widgets/paso_datos.dart';
import 'widgets/paso_confirmacion.dart';

class AgendarCitaScreen extends StatefulWidget {
  const AgendarCitaScreen({super.key});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _service = PacienteService();

  int _step = 0;
  bool _cargando = true;
  bool _cargandoHoras = false;

  late List<Sede> _sedes = [];
  late Map<String, String> _profesionales = {};
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

  static const _pasos = ['Sucursal', 'Horario', 'Tus Datos', 'Confirmación'];

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
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
    setState(() => _cargando = false);
  }

  void _irPaso(int paso) {
    setState(() => _step = paso);
  }
  
  void _retroceder() {
    if (_step > 0 && _step < 3) {
      _irPaso(_step - 1);
    }
  }

  Future<void> _onSedeSeleccionada(Sede sede) async {
    if (_profesionalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: no hay profesional asignado')),
      );
      return;
    }
    setState(() {
      _cargando = true;
      _sedeSeleccionada = sede;
      _fechaSeleccionada = null;
      _horaSeleccionada = null;
      _slotsDisponibles.clear();
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _onFechaSeleccionada(DateTime fecha) async {
    if (_profesionalId == null) return;
    setState(() {
      _cargandoHoras = true;
      _fechaSeleccionada = fecha;
      _horaSeleccionada = null;
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

      setState(() => _cargandoHoras = false);
    } catch (e) {
      setState(() => _cargandoHoras = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar horarios: $e')),
        );
      }
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profesionalId == null || _sedeSeleccionada == null || _fechaSeleccionada == null || _horaSeleccionada == null) return;

    setState(() => _cargando = true);

    try {
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
      _irPaso(3);
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear cita: $e')),
        );
      }
    }
  }

  void _resetFlujo() {
    setState(() {
      _sedeSeleccionada = null;
      _fechaSeleccionada = null;
      _horaSeleccionada = null;
      _slotsDisponibles.clear();
      _docCtrl.clear();
      _nombresCtrl.clear();
      _telCtrl.clear();
      _emailCtrl.clear();
      _tipoConsulta = null;
      _yaEraPaciente = false;
      _step = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _step == 0) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profesionales.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visso Optometría')),
        body: const Center(child: Text('No hay profesionales disponibles')),
      );
    }

    return PacienteLayout(
      currentStep: _step,
      steps: _pasos,
      onBack: _step > 0 && _step < 3 ? _retroceder : null,
      child: _buildCurrentStepWidget(),
    );
  }

  Widget _buildCurrentStepWidget() {
    if (_cargando && _step != 0) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_step) {
      case 0:
        return PasoSucursal(
          sedes: _sedes,
          profesionalNombre: _profesionalNombre,
          onSedeSeleccionada: _onSedeSeleccionada,
        );
      case 1:
        return PasoFechaHora(
          fechasDisponibles: _fechasDisponibles,
          fechasNoDisponibles: _fechasNoDisponibles,
          fechaSeleccionada: _fechaSeleccionada,
          onFechaSeleccionada: _onFechaSeleccionada,
          slotsDisponibles: _slotsDisponibles,
          horaSeleccionada: _horaSeleccionada,
          cargandoHoras: _cargandoHoras,
          onHoraSeleccionada: (hora) {
            setState(() => _horaSeleccionada = hora);
            // Avanzar automáticamente o con botón? Vamos a avanzar automáticamente para fluidez
            Future.delayed(const Duration(milliseconds: 300), () => _irPaso(2));
          },
        );
      case 2:
        return PasoDatos(
          formKey: _formKey,
          docCtrl: _docCtrl,
          nombresCtrl: _nombresCtrl,
          telCtrl: _telCtrl,
          emailCtrl: _emailCtrl,
          tipoConsulta: _tipoConsulta,
          onTipoConsultaChanged: (v) => setState(() => _tipoConsulta = v),
          yaEraPaciente: _yaEraPaciente,
          onYaEraPacienteChanged: (v) => setState(() => _yaEraPaciente = v),
          onConfirmar: _confirmar,
          cargando: _cargando,
        );
      case 3:
        return PasoConfirmacion(
          sede: _sedeSeleccionada!,
          profesionalNombre: _profesionalNombre,
          fecha: _fechaSeleccionada!,
          hora: _horaSeleccionada!,
          onNuevaCita: _resetFlujo,
        );
      default:
        return const SizedBox();
    }
  }
}
