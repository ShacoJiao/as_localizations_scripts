import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'config_parser.dart';
import 'print_utils.dart';

/// 生成缺失的 ARB 文件
class ArbFileGenerator {
  /// 生成所有缺失的 ARB 文件
  static Future<void> generateArbFiles() async {
    try {
      // 获取语言列表
      final locales = await I18nConfigParser.getLocales();
      if (locales.isEmpty) {
        printError('无法获取语言列表');
        return;
      }

      // 获取项目根目录
      final projectRoot = await I18nConfigParser.getProjectRoot();

      // 生成 intl_list.txt 文件
      await _generateIntlListFile(projectRoot, locales);

      // 为主项目生成 ARB 文件
      await _generateMainProjectArbFiles(projectRoot, locales);

      // 清理不在 locales 配置中的 ARB 文件
      await _cleanupUnusedArbFiles(projectRoot, locales);
    } catch (e) {
      printError('生成 ARB 文件时出错: $e');
    }
  }

  /// 生成 intl_list.txt 文件
  static Future<void> _generateIntlListFile(String projectRoot, List<String> locales) async {
    final intlListFile = path.join(projectRoot, 'assets', 'translations', 'intl_list.txt');

    // 确保目录存在
    final dir = Directory(path.dirname(intlListFile));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    try {
      // 写入 locales 列表，每行一个
      final content = locales.join('\n');
      final file = File(intlListFile);
      await file.writeAsString(content, encoding: utf8);

      printSuccess('已生成 intl_list.txt 文件: $intlListFile');
    } catch (e) {
      printError('无法生成 intl_list.txt 文件: $intlListFile, 错误: $e');
    }
  }

  /// 为主项目生成 ARB 文件
  static Future<void> _generateMainProjectArbFiles(String projectRoot, List<String> locales) async {
    final mainTranslationsDir = path.join(projectRoot, 'assets', 'translations');

    // 确保主项目的 translations 目录存在
    await I18nConfigParser.ensureDirectoryExists(mainTranslationsDir);

    printInfo('为主项目生成 ARB 文件...');
    for (final locale in locales) {
      await _generateArbFile(mainTranslationsDir, locale);
    }
  }

  /// 清理不在 locales 配置中的 ARB 文件
  static Future<void> _cleanupUnusedArbFiles(String projectRoot, List<String> locales) async {
    final mainTranslationsDir = path.join(projectRoot, 'assets', 'translations');

    final directory = Directory(mainTranslationsDir);
    if (!directory.existsSync()) {
      return; // 目录不存在，无需清理
    }

    try {
      final files = await directory.list().toList();

      for (final entity in files) {
        if (entity is File) {
          final fileName = path.basename(entity.path);

          // 检查是否是 ARB 文件
          if (fileName.startsWith('intl_') && fileName.endsWith('.arb')) {
            // 提取语言代码
            final locale = fileName.substring(5, fileName.length - 4); // 去掉 'intl_' 前缀和 '.arb' 后缀

            // 如果语言代码不在 locales 配置中，删除文件
            if (!locales.contains(locale)) {
              await entity.delete();
              printWarning('已删除未使用的 ARB 文件: ${entity.path}');
            }
          }
        }
      }
    } catch (e) {
      printError('清理未使用的 ARB 文件时出错: $e');
    }
  }

  /// 为指定语言生成 ARB 文件
  static Future<void> _generateArbFile(String translationsDir, String locale) async {
    final arbFile = path.join(translationsDir, 'intl_$locale.arb');

    // 如果文件已存在，跳过
    if (await I18nConfigParser.fileExists(arbFile)) {
      return;
    }

    try {
      // 创建 ARB 文件内容
      final arbContent = {'@@locale': locale};

      // 写入文件
      final file = File(arbFile);
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(arbContent), encoding: utf8);

      printSuccess('已创建缺失 ARB 文件: $arbFile');
    } catch (e) {
      printError('无法生成 ARB 文件: $arbFile, 错误: $e');
    }
  }
}

/// 主函数
void main() async {
  printStep('ARB', '开始生成缺失的 ARB 文件');
  await ArbFileGenerator.generateArbFiles();
  printSuccess('ARB 文件生成完成！');
}
