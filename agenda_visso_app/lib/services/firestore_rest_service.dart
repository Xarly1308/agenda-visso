import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sede.dart';
import '../models/horario.dart';
import '../models/paciente.dart';
import '../models/cita.dart';
import '../models/excepcion.dart';
import '../models/notificacion.dart';
import '../models/tipo_consulta.dart';

class FirestoreRestService {
  static const String _project = 'agendavisso';
  static const String _baseUrl = 'https://firestore.googleapis.com/v1/projects/'
      '$_project/databases/(default)/documents';

  final http.Client _client = http.Client();
  final Uuid _uuid = const Uuid();

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _url(String path) => Uri.parse('$_baseUrl$path');

  Map<String, dynamic> _fieldsToMap(Map<String, dynamic> fields) {
    return fields.map((key, value) {
      if (value.containsKey('stringValue')) return MapEntry(key, value['stringValue']);
      if (value.containsKey('integerValue')) return MapEntry(key, int.parse(value['integerValue']));
      if (value.containsKey('booleanValue')) return MapEntry(key, value['booleanValue']);
      if (value.containsKey('doubleValue')) return MapEntry(key, double.parse(value['doubleValue']));
      if (value.containsKey('timestampValue')) return MapEntry(key, value['timestampValue']);
      if (value.containsKey('nullValue')) return MapEntry(key, null);
      return MapEntry(key, value.toString());
    });
  }

