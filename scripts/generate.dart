import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'config_parser.dart';
import 'print_utils.dart';

void main() async {
  try {
    // 获取项目根目录路径
    final projectRoot = await I18nConfigParser.getProjectRoot();
    printInfo('项目根目录: $projectRoot');

    // 加载配置
    final config = await I18nConfigParser.loadConfig();

    // 将生成的文件添加到.gitignore中
    await _addToGitignore(projectRoot, config);

    printStep('GENERATE', '开始生成文件...');

    // 1. 根据i18n-dir的值，在主项目根目录下生成文件夹
    final i18nDirPath = await I18nConfigParser.getI18nDirPath();
    await I18nConfigParser.ensureDirectoryExists(i18nDirPath);
    printSuccess('创建目录: ${await I18nConfigParser.getI18nDir()}');

    // 2. 在i18n-dir对应文件夹下，如果没有template-json-file的文件，就创建
    final templateJsonPath = await I18nConfigParser.getTemplateJsonPath();
    await _createTemplateJsonFile(templateJsonPath);
    printSuccess('处理模板JSON文件: ${await I18nConfigParser.getTemplateJsonFile()}');

    // 3. 根据template-json-file和feature-strings配置生成strings文件
    final featureStrings = await I18nConfigParser.getFeatureStrings();
    await _generateStringsFiles(templateJsonPath, i18nDirPath, featureStrings);
    printSuccess('生成strings文件完成');

    // 4. 根据output-localization-file生成最终的本地化文件
    final outputLocalizationPath = await I18nConfigParser.getOutputLocalizationPath();
    final outputLocalizationFile = await I18nConfigParser.getOutputLocalizationFile();
    await _generateLocalizationsFile(outputLocalizationPath, outputLocalizationFile, featureStrings);
    printSuccess('生成本地化文件: $outputLocalizationFile');

    // 4.5. 生成 localizations.dart 导出文件
    await _generateLocalizationsExportFile(i18nDirPath, featureStrings);
    printSuccess('生成导出文件: localizations.dart');

    // 5. 格式化生成的代码
    await _formatGeneratedCode(i18nDirPath);
    printSuccess('格式化代码完成');

    printSuccess('所有文件生成完成！');
  } catch (e) {
    printError('错误: $e');
    exit(1);
  }
}

/// 创建模板JSON文件
Future<void> _createTemplateJsonFile(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    // 创建基本的JSON模板
    final templateJson = {'commonstrings_ok': '好的', 'appstrings_spot': '资产'};

    await file.writeAsString(JsonEncoder.withIndent('  ').convert(templateJson));
  }
}

/// 生成strings文件
Future<void> _generateStringsFiles(String jsonPath, String i18nDirPath, Map<String, String> featureStrings) async {
  // 读取JSON文件
  final jsonFile = File(jsonPath);
  if (!jsonFile.existsSync()) {
    printError('错误: 找不到JSON文件: $jsonPath');
    return;
  }

  final jsonContent = jsonFile.readAsStringSync();
  final jsonData = json.decode(jsonContent) as Map<String, dynamic>;

  // 创建strings目录
  final stringsDir = path.join(i18nDirPath, 'strings');
  await I18nConfigParser.ensureDirectoryExists(stringsDir);

  // 收集所有已声明的前缀
  final declaredPrefixes = <String>{};
  for (final entry in featureStrings.entries) {
    final fileName = entry.value;
    // 根据 yaml value 生成前缀用于匹配 json key
    final prefix = _getPrefixForMatching(fileName);
    declaredPrefixes.add(prefix);
  }

  // 为每个feature生成对应的strings文件
  for (final entry in featureStrings.entries) {
    final featureName = entry.key;
    final fileName = entry.value;

    await _generateFeatureStringsFile(stringsDir, featureName, fileName, jsonData);
  }

  // 生成base_strings.dart文件，包含未声明的键值对
  await _generateBaseStringsFile(stringsDir, jsonData, declaredPrefixes);

  // 生成strings.dart导出文件
  await _generateStringsExportFile(stringsDir, featureStrings);

  // 生成strings_mixin.dart文件
  await _generateStringsMixinFile(stringsDir);
}

