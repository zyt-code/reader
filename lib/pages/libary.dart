import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:reader/services/book_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reader/utils/epub_utils.dart';
import 'dart:io';

import 'package:reader/widgets/book_grid.dart';

class LibaryPage extends StatefulWidget {
  const LibaryPage({super.key});

  @override
  State<LibaryPage> createState() => _LibaryPageState();
}

class _LibaryPageState extends State<LibaryPage> {
  final BookService bookService = BookService();
  final List<Book> books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    await bookService.init();
    final bookList = await bookService.getBooks();
    setState(() {
      books.addAll(bookList);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '书库',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      // select epub file
                      FilePickerResult? result = await FilePicker.platform
                          .pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['epub'],
                          );
                      if (result != null) {
                        PlatformFile file = result.files.first;
                        if (file.path == null) {
                          throw Exception('无法获取文件路径');
                        }

                        // 获取应用文档目录
                        final appDir = await getApplicationDocumentsDirectory();
                        final booksDir = Directory('${appDir.path}/books');
                        if (!await booksDir.exists()) {
                          await booksDir.create(recursive: true);
                        }

                        // 创建封面图片目录
                        final coversDir = Directory('${appDir.path}/covers');
                        if (!await coversDir.exists()) {
                          await coversDir.create(recursive: true);
                        }

                        // 将文件复制到应用文档目录
                        final fileName = file.name;
                        final newFilePath = '${booksDir.path}/$fileName';
                        await File(file.path!).copy(newFilePath);

                        //  添加到数据库
                        final bookService = BookService();
                        await bookService.init();

                        String title = fileName.replaceAll('.epub', '');
                        String coverPath =
                            'assets/images/book_cover_not_available.jpg';

                        // epubx 解析文件
                        final epubFile = await EpubUtils.parseEpub(newFilePath);

                        // 保存封面图片
                        if (epubFile.coverImage != null) {
                          final coverFileName =
                              '${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final coverFile = File(
                            '${coversDir.path}/$coverFileName',
                          );
                          await coverFile.writeAsBytes(epubFile.coverImage!);
                          coverPath = coverFile.path;
                        }

                        // 创建新的 Book 对象
                        final book = Book(
                          title: epubFile.title ?? title,
                          author: epubFile.author,
                          filePath: newFilePath,
                          coverPath: coverPath,
                          lastReadTime: DateTime.now(),
                          createTime: DateTime.now(),
                        );
                        print("epub data: ${epubFile.toString()}");

                        // 保存到数据库
                        final bookId = await bookService.insertBook(book);
                        book.setId = bookId;

                        // 添加到 books 最前方
                        setState(() {
                          books.insert(0, book);
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BookGrid(books: books),
            ],
          ),
        ),
      ),
    );
  }
}
