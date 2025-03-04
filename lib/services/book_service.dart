import 'package:reader/services/database_init_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Book {
  int? id;
  final String title;
  final String? author;
  final String? coverPath;
  final String filePath;
  final double progress;
  final DateTime? lastReadTime;
  final DateTime createTime;

  set setId(int value) {
    id = value;
  }

  Book({
    this.id,
    required this.title,
    this.author,
    this.coverPath,
    required this.filePath,
    this.progress = 0.0,
    this.lastReadTime,
    DateTime? createTime,
  }) : this.createTime = createTime ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverPath': coverPath,
      'filePath': filePath,
      'progress': progress,
      'lastReadTime': lastReadTime?.millisecondsSinceEpoch,
      'createTime': createTime.millisecondsSinceEpoch,
    };
  }

  static Book fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      coverPath: map['coverPath'],
      filePath: map['filePath'],
      progress: map['progress'],
      lastReadTime:
          map['lastReadTime'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['lastReadTime'])
              : null,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['createTime']),
    );
  }
}

class BookService {
  static final BookService _instance = BookService._internal();
  Database? _database;

  factory BookService() {
    return _instance;
  }

  BookService._internal();

  Future<void> init() async {
    if (_database != null) return;

    final String path = join(await getDatabasesPath(), 'reader.db');
    _database = await openDatabase(
      path,
      version: 4,
      onCreate: (Database db, int version) async {
        await DatabaseInitService.initTables(db);
      },
    );
  }

  Future<int> insertBook(Book book) async {
    await init();
    return await _database!.insert('books', book.toMap());
  }

  Future<List<Book>> getBooks() async {
    await init();
    final List<Map<String, dynamic>> maps = await _database!.query(
      'books',
      orderBy: 'COALESCE(lastReadTime, createTime) DESC',
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<void> updateBookProgress(int id, double progress) async {
    await init();
    await _database!.update(
      'books',
      {
        'progress': progress,
        'lastReadTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteBook(int id) async {
    await init();
    await _database!.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
