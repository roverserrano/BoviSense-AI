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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      authRepository: authRepository,
      adminUsuarioRepository: adminUsuarioRepository,
      ganaderoRepository: ganaderoRepository,
    ),
  );
}

class BoviSenseApp extends StatelessWidget {
  const BoviSenseApp({
    super.key,
    required this.authRepository,
    required this.adminUsuarioRepository,
    required this.ganaderoRepository,
  });

  final AuthRepository authRepository;
  final AdminUsuarioRepository adminUsuarioRepository;
  final GanaderoRepository ganaderoRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<Esp32BleBridgeService>(
          create: (_) => Esp32BleBridgeService(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(authRepository)..initializeSession(),
        ),
        ChangeNotifierProvider<AdminUsuariosViewModel>(
          create: (_) => AdminUsuariosViewModel(adminUsuarioRepository),
        ),
        ChangeNotifierProvider<GanaderoViewModel>(
          create: (_) => GanaderoViewModel(ganaderoRepository),
        ),
      ],
      child: _AppLifecycleSessionGuard(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'BoviSense',
          theme: AppTheme.lightTheme,
          home: const AppSplashScreen(child: AuthGate()),
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
    if (state != AppLifecycleState.detached || _isClosingSession) {
      return;
    }

    _isClosingSession = true;
    context.read<AuthViewModel>().closeAppSession().whenComplete(() {
      _isClosingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
