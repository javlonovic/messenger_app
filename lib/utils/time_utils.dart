import 'package:intl/intl.dart';

class TimeUtils {
  static String formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return DateFormat('HH:mm').format(dt);
    if (date == yesterday) return 'Yesterday';
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }

  static String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'last seen a while ago';
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
    return 'last seen ${DateFormat('dd MMM').format(lastSeen)}';
  }

  static String formatChatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return DateFormat('HH:mm').format(dt);
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }
}
