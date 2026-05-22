import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

const String _kSavedUsers = 'saved_users';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePass = true;
  bool _recordar = false;
  List<Map<String, String>> _savedUsers = [];
  bool _cargandoSaved = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuariosGuardados();
  }

  Future<void> _cargarUsuariosGuardados() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavedUsers);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _savedUsers = list
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    }
    if (mounted) setState(() => _cargandoSaved = false);
  }

  Future<void> _guardarUsuarioActual() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    _savedUsers.removeWhere((u) => u['email'] == email);
    _savedUsers.insert(0, {'email': email, 'pass': pass});
    await prefs.setString(_kSavedUsers, jsonEncode(_savedUsers));
    if (mounted) setState(() {});
  }

  Future<void> _eliminarUsuario(String email) async {
    final prefs = await SharedPreferences.getInstance();
    _savedUsers.removeWhere((u) => u['email'] == email);
    await prefs.setString(_kSavedUsers, jsonEncode(_savedUsers));
    if (mounted) setState(() {});
  }

  void _seleccionarUsuario(Map<String, String> user) {
    _emailCtrl.text = user['email'] ?? '';
    _passCtrl.text = user['pass'] ?? '';
    setState(() => _recordar = true);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.limpiarError();
    final ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && _recordar) {
      await _guardarUsuarioActual();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF003B74),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/splash.png', width: 120,
                      errorBuilder: (c, e, s) => const Icon(Icons.visibility, size: 80, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Agenda Visso', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),

                  if (!_cargandoSaved && _savedUsers.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('USUARIOS GUARDADOS',
                            style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11, letterSpacing: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._savedUsers.map((u) => _buildUserCard(u)),
                  ],

                  SizedBox(height: _savedUsers.isNotEmpty ? 16 : 40),
                  TextFormField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withAlpha(25),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v?.contains('@') == true ? null : 'Ingrese un correo válido',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      filled: true,
                      fillColor: Colors.white.withAlpha(25),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                    ),
                    obscureText: _obscurePass,
                    validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Mínimo 6 caracteres',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _recordar,
                        onChanged: (v) => setState(() => _recordar = v ?? false),
                        fillColor: WidgetStateProperty.resolveWith((_) => Colors.white.withAlpha(30)),
                        checkColor: Colors.white,
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _recordar = !_recordar),
                        child: const Text('Recordar contraseña', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (auth.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(auth.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.cargando ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF003B74),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: auth.cargando
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Ingresar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, String> user) {
    final email = user['email'] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _seleccionarUsuario(user),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withAlpha(30),
                  child: const Icon(Icons.person_outline, color: Colors.white70, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(email, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white.withAlpha(100), size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _eliminarUsuario(email),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
