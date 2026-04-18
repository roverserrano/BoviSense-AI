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
import 'data/services/esp8266_discovery_service.dart';
import 'firebase_options.dart';
import 'viewmodels/admin_usuarios_view_model.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/ganadero_view_model.dart';
import 'views/auth_gate.dart';

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
    BobisenseAiApp(
      authRepository: authRepository,
      adminUsuarioRepository: adminUsuarioRepository,
      ganaderoRepository: ganaderoRepository,
    ),
  );
}

class BobisenseAiApp extends StatelessWidget {
  const BobisenseAiApp({
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
        ChangeNotifierProvider<Esp8266DiscoveryService>(
          create: (_) => Esp8266DiscoveryService()..start(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(authRepository)..restoreSession(),
        ),
        ChangeNotifierProvider<AdminUsuariosViewModel>(
          create: (_) => AdminUsuariosViewModel(adminUsuarioRepository),
        ),
        ChangeNotifierProvider<GanaderoViewModel>(
          create: (_) => GanaderoViewModel(ganaderoRepository),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Bobisense AI',
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}