/// 生成特定feature的strings文件
Future<void> _generateFeatureStringsFile(String stringsDir, String featureName, String fileName, Map<String, dynamic> jsonData) async {
  // 1. 根据 yaml value 生成文件名和类名
  // 文件名：{value}.dart
  final fileNameWithExtension = fileName.endsWith('.dart') ? fileName : fileName + '.dart';

  // 类名：{value} 驼峰并去掉下划线
  final className = _fileNameToClassName(fileName);

  final filePath = path.join(stringsDir, fileNameWithExtension);

  // 2. 匹配 json key 前缀：{value}去掉下划线然后全小写加下划线开头
  // 例如：app_strings -> appstrings_
  final prefixForMatching = _getPrefixForMatching(fileName);

  // 过滤出以prefixForMatching开头的键值对
  final featureData = <String, String>{};
  for (final entry in jsonData.entries) {
    if (entry.key.startsWith(prefixForMatching)) {
      featureData[entry.key] = entry.value as String;
    }
  }

  if (featureData.isEmpty) {
    // 如果没有数据，创建空的类文件
    final content = '''import 'strings_mixin.dart';

class $className with MixinStrings {
  // 暂无数据
}
''';
    await File(filePath).writeAsString(content);
    return;
  }

  // 生成类内容
  final buffer = StringBuffer();
  buffer.writeln("import 'strings_mixin.dart';");
  buffer.writeln();
  buffer.writeln('class $className with MixinStrings {');

  for (final entry in featureData.entries) {
    final key = entry.key;
    final value = entry.value;

    // 从key中提取方法名（去掉prefixForMatching）
    final methodName = key.substring(prefixForMatching.length);

    // 检查是否包含参数（通过检查值中是否有{}）
    if (value.contains('{') && value.contains('}')) {
      // 有参数的方法
      final args = _extractArgs(value);
      final argsList = args.map((arg) => 'Object $arg').join(', ');
      final argsMap = args.map((arg) => "'$arg': $arg").join(', ');

      // 将JSON格式的{xxx}转换为Dart格式的$xxx
      final dartValue = _convertToDartString(value);

      buffer.writeln('  String $methodName($argsList) {');
      buffer.writeln("    return intlMessage('$dartValue', sid: '$key', args: {$argsMap});");
      buffer.writeln('  }');
    } else {
      // 简单的getter
      final dartValue = _convertToDartString(value);
      buffer.writeln("  String get $methodName => intlMessage('$dartValue', sid: '$key');");
    }
    buffer.writeln();
  }

  buffer.writeln('}');

  await File(filePath).writeAsString(buffer.toString());
}

/// 根据 yaml value 生成用于匹配 json key 的前缀
/// 例如：app_strings -> appstrings_
/// buy_crypto_strings -> buycryptostrings_
String _getPrefixForMatching(String value) {
  // 去掉 .dart 后缀（如果有）
  final nameWithoutExtension = value.replaceAll('.dart', '');

  // 去掉下划线，全小写，然后加下划线
  final prefix = nameWithoutExtension.replaceAll('_', '').toLowerCase() + '_';

  return prefix;
}

/// 从字符串中提取参数名（去重并保持顺序）
List<String> _extractArgs(String text) {
  final regex = RegExp(r'\{([^}]+)\}');
  final matches = regex.allMatches(text);
  final args = <String>[];
  final seenArgs = <String>{};

  for (final match in matches) {
    final arg = match.group(1)!;
    if (!seenArgs.contains(arg)) {
      seenArgs.add(arg);
      args.add(arg);
    }
  }

  return args;
}

