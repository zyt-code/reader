import 'dart:io';

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
  bool _hasError = false; // 新增错误状态
  String _errorMessage = '';
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

    if (_pages.isNotEmpty) {
      final progress = await _progressService.getProgress(widget.book.id!);
      if (progress != null) {
        final validIndex = progress.chapterIndex.clamp(0, _pages.length - 1);
        setState(() {
          _currentPage = validIndex;
          _scrollPosition = progress.scrollPosition;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(validIndex);
        });
      }
    }
  }

  Future<void> _loadChapters() async {
    print('开始加载书籍内容，路径：${widget.book.filePath}');
    try {
      await _chapterService.init();
      print('正在查询书籍ID: ${widget.book.id} 的章节');
      final chapters = await _chapterService.getChaptersByBookId(
        widget.book.id!,
      );

      if (chapters.isEmpty) {
        print('数据库章节记录为空');
        setState(() {
          _hasError = true;
          _errorMessage = '未找到书籍章节内容';
        });
        return;
      }

      print('成功获取 ${chapters.length} 个章节');
      final List<String> formattedChapters = [];

      // 添加封面页作为第一页
      if (widget.book.coverPath != null && widget.book.coverPath!.isNotEmpty) {
        formattedChapters.add('cover_image'); // 使用特殊标记表示封面页
      }

      // 添加章节内容
      formattedChapters.addAll(
        chapters
            .map((chapter) => '${chapter.title}\n\n${chapter.content}')
            .toList(),
      );

      setState(() {
        _pages = formattedChapters;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('章节加载失败: $e\n堆栈追踪：$stackTrace');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '内容加载失败：${e.toString()}';
      });
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
      appBar: AppBar(title: Text(widget.book.title)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _pages.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '暂无阅读内容',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '可能原因：书籍解析失败或内容为空',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )
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
                  // 如果是封面页，显示封面图片
                  if (_pages[index] == 'cover_image' &&
                      widget.book.coverPath?.isNotEmpty == true) {
                    return Center(
                      child: Image.file(
                        File(widget.book.coverPath!),
                        fit: BoxFit.contain,
                      ),
                    );
                  }

                  // 显示章节内容
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
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(height: 1.6, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
