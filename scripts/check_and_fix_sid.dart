import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'config_parser.dart';
import 'print_utils.dart';

class _MethodInfo {
  final String className;
  final String methodName;

  _MethodInfo(this.className, this.methodName);
}

class SidChecker {
  final String filePath;
  String _content;
  bool _modified = false;

  SidChecker(this.filePath) : _content = File(filePath).readAsStringSync();

  void checkAndFix() {
    try {
      // 解析文件
      final parseResult = parseString(content: _content);
      if (parseResult.errors.isNotEmpty) {
        printError('解析错误: ${parseResult.errors}');
        return;
      }

      // 收集所有需要修改的方法
      final visitor = _MethodVisitor();
      parseResult.unit.accept(visitor);

      if (visitor.methodsToModify.isEmpty) {
        printInfo('文件无需修改: $filePath');
        return;
      }

      // 按位置从后向前排序，这样修改不会影响前面的位置
      visitor.methodsToModify.sort((a, b) => b.offset.compareTo(a.offset));

      // 修改文件内容
      for (final method in visitor.methodsToModify) {
        _modifyMethod(method);
      }

      if (_modified) {
        _saveChanges();
      }
    } catch (e) {
      printError('处理文件时出错: $e');
    }
  }

  void _modifyMethod(MethodInvocation node) {
    final methodInfo = _getMethodInfo(node);
    if (methodInfo == null) return;

    // 检查是否已经有 sid 参数
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'sid') {
        // 如果 sid 值与方法名不匹配，更新它
        final expectedSid = _getExpectedSid(methodInfo);
        if (arg.expression.toString().replaceAll("'", "").replaceAll('"', '') != expectedSid) {
          _updateSidValue(arg, expectedSid);
        }
        return;
      }
    }

    // 没有 sid 参数，添加一个
    final argsPos = _findArgsPosition(node);
    if (argsPos != null) {
      // 在 args 参数前添加 sid
      _insertSidBeforeArgs(node, _getExpectedSid(methodInfo), argsPos);
    } else {
      // 在第一个参数后添加 sid
      _insertSidAfterFirstArg(node, _getExpectedSid(methodInfo));
    }
  }

  String _getExpectedSid(_MethodInfo methodInfo) {
    // 对于 BaseStrings 类，直接使用方法名作为 sid
    if (methodInfo.className == 'basestrings') {
      return methodInfo.methodName;
    }
    // 对于其他类，使用 className_methodName 格式
    return '${methodInfo.className}_${methodInfo.methodName}';
  }

  _MethodInfo? _getMethodInfo(MethodInvocation node) {
    var parent = node.parent;
    String? className;
    String? methodName;

    while (parent != null) {
      if (parent is MethodDeclaration) {
        methodName = parent.name.lexeme;
        // 继续向上查找类名
        var classParent = parent.parent;
        while (classParent != null) {
          if (classParent is ClassDeclaration) {
            className = classParent.name.lexeme.toLowerCase();
            break;
          }
          classParent = classParent.parent;
        }
        break;
      }
      parent = parent.parent;
    }

    if (className == null || methodName == null) {
      return null;
    }

    return _MethodInfo(className, methodName);
  }

  int? _findArgsPosition(MethodInvocation node) {
    for (var i = 0; i < node.argumentList.arguments.length; i++) {
      final arg = node.argumentList.arguments[i];
      if (arg is NamedExpression && arg.name.label.name == 'args') {
        return i;
      }
    }
    return null;
  }

  void _updateSidValue(NamedExpression sidArg, String sid) {
    final start = sidArg.expression.offset;
    final end = sidArg.expression.end;
    final before = _content.substring(0, start);
    final after = _content.substring(end);
    _content = "$before'$sid'$after";
    _modified = true;
    printSuccess('更新 sid 值: $sid');
  }

  void _insertSidBeforeArgs(MethodInvocation node, String sid, int argsPos) {
    final argsArg = node.argumentList.arguments[argsPos];
    final start = argsArg.offset;
    final before = _content.substring(0, start);
    final after = _content.substring(start);
    _content = "${before}sid: '$sid', $after";
    _modified = true;
    printSuccess('添加 sid: $sid');
  }

  void _insertSidAfterFirstArg(MethodInvocation node, String sid) {
    final firstArg = node.argumentList.arguments.first;
    final end = firstArg.end;
    final before = _content.substring(0, end);
    final after = _content.substring(end);
    _content = "$before, sid: '$sid'$after";
    _modified = true;
    printSuccess('添加 sid: $sid');
  }

  void _saveChanges() {
    try {
      // 创建临时文件
      final tempFile = File('$filePath.temp');
      // 写入修改后的内容到临时文件
      tempFile.writeAsStringSync(_content);

      // 删除原文件
      File(filePath).deleteSync();

      // 重命名临时文件为原文件名
      tempFile.renameSync(filePath);

      printSuccess('文件已更新: $filePath');
    } catch (e) {
      printError('保存文件时出错: $e');
      // 如果出错，尝试清理临时文件
      try {
        File('$filePath.temp').deleteSync();
      } catch (_) {}
    }
  }
}

