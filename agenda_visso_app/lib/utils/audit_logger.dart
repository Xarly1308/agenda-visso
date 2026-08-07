import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_rest_service.dart';

class AuditLogger {
  AuditLogger._();
  static final AuditLogger instance = AuditLogger._();
  factory AuditLogger() => instance;

  static const _prefsKey = 'audit_config';
  static const _defaultEnabled = true;

  static const categorias = {
    'citas': 'Citas',
    'franquicias': 'Franquicias',
    'profesionales': 'Profesionales',
    'sedes': 'Sedes',
    'horarios': 'Horarios',
    'configuracion': 'Tipos de consulta y excepciones',
    'limpieza': 'Limpieza de datos',
  };

  Map<String, bool> _config = {};
  bool _cargado = false;

  Map<String, bool> get config => Map.unmodifiable(_config);

  bool estaHabilitada(String categoria) => _config[categoria] ?? _defaultEnabled;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    if (raw != null) {
      _config = {
        for (final entry in raw)
          entry.split(':').first: entry.split(':').last == 'true',
      };
    }
    for (final key in categorias.keys) {
      _config.putIfAbsent(key, () => _defaultEnabled);
    }
    _cargado = true;
  }

  Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _config.entries.map((e) => '${e.key}:${e.value}').toList();
    await prefs.setStringList(_prefsKey, raw);
  }

  Future<void> toggleCategoria(String key) async {
    _config[key] = !(_config[key] ?? _defaultEnabled);
    await guardar();
  }

  Future<void> registrar({
    required String categoria,
    required String accion,
    required String coleccion,
    String? documentoId,
    required String usuarioId,
    required String usuarioNombre,
    String? franquiciaId,
    String? detalles,
  }) async {
    if (!_cargado) await cargar();
    if (!estaHabilitada(categoria)) return;
    await FirestoreRestService().registrarAuditLog(
      accion: accion,
      coleccion: coleccion,
      documentoId: documentoId,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      franquiciaId: franquiciaId,
      detalles: detalles,
    );
  }
}
