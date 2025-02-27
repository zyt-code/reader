import 'package:flutter/material.dart';
import 'package:reader/services/book_service.dart';

class ReadPage extends StatelessWidget {
  final Book book;

  const ReadPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
      ),
      body: const Center(
        child: Text('阅读页面开发中...'),
      ),
    );
  }
}