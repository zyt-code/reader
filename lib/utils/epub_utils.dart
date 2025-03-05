import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

/// EPUB 书籍元数据
class EpubMetadata {
  final String? title;
  final String? author;
  final String? description;
  final String? publisher;
  final String? language;
  final String? identifier;
  final Uint8List? coverImage;
  final List<String> chapters;
  final List<EpubTocEntry>? tableOfContents; // 目录结构
  final Map<String, String>? cssStyles; // CSS样式表
  final String? tocNcxPath; // NCX文件路径
  final Map<String, String>? guide; // guide信息

  EpubMetadata({
    this.title,
    this.author,
    this.description,
    this.publisher,
    this.language,
    this.identifier,
    this.coverImage,
    required this.chapters,
    this.tableOfContents,
    this.cssStyles,
    this.tocNcxPath,
    this.guide,
  });

  @override
  String toString() {
    return 'EpubMetadata{title: $title, author: $author, description: $description, '
        'publisher: $publisher, language: $language, identifier: $identifier, '
        'chapters size: ${chapters.length}, hasCover: ${coverImage != null}, '
        'tocEntries: ${tableOfContents?.length}, cssStyles: ${cssStyles?.length}}';
  }
}

/// EPUB 章节内容
class EpubChapter {
  final String title;
  final String content;
  final String? htmlContent; // 原始HTML内容
  final Map<String, String>? styles; // 应用的样式
  final String? filePath; // 章节文件路径

  EpubChapter({
    required this.title, 
    required this.content, 
    this.htmlContent, 
    this.styles,
    this.filePath,
  });
}

/// EPUB 目录条目
class EpubTocEntry {
  final String label; // 目录标题
  final String? content; // 指向的内容路径
  final int level; // 目录层级
  final List<EpubTocEntry> children; // 子目录
  final String? id; // 条目ID
  final int? playOrder; // 播放顺序

  EpubTocEntry({
    required this.label,
    this.content,
    required this.level,
    this.children = const [],
    this.id,
    this.playOrder,
  });
}

/// EPUB 解析工具类
class EpubUtils {
  static String opfBaseDir = '';
  static Map<String, Uint8List> _epubFiles = {}; // 缓存EPUB文件内容
  static Map<String, String> _cssStyles = {}; // 缓存CSS样式表

  /// 解析CSS样式表文件
  static Map<String, String> _parseCssFiles(XmlDocument xmlDoc, String opfPath) {
    final Map<String, String> styles = {};
    final manifest = xmlDoc.findAllElements("manifest").first;
    
    // 查找所有CSS文件
    final cssItems = manifest.findElements("item").where((item) {
      final mediaType = item.getAttribute("media-type");
      return mediaType == "text/css" || 
             (item.getAttribute("href")?.toLowerCase().endsWith(".css") ?? false);
    });

    // 解析每个CSS文件
    for (final cssItem in cssItems) {
      final href = cssItem.getAttribute("href");
      if (href != null) {
        final cssPath = _resolvePath(opfPath, href);
        final cssBytes = _epubFiles[cssPath];
        if (cssBytes != null) {
          final cssContent = const Utf8Decoder().convert(cssBytes);
          styles[cssPath] = cssContent;
        }
      }
    }

    return styles;
  }

  /// 解析NCX文件
  static Future<List<EpubTocEntry>> _parseNcxFile(String ncxPath) async {
    final ncxBytes = _epubFiles[ncxPath];
    if (ncxBytes == null) return [];

    final ncxContent = const Utf8Decoder().convert(ncxBytes);
    final xmlDoc = XmlDocument.parse(ncxContent);
    final navMap = xmlDoc.findAllElements("navMap").firstOrNull;
    if (navMap == null) return [];

    List<EpubTocEntry> parseNavPoint(XmlElement navPoint, int level) {
      final List<EpubTocEntry> entries = [];
      final label = navPoint.findElements("navLabel")
          .firstOrNull?.findElements("text")
          .firstOrNull?.innerText.trim();
      final content = navPoint.findElements("content")
          .firstOrNull?.getAttribute("src");
      final id = navPoint.getAttribute("id");
      final playOrder = int.tryParse(
          navPoint.getAttribute("playOrder") ?? "");

      if (label != null) {
        final children = navPoint.findElements("navPoint")
            .map((np) => parseNavPoint(np, level + 1))
            .expand((e) => e)
            .toList();

        entries.add(EpubTocEntry(
          label: label,
          content: content,
          level: level,
          children: children,
          id: id,
          playOrder: playOrder,
        ));
      }

      return entries;
    }

    return navMap.findElements("navPoint")
        .map((np) => parseNavPoint(np, 0))
        .expand((e) => e)
        .toList();
  }

