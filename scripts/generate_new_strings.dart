import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;

import 'config_parser.dart';
import 'print_utils.dart';

class ArbGenerator {
  final Map<String, dynamic> _arbData = {};

  ArbGenerator();

  void processFile(String filePath) {
    try {
      final content = File(filePath).readAsStringSync();
      final parseResult = parseString(content: content);

      if (parseResult.errors.isNotEmpty) {
        throw Exception('解析错误: ${parseResult.errors}');
      }

      final unit = parseResult.unit;
      final visitor = _IntlMessageVisitor();
      unit.accept(visitor);

      // 获取类名
      final classVisitor = _ClassVisitor();
      unit.accept(classVisitor);
      final className = classVisitor.className?.toLowerCase() ?? '';

      for (final method in visitor.methods) {
        _processMethod(method, className);
      }
    } catch (e) {
      throw Exception('处理文件时出错: $e');
    }
  }

  void _processMethod(MethodDeclaration method, String className) {
    if (method.body is ExpressionFunctionBody) {
      _processExpressionBody(method.body as ExpressionFunctionBody);
    } else if (method.body is BlockFunctionBody) {
      _processBlockBody(method.body as BlockFunctionBody);
    }
  }

  void _processExpressionBody(ExpressionFunctionBody body) {
    final expression = body.expression;
    if (expression is MethodInvocation && expression.methodName.name == 'intlMessage') {
      _processIntlMessage(expression);
    }
  }

  void _processBlockBody(BlockFunctionBody body) {
    for (final statement in body.block.statements) {
      if (statement is ReturnStatement) {
        final expression = statement.expression;
        if (expression is MethodInvocation && expression.methodName.name == 'intlMessage') {
          _processIntlMessage(expression);
        }
      }
    }
  }

  void _processIntlMessage(MethodInvocation node) {
    if (node.argumentList.arguments.isEmpty) return;

    // 获取 sid 参数
    final sidArg = node.argumentList.arguments.where((arg) => arg is NamedExpression && arg.name.label.name == 'sid').firstOrNull;

    if (sidArg == null || sidArg is! NamedExpression) {
      throw Exception('intlMessage 方法必须包含 sid 参数');
    }

    final key = sidArg.expression.toString().replaceAll("'", "").replaceAll('"', '');

    final messageArg = node.argumentList.arguments[0];
    String message = messageArg.toString().replaceAll("'", "").replaceAll('"', '');

    // 首先处理转义的 $ 符号，将 \$ 转换为 $
    message = message.replaceAll(r'\$', '\$');

    // 处理参数
    final argsArg = node.argumentList.arguments.where((arg) => arg is NamedExpression && arg.name.label.name == 'args').firstOrNull;

    if (argsArg != null && argsArg is NamedExpression) {
      final argsMap = argsArg.expression;
      if (argsMap is SetOrMapLiteral) {
        for (final entry in argsMap.elements) {
          if (entry is MapLiteralEntry) {
            final key = entry.key.toString().replaceAll("'", "").replaceAll('"', '');
            message = message.replaceAll('\${${entry.value}}', '{$key}');
            message = message.replaceAll('\$${entry.value}', '{$key}');
          }
        }
      }
    }

    _arbData[key] = message;
  }

  void saveArbFile(String outputPath) {
    final jsonString = JsonEncoder.withIndent('  ').convert(_arbData);
    File(outputPath).writeAsStringSync(jsonString);
  }
}

class _IntlMessageVisitor extends GeneralizingAstVisitor<void> {
  final List<MethodDeclaration> methods = [];

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (_containsIntlMessage(node)) {
      methods.add(node);
    }
    super.visitMethodDeclaration(node);
  }

  bool _containsIntlMessage(MethodDeclaration node) {
    if (node.body is ExpressionFunctionBody) {
      final expression = (node.body as ExpressionFunctionBody).expression;
      return expression is MethodInvocation && expression.methodName.name == 'intlMessage';
    } else if (node.body is BlockFunctionBody) {
      final statements = (node.body as BlockFunctionBody).block.statements;
      for (final statement in statements) {
        if (statement is ReturnStatement) {
          final expression = statement.expression;
          if (expression is MethodInvocation && expression.methodName.name == 'intlMessage') {
            return true;
          }
        }
      }
    }
    return false;
  }
}

class _ClassVisitor extends GeneralizingAstVisitor<void> {
  String? className;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    className = node.name.lexeme;
    super.visitClassDeclaration(node);
  }
}

void main() async {
  try {
    printStep('ARB_GEN', '开始生成 ARB 文件');

    // 使用公共配置解析器获取 strings 目录路径
    final featuresDir = await I18nConfigParser.getStringsDirPath();

    // 获取项目根目录，然后构建 build 目录路径
    final projectRoot = await I18nConfigParser.getProjectRoot();
    final outputDir = path.join(projectRoot, 'build', 'localizations', 'arb');

    // 检查 featuresDir 是否存在
    final featuresDirectory = Directory(featuresDir);
    if (!featuresDirectory.existsSync()) {
      throw Exception('目录不存在: $featuresDir');
    }

    // 创建输出目录
    final outputDirectory = Directory(outputDir);
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
    }

    // 处理所有 strings 文件
    featuresDirectory.listSync().where((entity) => entity.path.endsWith('_strings.dart')).forEach((entity) {
      if (entity is File) {
        final arbGenerator = ArbGenerator();
        arbGenerator.processFile(entity.path);

        final outputPath = path.join(outputDir, '${path.basenameWithoutExtension(entity.path)}.arb');
        arbGenerator.saveArbFile(outputPath);
        printSuccess('已生成 ARB 文件: $outputPath');
      }
    });

    printSuccess('ARB 文件生成完成！');
  } catch (e) {
    printError('错误: $e');
    exit(1);
  }
}
