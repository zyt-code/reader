import 'dart:io';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:html/dom.dart' as dom;
import 'package:reader/services/chapter_service.dart';
import 'package:reader/services/book_service.dart';
import 'package:reader/services/reading_progress_service.dart';
import 'package:reader/widgets/chapter_list_view.dart';
import 'package:reader/widgets/epub_web_view.dart';

class ReadPage extends StatefulWidget {
  final Book book;

  const ReadPage({super.key, required this.book});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  bool _isLoading = true;
  final ReadingProgressService _progressService = ReadingProgressService();
  final ChapterService _chapterService = ChapterService();
  double _scrollPosition = 0.0;

  // 章节相关变量
  int _currentChapterIndex = 0;
  int _totalChapters = 0;
  Chapter? _currentChapter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initReadingProgress();
    });
  }

  Future<void> _initReadingProgress() async {
    await _progressService.init();
    await _chapterService.init();

    // 获取章节总数
    _totalChapters = await _chapterService.getChapterCount(widget.book.id!);
    print('书籍总章节数: $_totalChapters');

    // 获取阅读进度
    final progress = await _progressService.getProgress(widget.book.id!);
    if (progress != null) {
      setState(() {
        _currentChapterIndex = progress.chapterIndex;
        _scrollPosition = progress.scrollPosition;
      });
    }

    // 加载当前章节
    await _loadCurrentChapter();
  }

  // 加载当前章节
  Future<void> _loadCurrentChapter() async {
    try {
      final chapter = await _chapterService.getChapterByIndex(
        widget.book.id!,
        _currentChapterIndex,
      );
      
      if (chapter == null) {
        print('未找到章节: $_currentChapterIndex');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentChapter = chapter;
        _isLoading = false;
      });
    } catch (e) {
      print('加载章节失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 加载上一章
  Future<void> _loadPreviousChapter() async {
    if (_currentChapterIndex > 0) {
      setState(() {
        _currentChapterIndex--;
        _scrollPosition = 0;
      });
      await _loadCurrentChapter();
      await _updateReadingProgress();
    }
  }

  // 加载下一章
  Future<void> _loadNextChapter() async {
    if (_currentChapterIndex < _totalChapters - 1) {
      setState(() {
        _currentChapterIndex++;
        _scrollPosition = 0;
      });
      await _loadCurrentChapter();
      await _updateReadingProgress();
    }
  }

  Future<String> _getPageTitle() async {
    if (_currentChapter == null) return widget.book.title;
    return _currentChapter!.title;
  }



  Future<void> _updateReadingProgress() async {
    if (widget.book.id != null) {
      final progress = ReadingProgress(
        bookId: widget.book.id!,
        chapterIndex: _currentChapterIndex,
        scrollPosition: _scrollPosition,
        lastReadTime: DateTime.now(),
      );
      await _progressService.updateProgress(progress);
    }
  }

  // 显示章节目录
  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '目录',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ChapterListView(
                  bookId: widget.book.id!,
                  currentChapterIndex: _currentChapterIndex,
                  onChapterSelected: (chapterIndex) {
                    Navigator.pop(context);
                    _jumpToChapter(chapterIndex);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 跳转到指定章节
  Future<void> _jumpToChapter(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= _totalChapters) {
      print('章节索引超出范围: $chapterIndex');
      return;
    }

    setState(() {
      _currentChapterIndex = chapterIndex;
      _scrollPosition = 0.0;
      _isLoading = true;
    });
    
    await _loadCurrentChapter();
    await _updateReadingProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
                title: FutureBuilder<String>(
                  future: _getPageTitle(),
                  builder: (context, snapshot) {
                    return Text(snapshot.data ?? widget.book.title);
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.list),
                    onPressed: _showChapterList,
                    tooltip: '目录',
                  ),
                ],
              ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_currentChapter == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '暂无阅读内容',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '可能原因：书籍解析失败或内容为空',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            EpubWebView(
              htmlContent: _currentChapter!.content,
              styles: _currentChapter!.styleContent != null
                ? {'style': _currentChapter!.styleContent!}
                : null,
              fontSize: 18.0,
              nightMode: false,
              onScroll: (position) {
                _scrollPosition = position;
                _updateReadingProgress();
              },
              initialScrollPosition: _scrollPosition,
            ),
          
          // 章节导航按钮
          if (!_isLoading && _currentChapter != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_currentChapterIndex > 0)
                    FloatingActionButton(
                      heroTag: 'prevChapter',
                      onPressed: _loadPreviousChapter,
                      child: const Icon(Icons.arrow_back),
                    ),
                  if (_currentChapterIndex < _totalChapters - 1)
                    FloatingActionButton(
                      heroTag: 'nextChapter',
                      onPressed: _loadNextChapter,
                      child: const Icon(Icons.arrow_forward),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
