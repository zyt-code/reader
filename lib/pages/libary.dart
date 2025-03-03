import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:reader/services/book_service.dart';
import 'package:reader/services/chapter_service.dart';
import 'package:reader/pages/reader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reader/utils/epub_utils.dart';
import 'dart:io';

class LibaryPage extends StatefulWidget {
  final Function(bool)? onSelectionModeChange;

  const LibaryPage({super.key, this.onSelectionModeChange});

  @override
  State<LibaryPage> createState() => _LibaryPageState();
}

class _LibaryPageState extends State<LibaryPage> {
  final BookService bookService = BookService();
  final List<Book> books = [];
  bool _isSelectionMode = false;
  final Set<Book> _selectedBooks = {};

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    await bookService.init();
    final bookList = await bookService.getBooks();
    setState(() {
      books.clear();
      books.addAll(bookList);
    });
  }

  void _updateSelectionMode(bool isSelectionMode) {
    setState(() {
      _isSelectionMode = isSelectionMode;
      if (!isSelectionMode) {
        _selectedBooks.clear();
      }
      widget.onSelectionModeChange?.call(isSelectionMode);
    });
  }

  void _updateSelectedBooks(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedBooks.addAll(books);
      } else {
        _selectedBooks.clear();
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedBooks.clear();
      _isSelectionMode = false;
      widget.onSelectionModeChange?.call(false);
    });
  }

  void _deleteSelectedBooks() async {
    // 删除数据库中的书籍
    for (var book in _selectedBooks) {
      await bookService.deleteBook(book.id!);
      // 删除文件
      final file = File(book.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      // 删除封面
      if (book.coverPath != null && !book.coverPath!.startsWith('assets/')) {
        final coverFile = File(book.coverPath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }
    }
    // 重新加载书籍列表
    await _loadBooks();
    // 退出选择模式
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isSelectionMode)
                      TextButton(
                        onPressed: () {
                          _updateSelectedBooks(
                            _selectedBooks.length != books.length,
                          );
                        },
                        child: Text(
                          _selectedBooks.length == books.length ? '取消全选' : '全选',
                        ),
                      )
                    else
                      Text(
                        '书库',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    if (_isSelectionMode)
                      TextButton(
                        onPressed: () {
                          _updateSelectionMode(false);
                        },
                        child: const Text('取消'),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addBook,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      final isSelected = _selectedBooks.contains(book);
                      return GestureDetector(
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedBooks.remove(book);
                              } else {
                                _selectedBooks.add(book);
                              }
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReadPage(book: book),
                              ),
                            );
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedBooks.add(book);
                          });
                          widget.onSelectionModeChange?.call(true);
                        },
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 200,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Opacity(
                                      opacity:
                                          _isSelectionMode && !isSelected
                                              ? 0.5
                                              : 1.0,
                                      child:
                                          book.coverPath!.startsWith('assets/')
                                              ? Image.asset(
                                                book.coverPath!,
                                                fit: BoxFit.contain,
                                                width: double.infinity,
                                              )
                                              : Image.file(
                                                File(book.coverPath!),
                                                fit: BoxFit.contain,
                                                width: double.infinity,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return Image.asset(
                                                    'assets/images/book_cover_not_available.jpg',
                                                    fit: BoxFit.contain,
                                                    width: double.infinity,
                                                  );
                                                },
                                              ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                            if (_isSelectionMode)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          _isSelectionMode
              ? Container(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed:
                      _selectedBooks.isEmpty ? null : _deleteSelectedBooks,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: Colors.transparent,
                  ),
                  child: const Text('删除'),
                ),
              )
              : null,
    );
  }

  void _addBook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );
    if (result != null) {
      PlatformFile file = result.files.first;
      if (file.path == null) {
        throw Exception('无法获取文件路径');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final fileName = file.name;
      final newFilePath = '${booksDir.path}/$fileName';
      await File(file.path!).copy(newFilePath);

      final bookService = BookService();
      await bookService.init();

      String title = fileName.replaceAll('.epub', '');
      String coverPath = 'assets/images/book_cover_not_available.jpg';

      // 解析 EPUB 文件
      final epubFile = await EpubUtils.parseEpub(newFilePath);
      title = epubFile.title ?? title;
      // 保存封面图片
      if (epubFile.coverImage != null) {
        final coverFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final coverFile = File('${coversDir.path}/$coverFileName');
        await coverFile.writeAsBytes(epubFile.coverImage!);
        coverPath = coverFile.path;
      }

      // 创建新的 Book 对象
      final book = Book(
        title: title,
        author: epubFile.author,
        filePath: newFilePath,
        coverPath: coverPath,
        lastReadTime: DateTime.now(),
        createTime: DateTime.now(),
      );

      // 保存书籍到数据库
      final bookId = await bookService.insertBook(book);
      book.setId = bookId;

      // 解析并保存章节信息
      final chapters = await EpubUtils.parseChapters(newFilePath);
      final chapterService = ChapterService();
      await chapterService.init();

      // 将章节信息保存到数据库
      final chapterList =
          chapters.asMap().entries.map((entry) {
            return Chapter(
              bookId: bookId,
              title: entry.value.title,
              content: entry.value.content,
              filePath: newFilePath,
              chapterIndex: entry.key,
            );
          }).toList();

      await chapterService.insertChapters(chapterList);

      // 添加到 books 最前方
      setState(() {
        books.insert(0, book);
      });
    }
  }
}
