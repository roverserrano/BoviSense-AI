import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';

class UsuarioHomePage extends StatelessWidget {
  const UsuarioHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bobisense AI'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthViewModel>().logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.grass_rounded,
                  size: 64,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hola, ${usuario?.nombreCompleto ?? 'Usuario'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'La vista del rol Usuario se deja preparada como siguiente módulo.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
