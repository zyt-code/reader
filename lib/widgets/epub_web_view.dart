import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubWebView extends StatefulWidget {
  final String htmlContent;
  final Map<String, String>? styles;
  final double fontSize;
  final bool nightMode;
  final Function(double) onScroll;
  final double initialScrollPosition;

  const EpubWebView({
    super.key,
    required this.htmlContent,
    this.styles,
    this.fontSize = 18.0,
    this.nightMode = false,
    required this.onScroll,
    this.initialScrollPosition = 0.0,
  });

  @override
  State<EpubWebView> createState() => _EpubWebViewState();
}

class _EpubWebViewState extends State<EpubWebView> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _currentScrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _currentScrollPosition = widget.initialScrollPosition;
  }

  @override
  void didUpdateWidget(EpubWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.nightMode != widget.nightMode ||
        oldWidget.htmlContent != widget.htmlContent) {
      _updateContent();
    }
  }

  Future<void> _updateContent() async {
    if (_webViewController != null) {
      await _loadContent();
    }
  }

  Future<void> _loadContent() async {
    if (_webViewController == null) return;

    final htmlContent = _prepareHtmlContent();
    await _webViewController!.loadData(
      data: htmlContent,
      mimeType: 'text/html',
      encoding: 'UTF-8',
    );

    // 恢复滚动位置
    if (_currentScrollPosition > 0) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _webViewController?.scrollTo(
          x: 0,
          y: _currentScrollPosition.toInt(),
          animated: false,
        );
      });
    }
  }

  String _prepareHtmlContent() {
    // 构建CSS样式
    final StringBuffer cssStyles = StringBuffer();

    // 添加外部样式表和内联样式
    if (widget.styles != null) {
      widget.styles!.forEach((_, styleContent) {
        // 保留原始样式，不做修改
        cssStyles.write(styleContent);
        cssStyles.write('\n');
      });
    }

    // 添加自定义样式
    cssStyles.write('''
      :root {
        --font-size: ${widget.fontSize}px;
        --text-color: ${widget.nightMode ? '#CCCCCC' : '#333333'};
        --background-color: ${widget.nightMode ? '#222222' : '#FFFFFF'};
        --link-color: ${widget.nightMode ? '#8AB4F8' : '#1A73E8'};
      }
      
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        font-size: var(--font-size);
        line-height: 1.8;
        color: var(--text-color);
        background-color: var(--background-color);
        padding: 20px;
        margin: 0;
      }
      
      h1, h2, h3, h4, h5, h6 {
        color: var(--text-color);
        line-height: 1.4;
        margin-top: 1.5em;
        margin-bottom: 0.5em;
      }
      
      p {
        margin-bottom: 1em;
      }
      
      a {
        color: var(--link-color);
        text-decoration: none;
      }
      
      img {
        max-width: 100%;
        height: auto;
      }

      /* 目录页特殊样式 */
      .toc-entry {
        margin: 0.5em 0;
        padding-left: calc(var(--font-size) * 1.5 * var(--level, 0));
      }

      .toc-entry a {
        display: block;
        padding: 0.5em 0;
        color: var(--text-color);
        text-decoration: none;
        transition: color 0.2s;
      }

      .toc-entry a:hover {
        color: var(--link-color);
      }
    ''');

    // 构建完整的HTML文档
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <style>
        ${cssStyles.toString()}
      </style>
    </head>
    <body>
      ${widget.htmlContent}
      <script>
        // 监听滚动事件
        window.addEventListener('scroll', function() {
          window.flutter_inappwebview.callHandler('onScroll', window.scrollY);
        });
      </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              transparentBackground: true,
              disableContextMenu: true,
              supportZoom: false,
              disableHorizontalScroll: true,
              verticalScrollBarEnabled: false,
            ),
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;

            // 注册JavaScript处理器
            controller.addJavaScriptHandler(
              handlerName: 'onScroll',
              callback: (args) {
                if (args.isNotEmpty && args[0] is double) {
                  _currentScrollPosition = args[0];
                  widget.onScroll(_currentScrollPosition);
                }
              },
            );

            _loadContent();
          },
          onLoadStart: (controller, url) {
            setState(() {
              _isLoading = true;
            });
          },
          onLoadStop: (controller, url) {
            setState(() {
              _isLoading = false;
            });
          },
          onLoadError: (controller, url, code, message) {
            setState(() {
              _isLoading = false;
            });
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            // 处理内部链接导航
            final uri = navigationAction.request.url;
            if (uri != null && uri.scheme != 'file' && uri.scheme != 'data') {
              // 可以在这里处理外部链接，例如在浏览器中打开
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
        ),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
