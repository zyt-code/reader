import 'package:flutter/material.dart';
import 'package:reader/services/book_service.dart';
import 'package:reader/services/chapter_service.dart';
import 'package:reader/services/reading_progress_service.dart';

class ReadPage extends StatefulWidget {
  final Book book;

  const ReadPage({super.key, required this.book});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  List<String> _pages = [];
  int _currentPage = 0;
  bool _isLoading = true;
  final ReadingProgressService _progressService = ReadingProgressService();
  final ChapterService _chapterService = ChapterService();
  final PageController _pageController = PageController();
  double _scrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _initReadingProgress();
  }

  Future<void> _initReadingProgress() async {
    await _progressService.init();
    await _loadChapters();
    final progress = await _progressService.getProgress(widget.book.id!);
    if (progress != null) {
      setState(() {
        _currentPage = progress.chapterIndex;
        _scrollPosition = progress.scrollPosition;
      });
      _pageController.jumpToPage(_currentPage);
    }
  }

  Future<void> _loadChapters() async {
    try {
      await _chapterService.init();
      final chapters = await _chapterService.getChaptersByBookId(widget.book.id!);
      final List<String> formattedChapters = chapters
          .map((chapter) => '${chapter.title}\n\n${chapter.content}')
          .toList();

      setState(() {
        _pages = formattedChapters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载章节失败：$e')),
      );
    }
  }

  Future<void> _updateReadingProgress() async {
    if (widget.book.id != null) {
      final progress = ReadingProgress(
        bookId: widget.book.id!,
        chapterIndex: _currentPage,
        scrollPosition: _scrollPosition,
        lastReadTime: DateTime.now(),
      );
      await _progressService.updateProgress(progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                _updateReadingProgress();
              },
              itemBuilder: (context, index) {
                return NotificationListener<ScrollNotification>(
                  onNotification: (scrollNotification) {
                    if (scrollNotification is ScrollUpdateNotification) {
                      _scrollPosition = scrollNotification.metrics.pixels;
                      _updateReadingProgress();
                    }
                    return true;
                  },
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _pages[index],
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}