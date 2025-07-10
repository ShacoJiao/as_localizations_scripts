import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// 国际化配置解析器
class I18nConfigParser {
  static Map<String, dynamic>? _config;
  static String? _projectRoot;

  /// 获取项目根目录路径
  static Future<String> getProjectRoot() async {
    if (_projectRoot != null) {
      return _projectRoot!;
    }

    // 从当前脚本位置向上查找，直到找到包含as_i18n.yaml的目录
    var currentDir = Directory.current;
    while (currentDir.path != currentDir.parent.path) {
      final yamlFile = File(path.join(currentDir.path, 'as_i18n.yaml'));
      if (yamlFile.existsSync()) {
        _projectRoot = currentDir.path;
        return _projectRoot!;
      }
      currentDir = currentDir.parent;
    }
    throw Exception('无法找到项目根目录（包含as_i18n.yaml的目录）');
  }

  /// 加载配置文件
  static Future<Map<String, dynamic>> loadConfig() async {
    if (_config != null) {
      return _config!;
    }

    final projectRoot = await getProjectRoot();
    final yamlFile = File(path.join(projectRoot, 'as_i18n.yaml'));

    if (!yamlFile.existsSync()) {
      throw Exception('找不到 as_i18n.yaml 配置文件');
    }

    final yamlContent = yamlFile.readAsStringSync();
    final yamlMap = loadYaml(yamlContent);

    // 将 YamlMap 转换为 Map<String, dynamic>
    _config = Map<String, dynamic>.from(yamlMap);
    return _config!;
  }

  /// 获取 i18n-dir 配置
  static Future<String> getI18nDir() async {
    final config = await loadConfig();
    final i18nDir = config['i18n-dir'] as String?;
    if (i18nDir == null) {
      throw Exception('as_i18n.yaml 文件中缺少 i18n-dir 配置');
    }
    return i18nDir;
  }

  /// 获取完整的 i18n 目录路径
  static Future<String> getI18nDirPath() async {
    final projectRoot = await getProjectRoot();
    final i18nDir = await getI18nDir();
    return path.join(projectRoot, i18nDir);
  }

  /// 获取 strings 目录路径
  static Future<String> getStringsDirPath() async {
    final i18nDirPath = await getI18nDirPath();
    return path.join(i18nDirPath, 'strings');
  }

  /// 获取 template-json-file 配置
  static Future<String> getTemplateJsonFile() async {
    final config = await loadConfig();
    final templateJsonFile = config['template-json-file'] as String?;
    if (templateJsonFile == null) {
      throw Exception('as_i18n.yaml 文件中缺少 template-json-file 配置');
    }
    return templateJsonFile;
  }

  /// 获取完整的 template-json-file 路径
  static Future<String> getTemplateJsonPath() async {
    final i18nDirPath = await getI18nDirPath();
    final templateJsonFile = await getTemplateJsonFile();
    return path.join(i18nDirPath, templateJsonFile);
  }

  /// 获取 output-localization-file 配置
  static Future<String> getOutputLocalizationFile() async {
    final config = await loadConfig();
    final outputLocalizationFile = config['output-localization-file'] as String?;
    if (outputLocalizationFile == null) {
      throw Exception('as_i18n.yaml 文件中缺少 output-localization-file 配置');
    }
    return outputLocalizationFile;
  }

  /// 获取完整的 output-localization-file 路径
  static Future<String> getOutputLocalizationPath() async {
    final i18nDirPath = await getI18nDirPath();
    final outputLocalizationFile = await getOutputLocalizationFile();
    return path.join(i18nDirPath, outputLocalizationFile);
  }

  /// 获取 locales 配置
  static Future<List<String>> getLocales() async {
    final config = await loadConfig();
    final locales = config['locales'] as List?;
    if (locales == null) {
      throw Exception('as_i18n.yaml 文件中缺少 locales 配置');
    }
    return locales.cast<String>();
  }

  /// 获取 feature-strings 配置
  static Future<Map<String, String>> getFeatureStrings() async {
    final config = await loadConfig();
    final featureStrings = config['feature-strings'] as Map?;
    if (featureStrings == null) {
      throw Exception('as_i18n.yaml 文件中缺少 feature-strings 配置');
    }
    return Map<String, String>.from(featureStrings);
  }

  /// 获取 lingo 配置
  static Future<Map<String, dynamic>> getLingoConfig() async {
    final config = await loadConfig();
    final lingo = config['lingo'] as Map?;
    if (lingo == null) {
      throw Exception('as_i18n.yaml 文件中缺少 lingo 配置');
    }
    return Map<String, dynamic>.from(lingo);
  }

  /// 检查目录是否存在，如果不存在则创建
  static Future<void> ensureDirectoryExists(String dirPath) async {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return file.existsSync();
  }
}
