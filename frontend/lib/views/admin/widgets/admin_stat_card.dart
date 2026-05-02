import 'package:flutter/material.dart';

import 'admin_tokens.dart';

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.number,
    required this.label,
    required this.status,
  });

  final String number;
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminPalette.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: AdminPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AdminPalette.muted),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AdminPalette.chipBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              status,
              style: const TextStyle(fontSize: 11, color: AdminPalette.muted),
            ),
          ),
        ],
      ),
    );
  }
}
