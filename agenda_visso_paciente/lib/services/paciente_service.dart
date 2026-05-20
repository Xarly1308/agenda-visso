import '../models/sede.dart';
import '../models/horario.dart';
import '../models/cita.dart';
import '../models/paciente.dart';
import '../models/excepcion.dart';
import 'firestore_rest_service.dart';

class PacienteService {
  final FirestoreRestService _rest = FirestoreRestService();

  Future<List<Sede>> getSedes() => _rest.getSedes();
  Future<Map<String, String>> getProfesionales() => _rest.getProfesionales();
  Future<List<Horario>> getHorarios(String profesionalId) => _rest.getHorarios(profesionalId);
  Future<List<Excepcion>> getExcepciones(String profesionalId) => _rest.getExcepciones(profesionalId);
  Future<List<Cita>> getCitas(String profesionalId, DateTime fecha) => _rest.getCitas(profesionalId, fecha);
  Future<Paciente?> buscarPaciente(String documento) => _rest.buscarPaciente(documento);

  Future<Paciente> crearPaciente({
    required String documento,
    required String nombres,
    required String telefono,
    String? email,
    bool yaEraPaciente = false,
  }) =>
      _rest.crearPaciente(
        documento: documento,
        nombres: nombres,
        telefono: telefono,
        email: email,
        yaEraPaciente: yaEraPaciente,
      );

  Future<Cita> crearCita({
    required String profesionalId,
    required String sedeId,
    required String pacienteId,
    required DateTime fecha,
    required String hora,
    String? pacienteNombre,
    String? creadoPor,
    String? tipoConsulta,
  }) =>
      _rest.crearCita(
        profesionalId: profesionalId,
        sedeId: sedeId,
        pacienteId: pacienteId,
        fecha: fecha,
        hora: hora,
        pacienteNombre: pacienteNombre,
        creadoPor: creadoPor,
        tipoConsulta: tipoConsulta,
      );
}
