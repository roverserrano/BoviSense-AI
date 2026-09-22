import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/admin_usuario_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/ganadero_repository.dart';
import 'data/services/api_client.dart';
import 'data/services/esp32_ble_bridge_service.dart';
import 'firebase_options.dart';
import 'viewmodels/admin_usuarios_view_model.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/ganadero_view_model.dart';
import 'views/auth_gate.dart';
import 'views/common/app_splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final authRepository = AuthRepository(
      firebaseAuth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );

    final apiClient = ApiClient(
      auth: FirebaseAuth.instance,
      baseUrl: AppConfig.apiBaseUrl,
    );

    final adminUsuarioRepository = AdminUsuarioRepository(apiClient: apiClient);
    final ganaderoRepository = GanaderoRepository(apiClient: apiClient);

    runApp(
      BoviSenseApp(
        apiClient: apiClient,
        authRepository: authRepository,
        adminUsuarioRepository: adminUsuarioRepository,
        ganaderoRepository: ganaderoRepository,
      ),
    );
  } catch (error) {
    runApp(BootstrapErrorApp(message: error.toString()));
  }
}

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BoviSense',
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error al iniciar la aplicacion:\n$message',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BoviSenseApp extends StatefulWidget {
  const BoviSenseApp({
    super.key,
    this.apiClient,
    required this.authRepository,
    required this.adminUsuarioRepository,
    required this.ganaderoRepository,
  });

  final ApiClient? apiClient;
  final AuthRepository authRepository;
  final AdminUsuarioRepository adminUsuarioRepository;
  final GanaderoRepository ganaderoRepository;

  @override
  State<BoviSenseApp> createState() => _BoviSenseAppState();
}

class _BoviSenseAppState extends State<BoviSenseApp> {
  @override
  void dispose() {
    widget.apiClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthViewModel>(
      create: (_) => AuthViewModel(widget.authRepository)..initializeSession(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BoviSense',
        theme: AppTheme.lightTheme,
        home: AppSplashScreen(
          child: _SessionScope(
            adminUsuarioRepository: widget.adminUsuarioRepository,
            ganaderoRepository: widget.ganaderoRepository,
          ),
        ),
      ),
    );
  }
}

class _SessionScope extends StatelessWidget {
  const _SessionScope({
    required this.adminUsuarioRepository,
    required this.ganaderoRepository,
  });

  final AdminUsuarioRepository adminUsuarioRepository;
  final GanaderoRepository ganaderoRepository;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) => KeyedSubtree(
        key: ValueKey(auth.currentUser?.uid ?? 'signed-out'),
        child: MultiProvider(
          providers: [
            Provider<AdminUsuarioRepository>(
              create: (_) => adminUsuarioRepository.newSession(),
            ),
            Provider<GanaderoRepository>(
              create: (_) => ganaderoRepository.newSession(),
            ),
            ChangeNotifierProvider<Esp32BleBridgeService>(
              create: (context) =>
                  Esp32BleBridgeService(context.read<GanaderoRepository>()),
            ),
            ChangeNotifierProvider<AdminUsuariosViewModel>(
              create: (context) => AdminUsuariosViewModel(
                context.read<AdminUsuarioRepository>(),
              ),
            ),
            ChangeNotifierProvider<GanaderoViewModel>(
              create: (context) =>
                  GanaderoViewModel(context.read<GanaderoRepository>()),
            ),
          ],
          child: const _AppLifecycleSessionGuard(child: AuthGate()),
        ),
      ),
    );
  }
}

class _AppLifecycleSessionGuard extends StatefulWidget {
  const _AppLifecycleSessionGuard({required this.child});

  final Widget child;

  @override
  State<_AppLifecycleSessionGuard> createState() =>
      _AppLifecycleSessionGuardState();
}

class _AppLifecycleSessionGuardState extends State<_AppLifecycleSessionGuard>
    with WidgetsBindingObserver {
  bool _isClosingSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<Esp32BleBridgeService>().pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      context.read<Esp32BleBridgeService>().resumePolling();
      // El telefono puede haber estado horas bloqueado: los datos del panel no
      // deben quedar viejos.
      if (context.read<AuthViewModel>().isAuthenticated) {
        context.read<GanaderoViewModel>().loadDashboard();
      }
    }
    if (state != AppLifecycleState.detached || _isClosingSession) {
      return;
    }

    _isClosingSession = true;
    context
        .read<AuthViewModel>()
        .closeAppSession()
        .catchError((Object _) {
          // La siguiente apertura descarta cualquier sesion persistida.
        })
        .whenComplete(() {
          _isClosingSession = false;
        });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
