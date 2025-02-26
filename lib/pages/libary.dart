import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:reader/services/book_service.dart';
import 'package:reader/pages/reader.dart';
import 'package:path_provider/path_provider.dart';
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

  /// epubx 解析 epub 文件
  Future<EpubBook> parseEpub(String filePath) async {
    try {
      // 读取文件
      final file = File(filePath);
      final Uint8List bytes = await file.readAsBytes();

      // 解析 EPUB
      final EpubBook epubBook = await EpubReader.readBook(bytes);

      // 获取元数据
      String? title = epubBook.Title;
      String? author = epubBook.Author;
      // List<EpubTextContentFile>? chapters = epubBook.Chapters;
      print("书名: $title");
      print("作者: $author");

      // 获取封面图片
      if (epubBook.CoverImage != null) {
        print("封面获取成功！");
        // 你可以使用 Image.memory(Uint8List.fromList(epubBook.CoverImage!))
      } else {
        print("没有封面图片");
      }

      // // 获取章节信息
      // if (chapters != null) {
      //   print("章节数: ${chapters.length}");
      //   print("第一章标题: ${chapters.first.Title}");
      // }
      return epubBook;
    } catch (e) {
      print("EPUB 解析失败: $e");
      return EpubBook();
    }
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

                        // 将文件复制到应用文档目录
                        final fileName = file.name;
                        final newFilePath = '${booksDir.path}/$fileName';
                        await File(file.path!).copy(newFilePath);

                        //  添加到数据库
                        final bookService = BookService();
                        await bookService.init();

                        String title = fileName.replaceAll('.epub', '');
                        String author = "";

                        // epubx 解析文件
                        final epubFile = await parseEpub(newFilePath);
                        print("epub title: ${epubFile.Title}");

                        // 创建新的 Book 对象
                        final book = Book(
                          title: title,
                          author: author,
                          filePath: newFilePath,
                          coverPath:
                              'assets/images/book_cover_not_available.jpg',
                        );

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
