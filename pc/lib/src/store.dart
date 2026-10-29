import 'dart:convert';
import 'dart:io';

/// Резервная копия на ПК: список удалённых пакетов и исходные значения настроек — по каждому телефону.
/// Windows: %APPDATA%\ChistyXiaomi\  ·  Linux/macOS: ~/.local/share/ChistyXiaomi/
class Store {
  Store([String? dir]) : dir = dir ?? defaultDir();
  final String dir;

  static String defaultDir() {
    final e = Platform.environment;
    final base = Platform.isWindows ? (e['APPDATA'] ?? e['USERPROFILE'] ?? '.') : '${e['HOME'] ?? '.'}/.local/share';
    return '$base${Platform.pathSeparator}ChistyXiaomi';
  }

  String _f(String name) => '$dir${Platform.pathSeparator}$name';
  static String _safe(String serial) => serial.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  Map<String, dynamic> _read(String name) {
    try {
      final f = File(_f(name));
      if (f.existsSync()) return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  void _write(String name, Map<String, dynamic> j) {
    Directory(dir).createSync(recursive: true);
    final f = File(_f(name));
    final tmp = File('${f.path}.tmp')..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(j));
    if (f.existsSync()) f.deleteSync();
    tmp.renameSync(f.path);
  }

  String removedFile(String serial) => _f('removed-${_safe(serial)}.json');

  /// Удалённые пакеты: id › дата удаления.
  Map<String, String> removed(String serial) =>
      (_read('removed-${_safe(serial)}.json')['removed'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, '$v'));

  void addRemoved(String serial, String id, {String model = ''}) {
    final j = _read('removed-${_safe(serial)}.json');
    final m = (j['removed'] as Map<String, dynamic>? ?? {})..[id] = DateTime.now().toIso8601String().substring(0, 19);
    _write('removed-${_safe(serial)}.json', {'serial': serial, if (model.isNotEmpty) 'model': model, 'removed': m});
  }

  void dropRemoved(String serial, String id) {
    final j = _read('removed-${_safe(serial)}.json');
    final m = (j['removed'] as Map<String, dynamic>? ?? {})..remove(id);
    j['removed'] = m;
    _write('removed-${_safe(serial)}.json', j);
  }

  Map<String, String?> originals(String serial) => (_read('settings-${_safe(serial)}.json')).map((k, v) => MapEntry(k, v as String?));

  void saveOriginals(String serial, Map<String, String?> m) => _write('settings-${_safe(serial)}.json', m);

  /// Сохраняет журнал в файл и возвращает путь.
  String saveLog(String text) {
    final d = Directory(_f('logs'))..createSync(recursive: true);
    final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    final f = File('${d.path}${Platform.pathSeparator}log-$ts.txt')..writeAsStringSync(text);
    return f.path;
  }
}
