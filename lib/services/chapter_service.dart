import 'package:reader/services/database_init_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Chapter {
  int? id;
  final int bookId;
  final String title;
  final String content;
  final String? styleContent;
  final String filePath;
  final int chapterIndex;

  Chapter({
    this.id,
    required this.bookId,
    required this.title,
    required this.content,
    this.styleContent,
    required this.filePath,
    required this.chapterIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'content': content,
      'style_content': styleContent,
      'filePath': filePath,
      'chapter_index': chapterIndex,
    };
  }

  static Chapter fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'],
      bookId: map['bookId'],
      title: map['title'],
      content: map['content'],
      styleContent: map['style_content'],
      filePath: map['filePath'],
      chapterIndex: map['chapter_index'],
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
    _database = await openDatabase(path, version: 4);

    // 确保表已创建
    await DatabaseInitService.initTables(_database!);
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
    print('正在查询书籍ID: $bookId 的章节');
    final List<Map<String, dynamic>> maps = await _database!.query(
      'chapters',
      distinct: true,
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_index ASC',
    );
    print('数据库查询结果: ${maps.length} 条记录');
    if (maps.isEmpty) {
      print('警告：数据库中未找到该书籍的章节数据');
    }
    return List.generate(maps.length, (i) => Chapter.fromMap(maps[i]));
  }

  Future<void> deleteChaptersByBookId(int bookId) async {
    await init();
    await _database!.delete(
      'chapters',
      where: 'bookId = ?',
      whereArgs: [bookId],
    );
  }

  Future<Chapter?> getChapterByIndex(int bookId, int chapterIndex) async {
    await init();
    final List<Map<String, dynamic>> maps = await _database!.query(
      'chapters',
      where: 'bookId = ? AND chapter_index = ?',
      whereArgs: [bookId, chapterIndex],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Chapter.fromMap(maps.first);
  }

  Future<int> getChapterCount(int bookId) async {
    await init();
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM chapters WHERE bookId = ?',
      [bookId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