  Map<String, dynamic> _toFields(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is String) return MapEntry(key, {'stringValue': value});
      if (value is bool) return MapEntry(key, {'booleanValue': value});
      if (value is int) return MapEntry(key, {'integerValue': value.toString()});
      if (value is double) return MapEntry(key, {'doubleValue': value.toString()});
      if (value == null) return MapEntry(key, {'nullValue': null});
      return MapEntry(key, {'stringValue': value.toString()});
    });
  }

  String _docName(String collection, String id) =>
      '$_baseUrl/$collection/$id';

  Future<List<dynamic>> _runQuery(Map<String, dynamic> query) async {
    final response = await _client.post(
      _url(':runQuery'),
      headers: await _headers(),
      body: jsonEncode(query),
    );
    if (response.statusCode != 200) {
      throw Exception('Query error (${response.statusCode}): ${response.body}');
    }
    final results = jsonDecode(response.body) as List;
    return results.where((r) => r.containsKey('document')).toList();
  }

  Future<void> _setDocument(String collection, String id, Map<String, dynamic> data) async {
    final response = await _client.post(
      _url('/$collection?documentId=$id'),
      headers: await _headers(),
      body: jsonEncode({'fields': _toFields(data)}),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al crear $collection: ${response.statusCode}');
    }
  }

  Future<void> _updateDocument(String collection, String id, Map<String, dynamic> data) async {
    final response = await _client.patch(
      _url('/$collection/$id'),
      headers: await _headers(),
      body: jsonEncode({'fields': _toFields(data)}),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar $collection: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> _getDocument(String collection, String id) async {
    final response = await _client.get(
      _url('/$collection/$id'),
      headers: await _headers(),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Error al obtener $collection: ${response.statusCode}');
    }
    final doc = jsonDecode(response.body);
    return _fieldsToMap(doc['fields']);
  }

  Future<void> _commit(List<Map<String, dynamic>> writes) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl:commit'),
      headers: await _headers(),
      body: jsonEncode({'writes': writes}),
    );
    if (response.statusCode != 200) {
      throw Exception('Commit error (${response.statusCode}): ${response.body}');
    }
  }

  // ─── SEDES ────────────────────────────────────────────────────────

  Future<List<Sede>> getSedes() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'sedes'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'activa'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        },
      },
    });
    return docs
        .map((r) => Sede.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<void> addSede(Sede sede) async {
    await _setDocument('sedes', sede.id, sede.toMap());
  }

  Future<void> updateSede(Sede sede) async {
    await _updateDocument('sedes', sede.id, sede.toMap());
  }

  Future<void> deleteSede(String id) async {
    await _updateDocument('sedes', id, {'activa': false});
  }

  // ─── HORARIOS ─────────────────────────────────────────────────────

  Future<List<Horario>> getHorariosPorProfesionalYVariosDias({
    required String profesionalId,
    required List<int> diasSemana,
  }) async {
    if (diasSemana.isEmpty) return [];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'diaSemana'},
                  'op': 'IN',
                  'value': {
                    'arrayValue': {
                      'values': diasSemana
                          .map((d) => {'integerValue': d.toString()})
                          .toList(),
                    },
                  },
                },
              },
            ],
          },
        },
      },
    });
    return docs
        .map((r) => Horario.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Horario>> getHorariosPorSede(String sedeId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'sedeId'},
            'op': 'EQUAL',
            'value': {'stringValue': sedeId},
          },
        },
      },
    });
    return docs
        .map((r) => Horario.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Horario>> getHorariosPorProfesional(String profesionalId) async {
    // Global: return all horarios regardless of professional
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
      },
    });
    return docs
        .map((r) => Horario.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<void> addHorario(Horario horario) async {
    await _setDocument('horarios', horario.id, horario.toMap());
  }

  Future<void> deleteHorario(String id) async {
    final response = await _client.delete(
      _url('/horarios/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar horario: ${response.statusCode}');
    }
  }

  Future<void> setHorarios({
    required String profesionalId,
    required String sedeId,
    required List<Horario> horarios,
  }) async {
    // Global: query horarios by sede only (not by professional)
    final existing = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'horarios'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'sedeId'},
            'op': 'EQUAL',
            'value': {'stringValue': sedeId},
          },
        },
      },
    });

    final writes = <Map<String, dynamic>>[];

    for (final doc in existing) {
      writes.add({
        'delete': doc['document']['name'] as String,
      });
    }

    for (final horario in horarios) {
      final id = _uuid.v4();
      final h = horario.copyWith(
        id: id,
        profesionalId: profesionalId,
        sedeId: sedeId,
      );
      writes.add({
        'update': {
          'name': _docName('horarios', id),
          'fields': _toFields(h.toMap()),
        },
      });
    }

    if (writes.isNotEmpty) {
      await _commit(writes);
    }
  }

  // ─── PACIENTES ────────────────────────────────────────────────────

  Future<void> deletePaciente(String id) async {
    final response = await _client.delete(
      _url('/pacientes/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar paciente: ${response.statusCode}');
    }
  }

  Future<Paciente?> getPacientePorId(String id) async {
    final doc = await _getDocument('pacientes', id);
    if (doc == null) return null;
    return Paciente.fromMap(doc);
  }

  Future<Paciente?> getPacientePorDocumento(String documento) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'pacientes'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'documento'},
            'op': 'EQUAL',
            'value': {'stringValue': documento},
          },
        },
        'limit': 1,
      },
    });
    if (docs.isEmpty) return null;
    return Paciente.fromMap(_fieldsToMap(docs.first['document']['fields']));
  }

  Future<void> updatePaciente(Paciente paciente) async {
    await _updateDocument('pacientes', paciente.id, paciente.toMap());
  }

  Future<Paciente> addPaciente(Paciente paciente) async {
    final id = _uuid.v4();
    final p = Paciente(
      id: id,
      documento: paciente.documento,
      nombres: paciente.nombres,
      telefono: paciente.telefono,
      email: paciente.email,
      yaEraPaciente: paciente.yaEraPaciente,
    );
    await _setDocument('pacientes', id, p.toMap());
    return p;
  }

  Future<List<Paciente>> getAllPacientes() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'pacientes'}],
        'orderBy': [
          {
            'field': {'fieldPath': 'creadoEn'},
            'direction': 'DESCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Paciente.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Paciente>> buscarPacientes(String query) async {
    if (query.isEmpty) return [];
    final all = await getAllPacientes();
    final q = query.toLowerCase();
    return all
        .where((p) =>
            p.nombres.toLowerCase().contains(q) || p.documento.contains(q))
        .toList();
  }

  // ─── CITAS ────────────────────────────────────────────────────────

  Future<List<Cita>> getCitasPorFecha(DateTime fecha) async {
    final fechaStr = fecha.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'fecha'},
            'op': 'EQUAL',
            'value': {'stringValue': fechaStr},
          },
        },
        'orderBy': [
          {
            'field': {'fieldPath': 'hora'},
            'direction': 'ASCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Cita>> getCitasPorFechaYSede(DateTime fecha, String sedeId) async {
    final fechaStr = fecha.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'EQUAL',
                  'value': {'stringValue': fechaStr},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'sedeId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': sedeId},
                },
              },
            ],
          },
        },
        'orderBy': [
          {
            'field': {'fieldPath': 'hora'},
            'direction': 'ASCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Cita>> getCitasPorFechaYProfesional(
      DateTime fecha, String profesionalId) async {
    final fechaStr = fecha.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'EQUAL',
                  'value': {'stringValue': fechaStr},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
            ],
          },
        },
        'orderBy': [
          {
            'field': {'fieldPath': 'hora'},
            'direction': 'ASCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<Cita> addCita(Cita cita) async {
    final id = _uuid.v4();
    final c = cita.copyWith(id: id);
    await _setDocument('citas', id, c.toMap());
    return c;
  }

  Future<void> updateCitaEstado(String id, String estado) async {
    await _updateDocument('citas', id, {'estado': estado});
  }

  Future<void> updateCitaNotificada(String id) async {
    await _updateDocument('citas', id, {'notificada': true});
  }

  Future<void> deleteCita(String id) async {
    final response = await _client.delete(
      _url('/citas/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar cita: ${response.statusCode}');
    }
  }

  Future<void> deleteCitasEnRango(
      String profesionalId, DateTime desde, DateTime hasta) async {
    final d = desde.toIso8601String().split('T')[0];
    final h = hasta.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'stringValue': d},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': {'stringValue': h},
                },
              },
            ],
          },
        },
      },
    });

    if (docs.isEmpty) return;
    final writes = docs
        .map((doc) => {'delete': doc['document']['name'] as String})
        .toList();
    await _commit(writes);
  }

  // ─── EXCEPCIONES ──────────────────────────────────────────────────

  Future<List<Excepcion>> getExcepciones(String profesionalId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'excepciones'}],
      },
    });
    return docs
        .map((r) => Excepcion.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<List<Excepcion>> getExcepcionesEnRango({
    required String profesionalId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final d = desde.toIso8601String().split('T')[0];
    final h = hasta.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'excepciones'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'stringValue': d},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': {'stringValue': h},
                },
              },
            ],
          },
        },
      },
    });
    return docs
        .map((r) => Excepcion.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<void> addExcepcion(Excepcion excepcion) async {
    await _setDocument('excepciones', excepcion.id, excepcion.toMap());
  }

  Future<void> deleteExcepcion(String id) async {
    final response = await _client.delete(
      _url('/excepciones/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar excepción: ${response.statusCode}');
    }
  }

  // ─── PROFESIONALES ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProfesionales() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'profesionales'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'activo'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        },
      },
    });
    return docs
        .map((r) => _fieldsToMap(r['document']['fields']))
        .toList();
  }

  Future<Map<String, dynamic>?> getProfesional(String uid) async {
    return await _getDocument('profesionales', uid);
  }

  Future<void> setProfesional(String uid, Map<String, dynamic> data) async {
    await _setDocument('profesionales', uid, data);
  }

  // ─── NOTIFICACIONES ───────────────────────────────────────────────

  Future<List<Notificacion>> getNotificaciones(String profesionalId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'notificaciones'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'profesionalId'},
            'op': 'EQUAL',
            'value': {'stringValue': profesionalId},
          },
        },
        'orderBy': [
          {
            'field': {'fieldPath': 'fechaCreacion'},
            'direction': 'DESCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) =>
            Notificacion.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<int> getNotificacionesNoLeidas(String profesionalId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'notificaciones'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'leida'},
                  'op': 'EQUAL',
                  'value': {'booleanValue': false},
                },
              },
            ],
          },
        },
      },
    });
    return docs.length;
  }

  Future<void> addNotificacion(Notificacion notificacion) async {
    await _setDocument('notificaciones', notificacion.id, notificacion.toMap());
  }

  Future<void> marcarNotificacionesLeidas(String profesionalId) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'notificaciones'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'leida'},
                  'op': 'EQUAL',
                  'value': {'booleanValue': false},
                },
              },
            ],
          },
        },
      },
    });

    if (docs.isEmpty) return;
    final writes = docs.map((doc) {
      final name = doc['document']['name'] as String;
      return {
        'update': {
          'name': name,
          'fields': _toFields({'leida': true}),
        },
      };
    }).toList();
    await _commit(writes);
  }

  // ─── POLLING (replaces stream) ────────────────────────────────────

  Future<List<Cita>> pollCitasEnRango({
    required String profesionalId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final d = desde.toIso8601String().split('T')[0];
    final h = hasta.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'profesionalId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': profesionalId},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'stringValue': d},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': {'stringValue': h},
                },
              },
            ],
          },
        },
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  // ─── TIPOS CONSULTA ──────────────────────────────────────────────

  Future<List<TipoConsulta>> getTiposConsulta() async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'tipos_consulta'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'activo'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        },
      },
    });
    return docs
        .map((r) =>
            TipoConsulta.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }

  Future<void> addTipoConsulta(TipoConsulta tipo) async {
    await _setDocument('tipos_consulta', tipo.id, tipo.toMap());
  }

  Future<void> deleteTipoConsulta(String id) async {
    await _updateDocument('tipos_consulta', id, {'activo': false});
  }

  // ─── BORRADO MASIVO ─────────────────────────────────────────────

  Future<void> _deleteAllInCollection(String collection) async {
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': collection}],
      },
    });
    if (docs.isEmpty) return;
    final writes = docs
        .map((doc) => {'delete': doc['document']['name'] as String})
        .toList();
    for (var i = 0; i < writes.length; i += 500) {
      final batch = writes.sublist(i, (i + 500).clamp(0, writes.length));
      await _commit(batch);
    }
  }

  Future<void> deleteAllCitas() async {
    await _deleteAllInCollection('citas');
  }

  Future<void> deleteAllCollections() async {
    const collections = [
      'citas', 'sedes', 'horarios', 'tipos_consulta',
      'excepciones', 'pacientes', 'notificaciones', 'profesionales',
    ];
    for (final coll in collections) {
      await _deleteAllInCollection(coll);
    }
  }

  Future<void> deleteSelectedCollections(List<String> collections) async {
    for (final coll in collections) {
      await _deleteAllInCollection(coll);
    }
  }

  // ─── ESTADÍSTICAS ────────────────────────────────────────────────

  Future<List<Cita>> getCitasEnRango(DateTime desde, DateTime hasta) async {
    final d = desde.toIso8601String().split('T')[0];
    final h = hasta.toIso8601String().split('T')[0];
    final docs = await _runQuery({
      'structuredQuery': {
        'from': [{'collectionId': 'citas'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'stringValue': d},
                },
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'fecha'},
                  'op': 'LESS_THAN_OR_EQUAL',
                  'value': {'stringValue': h},
                },
              },
            ],
          },
        },
        'orderBy': [
          {
            'field': {'fieldPath': 'fecha'},
            'direction': 'ASCENDING',
          },
        ],
      },
    });
    return docs
        .map((r) => Cita.fromMap(_fieldsToMap(r['document']['fields'])))
        .toList();
  }
}