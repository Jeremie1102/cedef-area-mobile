/// Utilitaires de conversion de dates pour le stockage SQLite (format ISO 8601).
class AppDateUtils {
  AppDateUtils._();

  static const List<String> _monthNames = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static String now() => DateTime.now().toIso8601String();

  static String toIso(DateTime date) => date.toIso8601String();

  static DateTime? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Formate une date au format « 26 août 2026 » (sans dépendance à `intl`).
  static String frenchDate(DateTime date) => '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

  /// Formate une période au format « 26 - 28 août 2026 » (ou « 20 août 2026 »
  /// si les deux dates sont identiques, ou une seule date si l'autre est
  /// absente).
  static String frenchDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    if (start == null) return frenchDate(end!);
    if (end == null) return frenchDate(start);

    final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) return frenchDate(start);

    if (start.year == end.year && start.month == end.month) {
      return '${start.day} - ${end.day} ${_monthNames[end.month - 1]} ${end.year}';
    }
    return '${frenchDate(start)} - ${frenchDate(end)}';
  }

  /// Formate une date/heure au format « 26/08/2026 — 09:42 ».
  static String frenchDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} — $hour:$minute';
  }

  /// Formate une heure au format « 09:42 ».
  static String frenchTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
