import 'package:shared_preferences/shared_preferences.dart';

class ReadingService {
  static const String _keyDailyReadingTime = 'daily_reading_time';
  static const String _keyReadingStreak = 'reading_streak';
  static const String _keyDailyTarget = 'daily_target';
  static const String _keyLastReadDate = 'last_read_date';

  static final ReadingService _instance = ReadingService._internal();
  late SharedPreferences _prefs;

  factory ReadingService() {
    return _instance;
  }

  ReadingService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkAndUpdateStreak();
  }

  Future<void> _checkAndUpdateStreak() async {
    final String? lastReadDate = _prefs.getString(_keyLastReadDate);
    final DateTime now = DateTime.now();
    final String today = '${now.year}-${now.month}-${now.day}';

    if (lastReadDate == null) {
      await _prefs.setString(_keyLastReadDate, today);
      await _prefs.setInt(_keyReadingStreak, 0);
      return;
    }

    if (lastReadDate != today) {
      final DateTime lastRead = DateTime.parse(lastReadDate);
      final int daysDifference = now.difference(lastRead).inDays;

      if (daysDifference > 1) {
        // 连续阅读中断
        await _prefs.setInt(_keyReadingStreak, 0);
      }
      await _prefs.setString(_keyLastReadDate, today);
    }
  }

  // 获取今日阅读时间（分钟）
  Future<int> getDailyReadingTime() async {
    return _prefs.getInt(_keyDailyReadingTime) ?? 20;
  }

  // 更新今日阅读时间
  Future<void> updateDailyReadingTime(int minutes) async {
    await _prefs.setInt(_keyDailyReadingTime, minutes);
    if (minutes > 0) {
      final int streak = await getReadingStreak();
      await _prefs.setInt(_keyReadingStreak, streak + 1);
    }
  }

  // 获取连续阅读天数
  Future<int> getReadingStreak() async {
    return _prefs.getInt(_keyReadingStreak) ?? 0;
  }

  // 获取每日目标阅读时间（分钟）
  Future<int> getDailyTarget() async {
    return _prefs.getInt(_keyDailyTarget) ?? 40; // 默认40分钟
  }

  // 设置每日目标阅读时间
  Future<void> setDailyTarget(int minutes) async {
    await _prefs.setInt(_keyDailyTarget, minutes);
  }
}
