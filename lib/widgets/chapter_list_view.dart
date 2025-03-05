import 'package:flutter/material.dart';
import 'package:reader/services/chapter_service.dart';

class ChapterListView extends StatefulWidget {
  final int bookId;
  final int currentChapterIndex;
  final Function(int) onChapterSelected;

  const ChapterListView({
    super.key,
    required this.bookId,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  });

  @override
  State<ChapterListView> createState() => _ChapterListViewState();
}

class _ChapterListViewState extends State<ChapterListView> {
  final ChapterService _chapterService = ChapterService();
  final PageController _pageController = PageController();
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  static const int _chaptersPerPage = 20; // 每页显示的章节数
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    try {
      await _chapterService.init();
      final chapters = await _chapterService.getChaptersByBookId(widget.bookId);
      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });

      // 计算当前章节所在的页码并跳转
      if (widget.currentChapterIndex >= 0 && _chapters.isNotEmpty) {
        final pageIndex = widget.currentChapterIndex ~/ _chaptersPerPage;
        _pageController.jumpToPage(pageIndex);
      }
    } catch (e) {
      print('加载章节列表失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chapters.isEmpty) {
      return const Center(child: Text('暂无章节'));
    }

    // 对章节列表进行去重处理
    final uniqueChapters = _chapters.toSet().toList()
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    final pageCount = (uniqueChapters.length / _chaptersPerPage).ceil();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * _chaptersPerPage;
              final endIndex = (startIndex + _chaptersPerPage).clamp(
                0,
                uniqueChapters.length,
              );
              final pageChapters = uniqueChapters.sublist(startIndex, endIndex);

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
                itemCount: pageChapters.length,
                itemBuilder: (context, index) {
                  final chapter = pageChapters[index];
                  final isCurrentChapter =
                      chapter.chapterIndex == widget.currentChapterIndex;

                  return ListTile(
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight:
                            isCurrentChapter
                                ? FontWeight.bold
                                : FontWeight.normal,
                        color:
                            isCurrentChapter
                                ? Theme.of(context).primaryColor
                                : null,
                      ),
                    ),
                    onTap: () => widget.onChapterSelected(chapter.chapterIndex),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '第 ${_currentPage + 1} / $pageCount 页',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
