import 'package:sqflite/sqflite.dart';

class DatabaseInitService {
  static Future<void> initTables(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS books('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'title TEXT, '
      'author TEXT, '
      'coverPath TEXT, '
      'filePath TEXT, '
      'progress REAL, '
      'lastReadTime INTEGER, '
      'createTime INTEGER NOT NULL DEFAULT 0'
      ')',
    );

    await db.execute(
      'CREATE TABLE IF NOT EXISTS chapters('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'bookId INTEGER NOT NULL, '
      'title TEXT NOT NULL, '
      'content TEXT NOT NULL, '
      'filePath TEXT NOT NULL, '
      'chapter_index INTEGER NOT NULL, '
      'FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE'
      ')',
    );

    await db.execute(
      'CREATE TABLE IF NOT EXISTS reading_progress('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'bookId INTEGER NOT NULL, '
      'chapterIndex INTEGER NOT NULL, '
      'scrollPosition REAL NOT NULL, '
      'lastReadTime TEXT NOT NULL'
      ')',
    );
  }
}
