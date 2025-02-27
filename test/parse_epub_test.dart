import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:reader/pages/libary.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  group('parseEpub Tests', () {
    late LibaryPage libaryPage;

    setUp(() {
      libaryPage = const LibaryPage();
    });

    testWidgets(
      'parseEpub with valid epub file should return correct metadata',
      (WidgetTester tester) async {
        // 解析 epub
        final appDir = await getApplicationDocumentsDirectory();
        final booksDir = Directory('${appDir.path}/books');
        final fileName = "绍宋_榴弹怕水.epub";
        final newFilePath = '${booksDir.path}/$fileName';
        parseEpub(newFilePath);
      },
    );
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
