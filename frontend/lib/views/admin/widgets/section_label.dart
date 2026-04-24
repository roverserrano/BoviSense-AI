import 'package:flutter/material.dart';

import 'admin_tokens.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AdminPalette.muted,
          letterSpacing: 0.77,
        ),
      ),
    );
  }
}
