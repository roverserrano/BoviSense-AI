import 'package:flutter/material.dart';

import 'admin_tokens.dart';

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
    return Dialog(
      elevation: 0,
      backgroundColor: AdminPalette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Eliminar usuario',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AdminPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminPalette.muted,
                  height: 1.35,
                ),
                children: [
                  const TextSpan(text: '¿Deseas eliminar a '),
                  TextSpan(
                    text: userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AdminPalette.textPrimary,
                    ),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      elevation: 0,
                      foregroundColor: AdminPalette.inactiveText,
                      side: const BorderSide(
                        color: AdminPalette.border,
                        width: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      elevation: 0,
                      backgroundColor: AdminPalette.danger,
                      foregroundColor: AdminPalette.onDanger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Eliminar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
