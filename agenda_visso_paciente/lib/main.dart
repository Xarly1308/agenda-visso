import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/agendar_cita_screen.dart';
import 'utils/es_localizations.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  await FirebaseAuth.instance.signInAnonymously();
  await initializeDateFormatting('es');
  runApp(const PacienteApp());
}

class PacienteApp extends StatelessWidget {
  const PacienteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agendar Cita',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        EsLocalizationsDelegate(),
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'CO')],
      theme: AppTheme.theme,
      home: const AgendarCitaScreen(),
      locale: const Locale('es', 'CO'),
    );
  }
}
