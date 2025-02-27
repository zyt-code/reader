import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:collection/collection.dart';
import 'dart:convert';

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

  EpubMetadata({
    this.title,
    this.author,
    this.description,
    this.publisher,
    this.language,
    this.identifier,
    this.coverImage,
    required this.chapters,
  });

  @override
  String toString() {
    return 'EpubMetadata{title: $title, author: $author, description: $description, '
        'publisher: $publisher, language: $language, identifier: $identifier, '
        'chapters size: ${chapters.length}, hasCover: ${coverImage != null}}';
  }
}

/// EPUB 解析工具类
class EpubUtils {
  /// 解析 EPUB 文件
  static Future<EpubMetadata> parseEpub(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('EPUB 文件不存在: $filePath');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = {for (var f in archive.files) f.name: f.content};

    // 修改这里：将 Uint8List 转换为 String
    final containerXmlBytes = files['META-INF/container.xml'] as Uint8List?;
    if (containerXmlBytes == null) throw Exception('EPUB 缺少 container.xml');
    final containerXml = const Utf8Decoder().convert(containerXmlBytes);

    final opfPath = _getXmlAttributeValue(
      containerXml,
      'rootfile',
      'full-path',
    );
    if (opfPath == null) throw Exception('无法找到 OPF 文件路径');

    // 同样使用 UTF-8 解码 OPF 文件内容
    final opfContentBytes = files[opfPath] as Uint8List?;
    if (opfContentBytes == null) throw Exception('找不到 OPF 文件');
    final opfContent = const Utf8Decoder().convert(opfContentBytes);

    // 解析元数据
    final xmlDoc = XmlDocument.parse(opfContent);
    final metadata = xmlDoc.findAllElements("metadata").first;
    final title = _getXmlTagContent(metadata, 'dc:title');
    final author = _getXmlTagContent(metadata, 'dc:creator');
    final description = _getXmlTagContent(metadata, 'dc:description');
    final publisher = _getXmlTagContent(metadata, 'dc:publisher');
    final language = _getXmlTagContent(metadata, 'dc:language');
    final identifier = _getXmlTagContent(metadata, 'dc:identifier');

    // 获取封面图片
    Uint8List? coverImage;
    final coverPath = _findCoverPath(opfContent);
    if (coverPath != null) {
      final fullCoverPath = _resolvePath(opfPath, coverPath);
      final coverData = files[fullCoverPath];
      if (coverData is Uint8List) {
        coverImage = coverData;
      }
    }

    // 获取章节列表
    final chapters = _getChapterPaths(xmlDoc);

    return EpubMetadata(
      title: title,
      author: author,
      description: description,
      publisher: publisher,
      language: language,
      identifier: identifier,
      coverImage: coverImage,
      chapters: chapters,
    );
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
    if (spine == null) return chapters;

    final manifest = xmlDoc.findAllElements("manifest").first;
    final itemRefs = spine.findElements("itemref");

    for (final ref in itemRefs) {
      final idRef = ref.getAttribute("idref");
      final item = manifest
          .findElements("item")
          .firstWhereOrNull((e) => e.getAttribute("id") == idRef);
      if (item != null) {
        final path = item.getAttribute("href");
        if (path != null) chapters.add(path);
      }
    }
    return chapters;
  }

  /// 解析封面路径
  static String? _findCoverPath(String opfContent) {
    final xmlDoc = XmlDocument.parse(opfContent);
    final manifest = xmlDoc.findAllElements("manifest").first;

    // 方法1：查找带有 properties="cover-image" 的项
    var coverItem = manifest
        .findElements("item")
        .firstWhereOrNull(
          (e) => e.getAttribute("properties")?.contains("cover-image") ?? false,
        );

    // 方法2：查找 id 包含 "cover" 的项
    if (coverItem == null) {
      coverItem = manifest.findElements("item").firstWhereOrNull(
            (e) => e.getAttribute("id")?.toLowerCase().contains("cover") ?? false,
          );
    }

    // 方法3：查找媒体类型为图片且文件名包含 "cover" 的项
    if (coverItem == null) {
      coverItem = manifest.findElements("item").firstWhereOrNull((e) {
        final mediaType = e.getAttribute("media-type") ?? "";
        final href = e.getAttribute("href")?.toLowerCase() ?? "";
        return mediaType.startsWith("image/") && href.contains("cover");
      });
    }

    // 方法4：查找元数据中的封面引用
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

    // 方法5：如果还是没找到，尝试获取第一个图片文件
    if (coverItem == null) {
      coverItem = manifest.findElements("item").firstWhereOrNull(
            (e) => (e.getAttribute("media-type") ?? "").startsWith("image/"),
          );
    }

    return coverItem?.getAttribute("href");
  }

  /// 解析相对路径
  static String _resolvePath(String basePath, String relativePath) {
    final baseDir = basePath.substring(0, basePath.lastIndexOf('/') + 1);
    return baseDir + relativePath;
  }
}