/// 生成base_strings.dart文件，包含未声明的键值对
Future<void> _generateBaseStringsFile(String stringsDir, Map<String, dynamic> jsonData, Set<String> declaredPrefixes) async {
  final filePath = path.join(stringsDir, 'base_strings.dart');

  // 过滤出未声明的键值对
  final baseData = <String, String>{};
  for (final entry in jsonData.entries) {
    final key = entry.key;
    final value = entry.value as String;

    // 检查这个key是否属于任何已声明的前缀
    bool isDeclared = false;
    for (final prefix in declaredPrefixes) {
      // declaredPrefixes 现在存储的是基于 yaml value 生成的前缀（如 appstrings_）
      if (key.startsWith(prefix)) {
        isDeclared = true;
        break;
      }
    }

    // 如果不在任何已声明的前缀中，则添加到base数据中
    if (!isDeclared) {
      baseData[key] = value;
    }
  }

  if (baseData.isEmpty) {
    // 如果没有数据，创建空的类文件
    final content = '''import 'strings_mixin.dart';

class BaseStrings with MixinStrings {
  // 暂无数据
}
''';
    await File(filePath).writeAsString(content);
    return;
  }

  // 生成类内容
  final buffer = StringBuffer();
  buffer.writeln("import 'strings_mixin.dart';");
  buffer.writeln();
  buffer.writeln('class BaseStrings with MixinStrings {');

  for (final entry in baseData.entries) {
    final key = entry.key;
    final value = entry.value;

    // 检查是否包含参数（通过检查值中是否有{}）
    if (value.contains('{') && value.contains('}')) {
      // 有参数的方法
      final args = _extractArgs(value);
      final argsList = args.map((arg) => 'Object $arg').join(', ');
      final argsMap = args.map((arg) => "'$arg': $arg").join(', ');

      // 将JSON格式的{xxx}转换为Dart格式的$xxx
      final dartValue = _convertToDartString(value);

      buffer.writeln('  String $key($argsList) {');
      buffer.writeln("    return intlMessage('$dartValue', sid: '$key', args: {$argsMap});");
      buffer.writeln('  }');
    } else {
      // 简单的getter
      final dartValue = _convertToDartString(value);
      buffer.writeln("  String get $key => intlMessage('$dartValue', sid: '$key');");
    }
    buffer.writeln();
  }

  buffer.writeln('}');

  await File(filePath).writeAsString(buffer.toString());
}

/// 生成strings.dart导出文件
Future<void> _generateStringsExportFile(String stringsDir, Map<String, String> featureStrings) async {
  final filePath = path.join(stringsDir, 'strings.dart');
  final buffer = StringBuffer();

  // 收集所有需要导出的文件名
  final exportFiles = <String>[];

  // 添加base_strings.dart
  exportFiles.add('base_strings.dart');

  // 添加其他feature strings文件
  for (final entry in featureStrings.entries) {
    final fileName = entry.value;
    // 确保文件名有 .dart 扩展名
    final fileNameWithExtension = fileName.endsWith('.dart') ? fileName : '${fileName}.dart';
    exportFiles.add(fileNameWithExtension);
  }

  // 按字母顺序排序
  exportFiles.sort();

  // 生成export语句
  for (final file in exportFiles) {
    buffer.writeln("export '$file';");
  }

  await File(filePath).writeAsString(buffer.toString());
}

/// 生成strings_mixin.dart文件
Future<void> _generateStringsMixinFile(String stringsDir) async {
  final filePath = path.join(stringsDir, 'strings_mixin.dart');
  final content = '''import 'package:localizations_sdk/localizations_sdk.dart';

mixin MixinStrings {
  String intlMessage(String messageText, {required String sid, Map<String, Object>? args}) {
    return TranslatorApiAccess.instance.translator.translate(defaultEn: messageText, sid: sid, args: args);
  }
}
''';

  await File(filePath).writeAsString(content);
}

