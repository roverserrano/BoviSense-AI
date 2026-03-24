import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_view_model.dart';
import 'admin/admin_dashboard_page.dart';
import 'auth/login_page.dart';
import 'ganadero/ganadero_dashboard_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (_, authViewModel, __) {
        if (authViewModel.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authViewModel.isAuthenticated) {
          return const LoginPage();
        }

        final rol = authViewModel.currentUser?.rol.toLowerCase() ?? '';

        if (rol == 'administrador') {
          return const AdminDashboardPage();
        }

        return const GanaderoDashboardPage();
      },
    );
  }
}
