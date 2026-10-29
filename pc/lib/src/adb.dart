import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Результат одной команды adb.
class AdbResult {
  const AdbResult(this.code, this.out, {this.timedOut = false, this.cancelled = false});
  final int code;
  final String out;
  final bool timedOut, cancelled;
  bool get ok => code == 0 && !timedOut && !cancelled;
  @override
  String toString() => 'AdbResult($code, ${out.length} симв.${timedOut ? ', таймаут' : ''})';
}

/// Отмена текущей операции: убивает выполняющийся процесс adb и останавливает цикл.
class CancelToken {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  final _procs = <Process>{};
  void cancel() {
    _cancelled = true;
    for (final p in _procs.toList()) {
      p.kill();
    }
  }
}

class Cancelled implements Exception {
  @override
  String toString() => 'Операция отменена';
}

/// Исполнитель команд adb (настоящий — процесс adb.exe, в тестах — фейк).
abstract class AdbExec {
  Future<AdbResult> run(List<String> args, {Duration timeout, CancelToken? ct});
}

class ProcessAdb implements AdbExec {
  ProcessAdb([String? exe]) : exe = exe ?? locate();
  final String exe;

  /// adb.exe лежит рядом с программой в папке adb\ (из комплекта Google platform-tools).
  static String locate() {
    final dir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    for (final c in ['$dir${sep}adb${sep}adb${Platform.isWindows ? '.exe' : ''}', '$dir${sep}adb${Platform.isWindows ? '.exe' : ''}']) {
      if (File(c).existsSync()) return c;
    }
    final home = Platform.environment['ANDROID_HOME'];
    if (home != null && File('$home${sep}platform-tools${sep}adb').existsSync()) return '$home${sep}platform-tools${sep}adb';
    return Platform.isWindows ? 'adb.exe' : 'adb';
  }

  @override
  Future<AdbResult> run(List<String> args, {Duration timeout = const Duration(seconds: 20), CancelToken? ct}) async {
    if (ct?.cancelled == true) return const AdbResult(-5, 'Отменено', cancelled: true);
    final Process p;
    try {
      p = await Process.start(exe, args);
    } catch (e) {
      return AdbResult(-1, 'Не удалось запустить adb ($exe): $e');
    }
    ct?._procs.add(p);
    final buf = StringBuffer();
    // Не ждём закрытия stdout: при первом запуске adb-сервер наследует дескрипторы и держит их открытыми.
    final s1 = p.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen(buf.write);
    final s2 = p.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen(buf.write);
    var timedOut = false;
    int code;
    try {
      code = await p.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      p.kill();
      code = -4;
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await s1.cancel();
    await s2.cancel();
    ct?._procs.remove(p);
    final out = buf.toString().replaceAll('\r\n', '\n').trim();
    if (ct?.cancelled == true) return AdbResult(-5, out, cancelled: true);
    if (timedOut) return AdbResult(-4, 'Таймаут ${timeout.inSeconds} с — команда не ответила. $out'.trim(), timedOut: true);
    return AdbResult(code, out);
  }
}

enum DevState { noAdb, none, unauthorized, offline, ready, many }

class DevEntry {
  const DevEntry(this.serial, this.state, this.model);
  final String serial, state, model;
}

/// Разбор `adb devices -l`.
List<DevEntry> parseDevices(String out) {
  final res = <DevEntry>[];
  for (final raw in out.split('\n')) {
    final l = raw.trim();
    if (l.isEmpty || l.startsWith('List of devices') || l.startsWith('*')) continue;
    final parts = l.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final model = parts.firstWhere((s) => s.startsWith('model:'), orElse: () => '').replaceFirst('model:', '');
    res.add(DevEntry(parts[0], parts[1], model.replaceAll('_', ' ')));
  }
  return res;
}
