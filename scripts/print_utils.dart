import 'dart:io';

// ANSI 颜色代码 - 与 Python print_utils.py 保持一致
class Colors {
  // 基础颜色
  static const String reset = '\x1B[0m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String white = '\x1B[37m';

  // 样式
  static const String bold = '\x1B[1m';
  static const String dim = '\x1B[2m';
  static const String italic = '\x1B[3m';
  static const String underline = '\x1B[4m';
}

// 彩色输出函数 - 与 Python 版本保持一致
void printStep(String step, String message) {
  stdout.writeln('\n');
  stdout.writeln('++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
  stdout.writeln('${Colors.cyan}[$step]${Colors.reset} $message');
}

void printInfo(String message) {
  stdout.writeln('${Colors.blue}[INFO]${Colors.reset} $message');
}

void printSuccess(String message) {
  stdout.writeln('${Colors.green}[SUCCESS]${Colors.reset} $message');
}

void printError(String message) {
  stdout.writeln('${Colors.red}[ERROR]${Colors.reset} $message');
}

void printWarning(String message) {
  stdout.writeln('${Colors.yellow}[WARNING]${Colors.reset} $message');
}

// 额外的实用函数
void printBold(String message) {
  stdout.writeln('${Colors.bold}$message${Colors.reset}');
}

void printDim(String message) {
  stdout.writeln('${Colors.dim}$message${Colors.reset}');
}

void printCyan(String message) {
  stdout.writeln('${Colors.cyan}$message${Colors.reset}');
}

void printMagenta(String message) {
  stdout.writeln('${Colors.magenta}$message${Colors.reset}');
}
