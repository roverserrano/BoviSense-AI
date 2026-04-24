import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/conteo_model.dart';

class GanaderoColors {
  static const Color primary = Color(0xFF4A6741);
  static const Color accent = Color(0xFFA8C9A0);
  static const Color textDark = Color(0xFF2D4228);
  static const Color textSecondary = Color(0xFF5A7254);
  static const Color muted = Color(0xFF7A9472);

  static const Color bg = Color(0xFFF8F6F1);
  static const Color card = Color(0xFFFFFFFF);
  static const Color borderSoft = Color(0xFFD8D2C0);
  static const Color borderInput = Color(0xFFC5BFA8);
  static const Color surfaceAlt = Color(0xFFF0ECE4);

  static const Color amberBg = Color(0xFFF5E4C0);
  static const Color amberText = Color(0xFF7A4F10);
  static const Color amberBorder = Color(0xFFC8903A);

  static const Color redBg = Color(0xFFFCEBEB);
  static const Color redText = Color(0xFF7A2820);

  static const Color successBg = Color(0xFFF0F7E8);
  static const Color successText = Color(0xFF3B6D11);

  static const Color buttonText = Color(0xFFE8F0E4);
}

enum SimpleStatusType { pending, ready, inProgress, finished, error }

enum StepStateType { completed, active, pending }

String statusLabel(SimpleStatusType status) {
  switch (status) {
    case SimpleStatusType.pending:
      return 'Pendiente';
    case SimpleStatusType.ready:
      return 'Listo';
    case SimpleStatusType.inProgress:
      return 'En curso';
    case SimpleStatusType.finished:
      return 'Terminado';
    case SimpleStatusType.error:
      return 'Error';
  }
}

Color statusColor(SimpleStatusType status) {
  switch (status) {
    case SimpleStatusType.pending:
      return GanaderoColors.muted;
    case SimpleStatusType.ready:
      return GanaderoColors.successText;
    case SimpleStatusType.inProgress:
      return GanaderoColors.amberText;
    case SimpleStatusType.finished:
      return GanaderoColors.primary;
    case SimpleStatusType.error:
      return GanaderoColors.redText;
  }
}

class GanaderoAppBar extends AppBar {
  GanaderoAppBar({super.key, required String titleText, super.actions})
    : super(
        backgroundColor: GanaderoColors.primary,
        foregroundColor: GanaderoColors.buttonText,
        title: Text(
          titleText,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: GanaderoColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class NextStepCard extends StatelessWidget {
  const NextStepCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GanaderoColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Siguiente paso',
            style: TextStyle(
              fontSize: 12,
              color: GanaderoColors.accent,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: GanaderoColors.buttonText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFFDCE8D8),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: GanaderoColors.textDark,
                backgroundColor: GanaderoColors.accent,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
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
        color: GanaderoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GanaderoColors.borderSoft, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: GanaderoColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: GanaderoColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: GanaderoColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 11,
                color: GanaderoColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryItem extends StatelessWidget {
  const HistoryItem({super.key, required this.conteo, this.onTap});

  final ConteoModel conteo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final diff = conteo.diferencia;
    final Color color;
    final String status;

    if (diff == 0) {
      color = GanaderoColors.successText;
      status = 'Exacto';
    } else if (diff < 0) {
      color = GanaderoColors.amberText;
      status = 'Faltante';
    } else {
      color = GanaderoColors.redText;
      status = 'Excedente';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GanaderoColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GanaderoColors.borderSoft, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDateTime(conteo.fechaHoraInicio),
                    style: const TextStyle(
                      fontSize: 12,
                      color: GanaderoColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Lote principal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: GanaderoColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real ${conteo.cantidadDetectada} / Esperado ${conteo.cantidadEsperada}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GanaderoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  diff > 0 ? '+$diff' : '$diff',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 11, color: color),
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

class StepFlowItem extends StatelessWidget {
  const StepFlowItem({
    super.key,
    required this.title,
    required this.description,
    required this.state,
    this.requiredAction,
  });

  final String title;
  final String description;
  final StepStateType state;
  final String? requiredAction;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final Color borderColor;

    switch (state) {
      case StepStateType.completed:
        dotColor = GanaderoColors.successText;
        borderColor = GanaderoColors.successText;
      case StepStateType.active:
        dotColor = GanaderoColors.amberBg;
        borderColor = GanaderoColors.amberBorder;
      case StepStateType.pending:
        dotColor = GanaderoColors.surfaceAlt;
        borderColor = GanaderoColors.borderSoft;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GanaderoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GanaderoColors.borderSoft, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: Border.all(color: borderColor, width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: GanaderoColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GanaderoColors.textSecondary,
                  ),
                ),
                if (requiredAction != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    requiredAction!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: GanaderoColors.amberText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.status,
    required this.label,
    required this.subtitle,
  });

  final SimpleStatusType status;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GanaderoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GanaderoColors.borderSoft, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: GanaderoColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GanaderoColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final SimpleStatusType status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    switch (status) {
      case SimpleStatusType.error:
        bg = GanaderoColors.redBg;
        border = GanaderoColors.redText;
        text = GanaderoColors.redText;
      case SimpleStatusType.inProgress:
        bg = GanaderoColors.amberBg;
        border = GanaderoColors.amberBorder;
        text = GanaderoColors.amberText;
      default:
        bg = GanaderoColors.successBg;
        border = GanaderoColors.successText;
        text = GanaderoColors.successText;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: border, width: 3),
          top: BorderSide(color: border.withValues(alpha: 0.2), width: 0.5),
          right: BorderSide(color: border.withValues(alpha: 0.2), width: 0.5),
          bottom: BorderSide(color: border.withValues(alpha: 0.2), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: text,
            ),
          ),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(fontSize: 12, color: text)),
        ],
      ),
    );
  }
}

class ResultHero extends StatelessWidget {
  const ResultHero({
    super.key,
    required this.value,
    required this.unit,
    required this.expected,
    required this.diff,
    required this.status,
  });

  final int value;
  final String unit;
  final int expected;
  final int diff;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GanaderoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GanaderoColors.borderSoft, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 48,
              height: 1,
              fontWeight: FontWeight.w500,
              color: GanaderoColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unit,
            style: const TextStyle(fontSize: 12, color: GanaderoColors.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroMetric('Esperados', '$expected'),
              _heroMetric('Diferencia', diff > 0 ? '+$diff' : '$diff'),
              _heroMetric('Estado', status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: GanaderoColors.muted),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: GanaderoColors.textDark,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: GanaderoColors.primary,
          foregroundColor: GanaderoColors.buttonText,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GanaderoColors.buttonText,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class StopButton extends StatelessWidget {
  const StopButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFF5D0CC),
          foregroundColor: GanaderoColors.redText,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: GanaderoColors.primary,
          side: const BorderSide(color: GanaderoColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class GanaderoBottomNavBar extends StatelessWidget {
  const GanaderoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: GanaderoColors.borderSoft, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: GanaderoColors.card,
        selectedItemColor: GanaderoColors.primary,
        unselectedItemColor: GanaderoColors.muted,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Finca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline_rounded),
            label: 'Conteo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}

class TechnicalDetails extends StatelessWidget {
  const TechnicalDetails({super.key, required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GanaderoColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GanaderoColors.borderSoft, width: 0.5),
      ),
      child: ExpansionTile(
        collapsedIconColor: GanaderoColors.textSecondary,
        iconColor: GanaderoColors.textSecondary,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: GanaderoColors.textSecondary,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          if (lines.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sin datos técnicos por ahora.',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: GanaderoColors.textSecondary,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: GanaderoColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
