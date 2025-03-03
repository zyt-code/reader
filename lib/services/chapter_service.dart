import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Chapter {
  int? id;
  final int bookId;
  final String title;
  final String content;
  final String filePath;
  final int chapterIndex;

  Chapter({
    this.id,
    required this.bookId,
    required this.title,
    required this.content,
    required this.filePath,
    required this.chapterIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'content': content,
      'filePath': filePath,
      'index': chapterIndex,
    };
  }

  static Chapter fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'],
      bookId: map['bookId'],
      title: map['title'],
      content: map['content'],
      filePath: map['filePath'],
      chapterIndex: map['index'],
    );
  }
}

class ChapterService {
  static final ChapterService _instance = ChapterService._internal();
  Database? _database;

  factory ChapterService() {
    return _instance;
  }

  ChapterService._internal();

  Future<void> init() async {
    if (_database != null) return;

    final String path = join(await getDatabasesPath(), 'reader.db');
    _database = await openDatabase(
      path,
      version: 4,
      // 不在这里创建表，因为BookService已经负责创建了
    );
    
    // 检查表是否存在，如果不存在则创建
    final tables = await _database!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='chapters'"
    );
    if (tables.isEmpty) {
      await _database!.execute(
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
    }

  }

  Future<void> insertChapters(List<Chapter> chapters) async {
    await init();
    final batch = _database!.batch();
    for (var chapter in chapters) {
      batch.insert('chapters', chapter.toMap());
    }
    await batch.commit();
  }

  Future<List<Chapter>> getChaptersByBookId(int bookId) async {
    await init();
    final List<Map<String, dynamic>> maps = await _database!.query(
      'chapters',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_index ASC',
    );
    return List.generate(maps.length, (i) => Chapter.fromMap(maps[i]));
  }

  Future<void> deleteChaptersByBookId(int bookId) async {
    await init();
    await _database!.delete('chapters', where: 'bookId = ?', whereArgs: [bookId]);
  }
}