/// 生成本地化文件
Future<void> _generateLocalizationsFile(String filePath, String fileName, Map featureStrings) async {
  final file = File(filePath);

  // 从文件名生成类名（去掉 .dart 扩展名，转换为驼峰命名）
  final className = _fileNameToClassName(fileName);

  // 生成所有getter，按字母顺序排序
  final getters = <MapEntry<String, String>>[];

  // 添加base getter
  getters.add(MapEntry('base', 'BaseStrings'));

  // 添加其他feature getters
  for (final entry in featureStrings.entries) {
    final featureName = entry.key as String;
    final fileName = entry.value as String;
    // 根据文件名生成类名，例如：buy_crypto_strings -> BuyCryptoStrings
    final className = _fileNameToClassName(fileName);
    getters.add(MapEntry(featureName, className));
  }

  // 按字母顺序排序
  getters.sort((a, b) => a.key.compareTo(b.key));

  // 生成getter字符串
  final gettersString = getters.map((getter) => '  ${getter.value} get ${getter.key} => ${getter.value}();').join('\n\n');

  // 生成 supportedLocales 方法
  final supportedLocalesBuffer = StringBuffer();
  await _generateSupportedLocalesMethod(supportedLocalesBuffer);
  final supportedLocalesString = supportedLocalesBuffer.toString().trim();

  final buffer = StringBuffer();
  buffer.writeln("import 'package:flutter/foundation.dart';");
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln("import 'package:localizations_sdk/localizations_sdk.dart';");
  buffer.writeln();
  buffer.writeln("import 'strings/strings.dart';");
  buffer.writeln();

  // 生成 AppLocalizationsDelegate 类
  buffer.writeln('''class ${className}Delegate extends LocalizationsDelegate<LocalizationsSdk> {
  bool _loadAlreadyInvoked = false;

  ${className}Delegate();

  @override
  bool isSupported(Locale locale) => $className.supportedLocales().contains(locale);

  @override
  Future<LocalizationsSdk> load(Locale locale) {
    if (!_loadAlreadyInvoked) {
      _loadAlreadyInvoked = true;

      final lastLoadedLocalizationsSdk = LocalizationsSdk.lastLoadedLocalizationsSdk;
      if (lastLoadedLocalizationsSdk != null && lastLoadedLocalizationsSdk.locale == locale) {
        return SynchronousFuture<LocalizationsSdk>(lastLoadedLocalizationsSdk);
      }
    }

    return LocalizationsSdk.load(locale);
  }

  @override
  bool shouldReload(LocalizationsDelegate<LocalizationsSdk> old) => false;
}

extension $className on LocalizationsSdk {
$supportedLocalesString

$gettersString
}''');

  await file.writeAsString(buffer.toString());
}

/// 将文件名转换为驼峰命名的类名
String _fileNameToClassName(String fileName) {
  // 去掉 .dart 扩展名
  final nameWithoutExtension = fileName.replaceAll('.dart', '');

  // 将下划线转换为驼峰命名
  return _toCamelCase(nameWithoutExtension);
}

/// 生成 supportedLocales 方法
Future<void> _generateSupportedLocalesMethod(StringBuffer buffer) async {
  try {
    final locales = await I18nConfigParser.getLocales();

    buffer.writeln('  static List<Locale> supportedLocales() {');
    buffer.writeln('    return [');

    for (int i = 0; i < locales.length; i++) {
      final locale = locales[i];
      final localeCode = _convertLocaleStringToLocaleCode(locale);
      buffer.writeln('      $localeCode,');
    }

    buffer.writeln('    ];');
    buffer.writeln('  }');
  } catch (e) {
    printError('警告: 无法生成 supportedLocales 方法: $e');
    // 如果无法获取配置，生成一个默认的空方法
    buffer.writeln('  /// 从 as_i18n.yaml 配置中获取支持的语言列表');
    buffer.writeln('  List<Locale> getSupportedLocales() {');
    buffer.writeln('    return [];');
    buffer.writeln('  }');
  }
}

/// 将 locale 字符串转换为 Flutter Locale 代码
String _convertLocaleStringToLocaleCode(String localeString) {
  // 解析 locale 字符串，支持以下格式：
  // - en_US -> Locale('en', 'US')
  // - zh_Hans_CN -> Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')
  // - zh_Hant_HK -> Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK')

  final parts = localeString.split('_');
  if (parts.length == 2) {
    // 格式: en_US
    final languageCode = parts[0];
    final countryCode = parts[1];
    return "Locale('$languageCode', '$countryCode')";
  } else if (parts.length == 3) {
    // 格式: zh_Hans_CN 或 zh_Hant_HK
    final languageCode = parts[0];
    final scriptCode = parts[1];
    final countryCode = parts[2];
    return "Locale.fromSubtags(languageCode: '$languageCode', scriptCode: '$scriptCode', countryCode: '$countryCode')";
  } else {
    // 格式: en (只有语言代码)
    return "Locale('$localeString')";
  }
}