class _MethodVisitor extends GeneralizingAstVisitor<void> {
  final List<MethodInvocation> methodsToModify = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'intlMessage') {
      methodsToModify.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

class _SidVerifier extends GeneralizingAstVisitor<void> {
  int totalMethods = 0;
  int correctMethods = 0;
  int incorrectMethods = 0;
  final List<String> errors = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'intlMessage') {
      totalMethods++;

      // 获取方法信息
      final methodInfo = _getMethodInfo(node);
      if (methodInfo == null) {
        incorrectMethods++;
        errors.add('无法获取方法信息: ${node.toSource()}');
        return;
      }

      final expectedSid = _getExpectedSid(methodInfo);

      // 检查 sid 参数
      bool hasCorrectSid = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'sid') {
          final sidValue = arg.expression.toString().replaceAll("'", "").replaceAll('"', '');
          if (sidValue == expectedSid) {
            hasCorrectSid = true;
            break;
          }
        }
      }

      if (hasCorrectSid) {
        correctMethods++;
      } else {
        incorrectMethods++;
        errors.add('方法 ${methodInfo.methodName} 缺少正确的 sid 参数，期望值: $expectedSid');
      }
    }
    super.visitMethodInvocation(node);
  }

  String _getExpectedSid(_MethodInfo methodInfo) {
    // 对于 BaseStrings 类，直接使用方法名作为 sid
    if (methodInfo.className == 'basestrings') {
      return methodInfo.methodName;
    }
    // 对于其他类，使用 className_methodName 格式
    return '${methodInfo.className}_${methodInfo.methodName}';
  }

  _MethodInfo? _getMethodInfo(MethodInvocation node) {
    var parent = node.parent;
    String? className;
    String? methodName;

    while (parent != null) {
      if (parent is MethodDeclaration) {
        methodName = parent.name.lexeme;
        // 继续向上查找类名
        var classParent = parent.parent;
        while (classParent != null) {
          if (classParent is ClassDeclaration) {
            className = classParent.name.lexeme.toLowerCase();
            break;
          }
          classParent = classParent.parent;
        }
        break;
      }
      parent = parent.parent;
    }

    if (className == null || methodName == null) {
      return null;
    }

    return _MethodInfo(className, methodName);
  }
}

void verifyAllFiles(List<String> filePaths) {
  printStep('VERIFY', '开始验证所有文件...');
  int totalFiles = 0;
  int totalMethods = 0;
  int totalCorrectMethods = 0;
  int totalIncorrectMethods = 0;
  final List<String> allErrors = [];

  for (final filePath in filePaths) {
    try {
      final content = File(filePath).readAsStringSync();
      final parseResult = parseString(content: content);

      if (parseResult.errors.isNotEmpty) {
        throw Exception('文件 $filePath 存在解析错误: ${parseResult.errors}');
      }

      final verifier = _SidVerifier();
      parseResult.unit.accept(verifier);

      totalFiles++;
      totalMethods += verifier.totalMethods;
      totalCorrectMethods += verifier.correctMethods;
      totalIncorrectMethods += verifier.incorrectMethods;
      allErrors.addAll(verifier.errors.map((e) => '[$filePath] $e'));
    } catch (e) {
      throw Exception('验证文件 $filePath 时出错: $e');
    }
  }

  printBold('\n验证结果汇总:');
  printInfo('总文件数: $totalFiles');
  printInfo('总方法数: $totalMethods');
  printSuccess('正确的方法数: $totalCorrectMethods');
  if (totalIncorrectMethods > 0) {
    printError('错误的方法数: $totalIncorrectMethods');
  }

  if (allErrors.isNotEmpty) {
    printWarning('\n错误列表:');
    for (final error in allErrors) {
      printError('- $error');
    }
    throw Exception('发现 $totalIncorrectMethods 个方法存在 sid 参数错误，请修复后重试');
  }
}

void main(List<String> arguments) async {
  try {
    printStep('START', '开始检查和修复 SID 参数');

    // 使用 config_parser 获取 strings 目录路径
    final featuresDir = await I18nConfigParser.getStringsDirPath();

    // 确保目录存在
    if (!Directory(featuresDir).existsSync()) {
      throw Exception('错误: 目录不存在 $featuresDir');
    }

    // 查找所有 *_strings.dart 文件
    final dartFiles =
        Directory(
          featuresDir,
        ).listSync(recursive: true).where((entity) => entity is File && entity.path.endsWith('_strings.dart')).map((entity) => entity.path).toList();

    if (dartFiles.isEmpty) {
      throw Exception('在 $featuresDir 中没有找到 *_strings.dart 文件');
    }

    printInfo('找到 ${dartFiles.length} 个文件需要处理');

    // 处理每个文件
    for (final filePath in dartFiles) {
      printStep('PROCESS', '处理文件: $filePath');
      final checker = SidChecker(filePath);
      checker.checkAndFix();
    }

    // 验证所有文件
    printStep('VERIFY', '验证所有文件');
    verifyAllFiles(dartFiles);

    printSuccess('所有文件验证通过！');
  } catch (e) {
    printError('错误: $e');
    exit(1); // 使用非零退出码表示错误
  }
}
