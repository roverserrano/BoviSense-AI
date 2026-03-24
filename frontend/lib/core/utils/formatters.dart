String formatDateTime(DateTime? value) {
  if (value == null) return 'Sin fecha';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String formatDate(DateTime? value) {
  if (value == null) return 'Sin fecha';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

String formatSignedInt(int value) {
  if (value > 0) return '+$value';
  return value.toString();
}