  /// 解析 EPUB 文件
  static Future<EpubMetadata> parseEpub(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('EPUB 文件不存在: $filePath');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    _epubFiles = {for (var f in archive.files) f.name: f.content};

    // 第一步：读取META-INF/container.xml文件
    final containerXmlBytes = _epubFiles['META-INF/container.xml'];
    if (containerXmlBytes == null) throw Exception('EPUB 缺少 container.xml');
    final containerXml = const Utf8Decoder().convert(containerXmlBytes);

    final opfPath = _getXmlAttributeValue(
      containerXml,
      'rootfile',
      'full-path',
    );
    if (opfPath == null) throw Exception('无法找到 OPF 文件路径');

    // 第二步：读取解析opf文件
    final opfContentBytes = _epubFiles[opfPath];
    if (opfContentBytes == null) throw Exception('找不到 OPF 文件');
    final opfContent = const Utf8Decoder().convert(opfContentBytes);

    // 获取OPF文件所在的基础目录
    opfBaseDir =
        opfPath.contains('/')
            ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
            : '';

    final xmlDoc = XmlDocument.parse(opfContent);
    final metadata = xmlDoc.findAllElements("metadata").first;
    final title = _getXmlTagContent(metadata, 'dc:title');
    final author = _getXmlTagContent(metadata, 'dc:creator');
    final description = _getXmlTagContent(metadata, 'dc:description');
    final publisher = _getXmlTagContent(metadata, 'dc:publisher');
    final language = _getXmlTagContent(metadata, 'dc:language');
    final identifier = _getXmlTagContent(metadata, 'dc:identifier');

    // 解析封面图片
    Uint8List? coverImage;
    final coverPath = _findCoverPath(opfContent);
    if (coverPath != null) {
      final fullCoverPath = _resolvePath(opfPath, coverPath);
      final coverData = _epubFiles[fullCoverPath];
      if (coverData is Uint8List) {
        coverImage = coverData;
      }
    }

    // 解析章节路径
    final chapters = _getChapterPaths(xmlDoc);
    
    // 解析目录文件路径
    final tocId = xmlDoc.findAllElements("spine").firstOrNull?.getAttribute("toc");
    String? tocNcxPath;
    if (tocId != null) {
      final tocItem = xmlDoc.findAllElements("item")
          .firstWhereOrNull((e) => e.getAttribute("id") == tocId);
      if (tocItem != null) {
        final tocHref = tocItem.getAttribute("href");
        if (tocHref != null) {
          tocNcxPath = _resolvePath(opfPath, tocHref);
        }
      }
    } else {
      // 尝试查找NCX文件
      final ncxItem = xmlDoc.findAllElements("item")
          .firstWhereOrNull((e) => 
              (e.getAttribute("media-type") == "application/x-dtbncx+xml") ||
              (e.getAttribute("href")?.toLowerCase().endsWith(".ncx") ?? false));
      if (ncxItem != null) {
        final ncxHref = ncxItem.getAttribute("href");
        if (ncxHref != null) {
          tocNcxPath = _resolvePath(opfPath, ncxHref);
        }
      }
    }
    
    // 解析guide信息
    Map<String, String>? guide;
    final guideElement = xmlDoc.findAllElements("guide").firstOrNull;
    if (guideElement != null) {
      guide = {};
      for (final reference in guideElement.findElements("reference")) {
        final type = reference.getAttribute("type");
        final href = reference.getAttribute("href");
        if (type != null && href != null) {
          guide[type] = _resolvePath(opfPath, href);
        }
      }
    }
    
    // 第四步：解析CSS样式表文件
    _cssStyles = _parseCssFiles(xmlDoc, opfPath);
    
    // 第三步：解析NCX目录文件
    List<EpubTocEntry>? tableOfContents;
    if (tocNcxPath != null) {
      tableOfContents = await _parseNcxFile(tocNcxPath);
    }

    return EpubMetadata(
      title: title,
      author: author,
      description: description,
      publisher: publisher,
      language: language,
      identifier: identifier,
      coverImage: coverImage,
      chapters: chapters,
      tableOfContents: tableOfContents,
      cssStyles: _cssStyles,
      tocNcxPath: tocNcxPath,
      guide: guide,
    );
  }

