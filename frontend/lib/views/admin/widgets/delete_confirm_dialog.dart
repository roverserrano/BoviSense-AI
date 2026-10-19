import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

Future<bool> showDeleteConfirmDialog({
  required BuildContext context,
  required String userName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => DeleteConfirmDialog(userName: userName),
  );

  return result ?? false;
}

class DeleteConfirmDialog extends StatelessWidget {
  const DeleteConfirmDialog({super.key, required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eliminar usuario'),
      content: RichText(
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          children: [
            const TextSpan(text: '¿Deseas eliminar a '),
            TextSpan(
              text: userName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const TextSpan(text: '?'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.onDanger,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}