/// 将下划线命名转换为驼峰命名
String _toCamelCase(String input) {
  final parts = input.split('_');
  if (parts.isEmpty) return input;

  final result = parts
      .map((part) {
        if (part.isEmpty) return part;
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      })
      .join('');

  return result;
}

/// 将JSON格式的{xxx}转换为Dart格式的$xxx
String _convertToDartString(String jsonString) {
  // 先使用jsonEncode来正确处理所有转义字符，然后去掉首尾的引号
  final encoded = json.encode(jsonString);
  final escapedString = encoded.substring(1, encoded.length - 1);

  // 最后将剩余的$符号转义为\$，避免Dart将其解释为字符串插值
  final replaceResult = escapedString.replaceAll('\$', '\\\$');

  // 然后处理参数占位符，将{xxx}转换为$xxx
  final result = replaceResult.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) {
    final arg = match.group(1)!;
    return '\$$arg';
  });

  return result;
}

/// 格式化生成的代码
Future<void> _formatGeneratedCode(String dirPath) async {
  try {
    final result = await Process.run('dart', ['format', '-l', '150', dirPath]);
    if (result.exitCode != 0) {
      printError('警告: 代码格式化失败: ${result.stderr}');
    }
  } catch (e) {
    printError('警告: 无法执行dart format命令: $e');
  }
}

/// 将生成的文件添加到.gitignore中
Future<void> _addToGitignore(String projectRoot, Map config) async {
  final gitignoreFile = File(path.join(projectRoot, '.gitignore'));
  if (!gitignoreFile.existsSync()) {
    await gitignoreFile.create(recursive: true);
  }

  final gitignoreContent = gitignoreFile.readAsStringSync();
  final gitignoreLines = gitignoreContent.split('\n');

  final i18nDir = config['i18n-dir'] as String;
  final outputLocalizationFile = config['output-localization-file'] as String;

  // 智能拼接路径，确保只有一个/
  final i18nDirNormalized = i18nDir.endsWith('/') ? i18nDir : '$i18nDir/';
  final stringsDirPath = '${i18nDirNormalized}strings/';
  final outputLocalizationPath = '${i18nDirNormalized}$outputLocalizationFile';

  final newLines = <String>[];

  // 检查并添加strings文件夹
  if (!gitignoreLines.contains(stringsDirPath)) {
    newLines.add(stringsDirPath);
  }

  // 检查并添加output-localization-file
  if (!gitignoreLines.contains(outputLocalizationPath)) {
    newLines.add(outputLocalizationPath);
  }

  final localiationsFile = '${i18nDirNormalized}localizations.dart';
  if (!gitignoreLines.contains(localiationsFile)) {
    newLines.add(localiationsFile);
  }

  // 如果有新的行需要添加，则写入.gitignore文件
  if (newLines.isNotEmpty) {
    final updatedContent = gitignoreContent + '\n' + newLines.join('\n');
    await gitignoreFile.writeAsString(updatedContent);
    printSuccess('已将以下路径添加到 .gitignore:');
    for (final line in newLines) {
      printSuccess('  - $line');
    }
  }
}

/// 生成 localizations.dart 导出文件
Future<void> _generateLocalizationsExportFile(String i18nDirPath, Map featureStrings) async {
  final filePath = path.join(i18nDirPath, 'localizations.dart');

  // 获取输出文件名并生成类名
  final outputFileName = await I18nConfigParser.getOutputLocalizationFile();
  final className = _fileNameToClassName(outputFileName);

  final buffer = StringBuffer();

  buffer.writeln("export '${outputFileName}';");
  buffer.writeln("export 'strings/strings.dart';");

  await File(filePath).writeAsString(buffer.toString());
}
