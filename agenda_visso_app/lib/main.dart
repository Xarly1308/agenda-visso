import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/agenda_provider.dart';
import 'providers/config_provider.dart';
import 'providers/notificacion_provider.dart';
import 'providers/pacientes_provider.dart';
import 'services/notificacion_service.dart';
import 'services/app_update_service.dart';
import 'utils/audit_logger.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  NotificacionService.init().catchError((e) => debugPrint('NotificacionService.init error: $e'));
  AuditLogger().cargar().catchError((e) => debugPrint('AuditLogger.cargar error: $e'));
  runApp(const AgendaVissoApp());
}

class AgendaVissoApp extends StatelessWidget {
  const AgendaVissoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF003B74);
    const primaryContainer = Color(0xFF2b4d66);
    const surfaceColor = Color(0xFFf8f9fa);
    final baseTextTheme = GoogleFonts.interTextTheme();
    final titleTextTheme = GoogleFonts.poppinsTextTheme();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AgendaProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => NotificacionProvider()),
        ChangeNotifierProvider(create: (_) => PacientesProvider()),
      ],
      child: MaterialApp(
        title: 'Agenda Visso',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: NotificacionService.messengerKey,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es', 'ES')],
        locale: const Locale('es', 'ES'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryContainer,
            primary: primaryColor,
            onPrimary: Colors.white,
            primaryContainer: primaryContainer,
            secondary: const Color(0xFF32647f),
            secondaryContainer: const Color(0xFFaddefd),
            surface: surfaceColor,
            onSurface: const Color(0xFF191c1d),
            error: const Color(0xFFba1a1a),
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: surfaceColor,
          textTheme: baseTextTheme.copyWith(
            displayLarge: titleTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.02),
            headlineLarge: titleTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
            titleLarge: titleTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            titleMedium: titleTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400, fontSize: 18),
            bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400, fontSize: 16),
            labelMedium: baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.05),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: surfaceColor,
            foregroundColor: primaryContainer,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: titleTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: primaryContainer),
          ),
          navigationBarTheme: NavigationBarThemeData(
            indicatorColor: const Color(0xFF003B74).withAlpha(25),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor);
              }
              return GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF42474d));
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: primaryColor);
              }
              return const IconThemeData(color: Color(0xFF42474d));
            }),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              elevation: 0,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryContainer,
              side: const BorderSide(color: primaryContainer, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFc2c7cd), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFc2c7cd), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: primaryContainer, width: 1.5),
            ),
            labelStyle: baseTextTheme.labelMedium?.copyWith(color: const Color(0xFF42474d)),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFe1e3e4), width: 1),
            ),
            margin: EdgeInsets.zero,
          ),
          listTileTheme: ListTileThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: primaryContainer,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.cargando) {
              return const SplashScreen();
            }
            if (auth.estaLogueado) {
              return const DashboardScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
