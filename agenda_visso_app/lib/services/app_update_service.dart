import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ota_update/ota_update.dart';

class AppUpdateService {
  static const String _project = 'agendavisso';
  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/$_project/databases/(default)/documents';

  final http.Client _client = http.Client();

  Future<Map<String, String>?> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> getLatestVersion() async {
    final headers = await _headers();
    if (headers == null) return null;
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/app_version/latest'),
        headers: headers,
      );
      if (response.statusCode == 404) {
        await _seedDefaultVersion(headers);
        return null;
      }
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = body['fields'] as Map<String, dynamic>;
      return fields.map((k, v) => MapEntry(k, v['stringValue'] as String?));
    } catch (_) {
      return null;
    }
  }

  Future<void> _seedDefaultVersion(Map<String, String> headers) async {
    try {
      await _client.post(
        Uri.parse('$_baseUrl/app_version?documentId=latest'),
        headers: headers,
        body: jsonEncode({
          'fields': {
            'version': {'stringValue': '1.0.0'},
            'buildNumber': {'stringValue': '1'},
            'apkUrl': {'stringValue': 'https://github.com/Xarly1308/agenda-visso/releases/download/v1.0.0/app-release.apk'},
            'notas': {'stringValue': 'Versión inicial'},
          },
        }),
      );
    } catch (_) {}
  }

  bool isUpdateAvailable(String latestVersion, String currentVersion) {
    final latestParts = latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  Future<bool> downloadUpdate(String url, {void Function(double progress, String status)? onProgress}) async {
    try {
      final ota = OtaUpdate();
      final stream = ota.execute(url, destinationFilename: 'app-release.apk', usePackageInstaller: true);
      await for (final event in stream) {
        final p = double.tryParse(event.value ?? '') ?? 0;
        onProgress?.call(p / 100, event.status.name);
        if (event.status == OtaStatus.INSTALLING) break;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}