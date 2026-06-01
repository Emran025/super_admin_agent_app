/// Formats conversation timestamps for the Chats list (Arabic labels).
abstract final class ConversationTimeFormatter {
  static String format(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(messageDay).inDays;

    if (diff == 0) {
      final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
      final period = local.hour >= 12 ? 'م' : 'ص';
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }
    if (diff == 1) return 'أمس';
    if (diff < 7) return '${local.day}/${local.month.toString().padLeft(2, '0')}';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }
}
