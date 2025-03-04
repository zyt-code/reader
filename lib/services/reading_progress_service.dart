import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ReadingProgress {
  int? id;
  final int bookId;
  final int chapterIndex;
  final double scrollPosition;
  final DateTime lastReadTime;

  ReadingProgress({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.scrollPosition,
    required this.lastReadTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'scrollPosition': scrollPosition,
      'lastReadTime': lastReadTime.toIso8601String(),
    };
  }

  static ReadingProgress fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      id: map['id'],
      bookId: map['bookId'],
      chapterIndex: map['chapterIndex'],
      scrollPosition: map['scrollPosition'],
      lastReadTime: DateTime.parse(map['lastReadTime']),
    );
  }
}

class ReadingProgressService {
  static final ReadingProgressService _instance = ReadingProgressService._internal();
  Database? _database;

  factory ReadingProgressService() {
    return _instance;
  }

  ReadingProgressService._internal();

  Future<void> init() async {
    if (_database != null) return;

    final String path = join(await getDatabasesPath(), 'reader.db');
    _database = await openDatabase(
      path,
      version: 4,
      onCreate: (Database db, int version) async {
        await db.execute(
          'CREATE TABLE reading_progress('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'bookId INTEGER NOT NULL, '
          'chapterIndex INTEGER NOT NULL, '
          'scrollPosition REAL NOT NULL, '
          'lastReadTime TEXT NOT NULL'
          ')',
        );
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // 检查表是否存在
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='reading_progress'"
        );
        if (tables.isEmpty) {
          await db.execute(
            'CREATE TABLE reading_progress('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'bookId INTEGER NOT NULL, '
            'chapterIndex INTEGER NOT NULL, '
            'scrollPosition REAL NOT NULL, '
            'lastReadTime TEXT NOT NULL'
            ')',
          );
        }
      },
    );
  }

  Future<ReadingProgress?> getProgress(int bookId) async {
    final List<Map<String, dynamic>> maps = await _database!.query(
      'reading_progress',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );

    if (maps.isEmpty) return null;
    return ReadingProgress.fromMap(maps.first);
  }

  Future<void> updateProgress(ReadingProgress progress) async {
    if (progress.id == null) {
      await _database!.insert('reading_progress', progress.toMap());
    } else {
      await _database!.update(
        'reading_progress',
        progress.toMap(),
        where: 'id = ?',
        whereArgs: [progress.id],
      );
    }
  }
}