import 'dart:io';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:html/dom.dart' as dom;
import 'package:reader/services/chapter_service.dart';
import 'package:reader/services/book_service.dart';
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

  // 添加章节相关变量
  int _currentChapterIndex = 0;
  int _totalChapters = 0;
  final Map<int, List<int>> _chapterPageMap = {}; // 记录每个章节对应的页面范围

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

    await _loadChapters();

    if (_pages.isNotEmpty) {
      final progress = await _progressService.getProgress(widget.book.id!);
      if (progress != null) {
        // 确定当前章节索引
        _currentChapterIndex = progress.chapterIndex;

        // 加载当前章节
        if (_currentChapterIndex > 0) {
          await _loadChapterByIndex(_currentChapterIndex);
        }

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

  List<String> _splitTextIntoPages(String text) {
    List<String> pages = [];

    // 如果文本为空，返回空列表
    if (text.isEmpty) {
      return pages;
    }

    // 获取屏幕尺寸
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final availableHeight = screenHeight - MediaQuery.of(context).padding.vertical - 40.0; // 减去状态栏和内边距

    // 字体和行高设置
    const double fontSize = 18.0;
    const double lineHeight = 1.8;
    const double letterSpacing = 0.8;
    const double paragraphSpacing = 16.0;

    // 计算单行文本高度
    final lineHeightValue = fontSize * lineHeight;
    
    // 计算每页可容纳的最大行数
    final linesPerPage = (availableHeight / (lineHeightValue + paragraphSpacing)).floor();

    print('开始解析HTML内容，文本长度: ${text.length}');
    // 解析HTML内容
    final document = htmlparser.parse(text);
    final bodyElement = document.body;
    if (bodyElement == null) {
      print('HTML解析失败：无法找到body元素');
      // 如果解析失败，尝试将原始文本作为纯文本处理
      text = '<p>$text</p>';
      pages.add(text);
      print('将原始文本作为单个段落处理');
      return pages;
    }

    // 收集所有文本节点和段落
    List<dom.Element> contentElements = [];
    void extractContent(dom.Node node) {
      if (node is dom.Element) {
        if (node.text.trim().isNotEmpty) {
          if (node.localName == 'p') {
            contentElements.add(node);
          } else {
            // 将非段落元素包装成段落
            final wrappedText = '<p>${node.text}</p>';
            contentElements.add(
              htmlparser.parse(wrappedText).body!.firstChild as dom.Element,
            );
          }
        }
      }
    }

    bodyElement.nodes.forEach(extractContent);

    if (contentElements.isEmpty) {
      print('未找到有效内容，尝试将文本作为单个段落处理');
      text = '<p>${bodyElement.text.trim()}</p>';
      pages.add(text);
      return pages;
    }
    print('找到 ${contentElements.length} 个内容元素');

    // 按照段落分页，保持段落完整性
    StringBuffer currentPage = StringBuffer();
    int currentLineCount = 0;
    List<dom.Element> currentPageElements = [];

    for (var element in contentElements) {
      String elementText = element.text.trim();
      String elementHtml = element.outerHtml;

      // 计算当前段落需要的行数
      int paragraphLines = (elementText.length * (fontSize + letterSpacing) / screenSize.width).ceil();

      // 如果当前段落超过一页的行数，直接创建新页
      if (paragraphLines > linesPerPage) {
        // 如果当前页不为空，先保存当前页
        if (currentPageElements.isNotEmpty) {
          pages.add(currentPageElements.map((e) => e.outerHtml).join('\n'));
          currentPageElements.clear();
          currentLineCount = 0;
        }
        // 将长段落单独作为一页
        pages.add(elementHtml);
        continue;
      }

      // 检查添加当前段落是否会导致页面超出行数限制
      if (currentLineCount + paragraphLines > linesPerPage && currentPageElements.isNotEmpty) {
        // 保存当前页并创建新页
        pages.add(currentPageElements.map((e) => e.outerHtml).join('\n'));
        currentPageElements.clear();
        currentLineCount = 0;
      }

      // 将当前段落添加到页面
      currentPageElements.add(element);
      currentLineCount += paragraphLines;
    }

    // 添加最后一页
    if (currentPageElements.isNotEmpty) {
      pages.add(currentPageElements.map((e) => e.outerHtml).join('\n'));
    }

    print('成功分页，共生成 ${pages.length} 页');
    return pages;
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
          _isLoading = false;
        });
        return;
      }

      print('成功获取 ${chapters.length} 个章节');
      final List<String> formattedChapters = [];

      // 添加封面页作为第一页
      if (widget.book.coverPath != null && widget.book.coverPath!.isNotEmpty) {
        formattedChapters.add('cover_image'); // 使用特殊标记表示封面页
        _chapterPageMap[-1] = [0, 0]; // 使用-1表示封面页
      }

      // 加载第一章内容
      if (chapters.isNotEmpty) {
        final firstChapter = chapters.first;
        final chapterText = firstChapter.content;
        final pages = _splitTextIntoPages(chapterText);

        // 记录第一章的页面范围
        int startPage = formattedChapters.length;
        formattedChapters.addAll(pages);
        _chapterPageMap[0] = [startPage, formattedChapters.length - 1];
        _currentChapterIndex = 0; // 设置当前章节索引

        setState(() {
          _pages = formattedChapters;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('章节加载失败: $e\n堆栈追踪：$stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getPageTitle() async {
    if (_pages.isEmpty) return widget.book.title;

    // 如果是封面页，返回书籍标题
    if (_currentPage == 0 && _pages[0] == 'cover_image') {
      return widget.book.title;
    }

    // 找出当前页面属于哪个章节
    for (var entry in _chapterPageMap.entries) {
      if (entry.key >= 0 &&
          _currentPage >= entry.value[0] &&
          _currentPage <= entry.value[1]) {
        final chapter = await _chapterService.getChapterByIndex(
          widget.book.id!,
          entry.key,
        );
        return chapter?.title ?? widget.book.title;
      }
    }

    return widget.book.title;
  }

  // 加载指定索引的章节
  Future<void> _loadChapterByIndex(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= _totalChapters) {
      print('章节索引超出范围: $chapterIndex');
      return;
    }

    // 如果章节已加载，则不重复加载
    if (_chapterPageMap.containsKey(chapterIndex)) {
      print('章节 $chapterIndex 已加载');
      return;
    }

    try {
      final chapter = await _chapterService.getChapterByIndex(
        widget.book.id!,
        chapterIndex,
      );
      if (chapter == null) {
        print('未找到章节: $chapterIndex');
        return;
      }

      final chapterText = chapter.content; // 只使用内容，标题将在页面标题栏显示
      final pages = _splitTextIntoPages(chapterText);

      setState(() {
        // 记录新章节的页面范围
        int startPage = _pages.length;
        _pages.addAll(pages);
        _chapterPageMap[chapterIndex] = [startPage, _pages.length - 1];
        print('加载章节 $chapterIndex 成功，页面范围: $startPage 到 ${_pages.length - 1}');
      });
    } catch (e) {
      print('加载章节 $chapterIndex 失败: $e');
    }
  }

  // 检查并加载下一章节
  Future<void> _checkAndLoadNextChapter(int currentPageIndex) async {
    // 找出当前页面属于哪个章节
    int? currentChapter;
    for (var entry in _chapterPageMap.entries) {
      if (currentPageIndex >= entry.value[0] &&
          currentPageIndex <= entry.value[1]) {
        currentChapter = entry.key;
        break;
      }
    }

    if (currentChapter != null) {
      // 如果当前页是章节的最后一页，预加载下一章
      if (currentPageIndex == _chapterPageMap[currentChapter]![1]) {
        int nextChapterIndex = currentChapter + 1;
        if (nextChapterIndex < _totalChapters &&
            !_chapterPageMap.containsKey(nextChapterIndex)) {
          print('预加载下一章节: $nextChapterIndex');
          await _loadChapterByIndex(nextChapterIndex);
        }
      }
    }
  }

  Future<void> _updateReadingProgress() async {
    if (widget.book.id != null) {
      // 找出当前页面属于哪个章节
      int chapterIndex = 0;
      for (var entry in _chapterPageMap.entries) {
        if (_currentPage >= entry.value[0] && _currentPage <= entry.value[1]) {
          chapterIndex = entry.key;
          break;
        }
      }

      final progress = ReadingProgress(
        bookId: widget.book.id!,
        chapterIndex: chapterIndex,
        scrollPosition: _scrollPosition,
        lastReadTime: DateTime.now(),
      );
      await _progressService.updateProgress(progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          _pages.isNotEmpty && _currentPage == 0 && _pages[0] == 'cover_image'
              ? null // 封面页不显示标题栏
              : AppBar(
                title: FutureBuilder<String>(
                  future: _getPageTitle(),
                  builder: (context, snapshot) {
                    return Text(snapshot.data ?? widget.book.title);
                  },
                ),
              ),
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
                onPageChanged: (index) async {
                  // 防止在加载过程中切换页面
                  if (_isLoading) return;

                  setState(() {
                    _currentPage = index;
                  });

                  // 更新阅读进度
                  await _updateReadingProgress();

                  // 检查是否需要加载下一章
                  await _checkAndLoadNextChapter(index);
                },
                itemBuilder: (context, index) {
                  // 如果是封面页，显示封面图片
                  if (index < _pages.length && _pages[index] == 'cover_image') {
                    return Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Center(
                        child:
                            widget.book.coverPath != null &&
                                    widget.book.coverPath!.isNotEmpty
                                ? Image.file(
                                  File(widget.book.coverPath!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.book,
                                      size: 120,
                                      color: Colors.grey,
                                    );
                                  },
                                )
                                : Icon(
                                  Icons.book,
                                  size: 120,
                                  color: Colors.grey,
                                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        child: Builder(
                          builder: (context) {
                            if (_currentPage >= _pages.length) {
                              print(
                                '当前页面索引超出范围: $_currentPage, 总页数: ${_pages.length}',
                              );
                              return const Center(child: Text('页面不存在'));
                            }

                            final pageContent = _pages[_currentPage];
                            print('正在渲染页面 $_currentPage 的内容');

                            if (pageContent.isEmpty) {
                              print('页面内容为空');
                              return const Center(child: Text('页面内容为空'));
                            }

                            final document = htmlparser.parse(pageContent);
                            final bodyElement = document.body;
                            if (bodyElement == null) {
                              print('HTML解析失败：无法找到body元素');
                              return const Center(child: Text('内容解析失败'));
                            }

                            List<Widget> contentWidgets = [];
                            for (var node in bodyElement.nodes) {
                              if (node is dom.Element) {
                                if (node.localName == 'p') {
                                  final text = node.text.trim();
                                  if (text.isNotEmpty) {
                                    print(
                                      '添加段落文本：${text.substring(0, text.length > 50 ? 50 : text.length)}...',
                                    );
                                    contentWidgets.add(
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                        ),
                                        child: SelectableText.rich(
                                          TextSpan(
                                            text: text,
                                            style: const TextStyle(
                                              fontSize: 18.0,
                                              height: 1.8,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                } else if (node.localName == 'img' &&
                                    node.attributes['src'] != null) {
                                  print('添加图片：${node.attributes['src']}');
                                  contentWidgets.add(
                                    Image.network(
                                      node.attributes['src']!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        print(
                                          '图片加载失败: ${node.attributes['src']} - $error',
                                        );
                                        return const Icon(
                                          Icons.broken_image,
                                          size: 48,
                                          color: Colors.grey,
                                        );
                                      },
                                    ),
                                  );
                                }
                              }
                            }

                            if (contentWidgets.isEmpty) {
                              print('未能生成任何内容组件');
                              return const Center(child: Text('无法显示内容'));
                            }

                            print('成功生成 ${contentWidgets.length} 个内容组件');
                            return Column(children: contentWidgets);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
