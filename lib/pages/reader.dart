import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import 'package:reader/services/book_service.dart';

class ReaderPage extends StatefulWidget {
  final String filePath;
  final Book book;

  const ReaderPage({super.key, required this.filePath, required this.book});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late EpubController _epubController;
  final BookService _bookService = BookService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initEpubController();
  }

  Future<void> _initEpubController() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final document = EpubDocument.openFile(File(widget.filePath));
      if (mounted) {
        setState(() {
          _epubController = EpubController(document: document);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打开电子书失败：${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _epubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : EpubView(
              controller: _epubController,
              onChapterChanged: (chapter) {
                if (chapter != null && widget.book.id != null) {
                  _bookService.updateBookProgress(widget.book.id!, chapter.progress);
                }
              },
            ),
    );
  }
}
