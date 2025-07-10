#!/usr/bin/env dart

import 'dart:io';

import 'config_parser.dart';
import 'print_utils.dart';

/// 国际化文件清理器
class I18nCleaner {
  /// 清理国际化相关文件
  static Future<void> clean() async {
    printStep('CLEAN', '开始清理国际化文件...');

    try {
      int cleanedCount = 0;

      // 清理 strings 文件夹
      final stringsDirPath = await I18nConfigParser.getStringsDirPath();
      cleanedCount += await _cleanStringsDirectory(stringsDirPath);

      // 清理输出文件
      final outputPath = await I18nConfigParser.getOutputLocalizationPath();
      cleanedCount += await _cleanOutputFile(outputPath);

      printSuccess('清理完成！共清理了 $cleanedCount 个文件/文件夹');
    } catch (e) {
      printError('清理过程中出现错误: $e');
      exit(1);
    }
  }

  /// 清理 strings 目录
  static Future<int> _cleanStringsDirectory(String stringsDirPath) async {
    final stringsDir = Directory(stringsDirPath);

    if (!stringsDir.existsSync()) {
      printInfo('strings 文件夹不存在: $stringsDirPath');
      return 0;
    }

    int cleanedCount = 0;

    try {
      // 获取目录中的所有文件和子目录
      final entities = stringsDir.listSync();

      for (final entity in entities) {
        if (entity is File) {
          await entity.delete();
          printWarning('已删除文件: ${entity.path}');
          cleanedCount++;
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
          printWarning('已删除文件夹: ${entity.path}');
          cleanedCount++;
        }
      }

      // 删除空的 strings 文件夹
      await stringsDir.delete();
      printWarning('已删除空文件夹: $stringsDirPath');
    } catch (e) {
      printError('清理 strings 文件夹失败: $e');
      rethrow;
    }

    return cleanedCount;
  }

  /// 清理输出文件
  static Future<int> _cleanOutputFile(String outputPath) async {
    final outputFile = File(outputPath);

    if (!outputFile.existsSync()) {
      printInfo('输出文件不存在: $outputPath');
      return 0;
    }

    try {
      await outputFile.delete();
      printWarning('已删除文件: $outputPath');
      return 1;
    } catch (e) {
      printError('删除输出文件失败: $e');
      rethrow;
    }
  }
}

/// 主函数
void main() async {
  await I18nCleaner.clean();
}