  /// 解析章节内容
  static Future<List<EpubChapter>> parseChapters(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = {for (var f in archive.files) f.name: f.content};

    final metadata = await parseEpub(filePath);
    final List<EpubChapter> chapters = [];
    print('开始解析章节列表，共有 ${metadata.chapters.length} 个章节');

    for (var chapterPath in metadata.chapters) {
      final normalizedPath = chapterPath
          .replaceAll('\\', '/')
          .replaceAll('//', '/');
      final chapterBytes = files[normalizedPath];
      if (chapterBytes != null) {
        final content = const Utf8Decoder().convert(chapterBytes);
        final document = html.parse(content);

        // 提取标题
        String? title = document.querySelector('h2#title')?.text;
        if (title == null || title.isEmpty) {
          title = document.querySelector('title')?.text ?? '';
          if (title.isEmpty) {
            title = document.querySelector('h1')?.text ?? '未命名章节';
          }
        }

        // 提取和处理样式信息
        Map<String, String> chapterStyles = {};
        final styleLinks = document.querySelectorAll('link[rel="stylesheet"]');
        final inlineStyles = document.querySelectorAll('style');
        
        // 处理外部样式表
        for (var link in styleLinks) {
          final href = link.attributes['href'];
          if (href != null) {
            final stylePath = _resolvePath(normalizedPath, href);
            if (_cssStyles.containsKey(stylePath)) {
              chapterStyles[stylePath] = _cssStyles[stylePath]!;
            }
          }
        }
        
        // 处理内联样式
        for (var style in inlineStyles) {
          final styleId = 'inline_${chapterStyles.length}';
          chapterStyles[styleId] = style.text;
        }

        // 处理正文内容
        final body = document.body;
        if (body != null) {
          // 移除脚本标签
          body.querySelectorAll('script').forEach((element) => element.remove());

          // 保留原始HTML结构，但清理不必要的属性
          void cleanElement(dom.Element element) {
            // 保留的属性列表
            final keepAttributes = ['id', 'class', 'style', 'href', 'src'];
            element.attributes.removeWhere((key, _) => !keepAttributes.contains(key));
            element.nodes.whereType<dom.Element>().forEach(cleanElement);
          }
          cleanElement(body);

          // 获取处理后的HTML内容
          final processedHtml = body.outerHtml;
          
          // 提取纯文本内容（用于搜索和显示）
          final textContent = body.text.trim();

          chapters.add(
            EpubChapter(
              title: title,
              content: textContent,
              htmlContent: processedHtml,
              styles: chapterStyles,
              filePath: normalizedPath,
            ),
          );
        }
      }
    }

    print('章节解析完成，共解析出 ${chapters.length} 个章节');
    return chapters;
  }

  /// 提取 XML 标签内容
  static String? _getXmlTagContent(XmlElement parent, String tag) {
    return parent.findElements(tag).firstOrNull?.innerText.trim();
  }

  /// 提取 XML 属性值
  static String? _getXmlAttributeValue(
    String xml,
    String tag,
    String attribute,
  ) {
    final xmlDoc = XmlDocument.parse(xml);
    final element = xmlDoc.findAllElements(tag).firstOrNull;
    return element?.getAttribute(attribute);
  }

  /// 解析章节路径
  static List<String> _getChapterPaths(XmlDocument xmlDoc) {
    final List<String> chapters = [];
    final spine = xmlDoc.findAllElements("spine").firstOrNull;
    if (spine == null) {
      print('警告：找不到 spine 元素');
      return chapters;
    }

    final manifest = xmlDoc.findAllElements("manifest").first;
    final itemRefs = spine.findElements("itemref");

    final opfDir = opfBaseDir;

    for (final ref in itemRefs) {
      final idRef = ref.getAttribute("idref");
      final item = manifest
          .findElements("item")
          .firstWhereOrNull((e) => e.getAttribute("id") == idRef);

      if (item != null) {
        // 跳过id为'cover'的HTML文件，只保留封面图片
        if (item.getAttribute("id") == "cover") {
          print('跳过封面HTML文件: ${item.getAttribute("href")}');
          continue;
        }

        final path = item.getAttribute("href");
        if (path != null) {
          final fullPath = opfDir.isEmpty ? path : "$opfDir/$path";
          final normalizedPath = fullPath.replaceAll("//", "/");
          chapters.add(normalizedPath);
        }
      }
    }

    return chapters;
  }

  /// 解析封面路径
  static String? _findCoverPath(String opfContent) {
    final xmlDoc = XmlDocument.parse(opfContent);
    final manifest = xmlDoc.findAllElements("manifest").first;

    var coverItem = manifest
        .findElements("item")
        .firstWhereOrNull(
          (e) => e.getAttribute("properties")?.contains("cover-image") ?? false,
        );

    coverItem ??= manifest
        .findElements("item")
        .firstWhereOrNull(
          (e) => e.getAttribute("id")?.toLowerCase().contains("cover") ?? false,
        );

    coverItem ??= manifest.findElements("item").firstWhereOrNull((e) {
      final mediaType = e.getAttribute("media-type") ?? "";
      final href = e.getAttribute("href")?.toLowerCase() ?? "";
      return mediaType.startsWith("image/") && href.contains("cover");
    });

    if (coverItem == null) {
      final metadata = xmlDoc.findAllElements("metadata").first;
      final metaCover = metadata
          .findElements("meta")
          .firstWhereOrNull((e) => e.getAttribute("name") == "cover");

      if (metaCover != null) {
        final coverId = metaCover.getAttribute("content");
        coverItem = manifest
            .findElements("item")
            .firstWhereOrNull((e) => e.getAttribute("id") == coverId);
      }
    }

    coverItem ??= manifest
        .findElements("item")
        .firstWhereOrNull(
          (e) => (e.getAttribute("media-type") ?? "").startsWith("image/"),
        );

    return coverItem?.getAttribute("href");
  }

  /// 解析相对路径
  static String _resolvePath(String basePath, String relativePath) {
    final baseDir = basePath.substring(0, basePath.lastIndexOf('/') + 1);
    return baseDir + relativePath;
  }
}
