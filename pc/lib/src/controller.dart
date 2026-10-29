import 'dart:async';

import 'package:flutter/foundation.dart';

import 'adb.dart';
import 'catalog.dart';
import 'ops.dart';
import 'store.dart';

class Progress {
  const Progress(this.title, this.done, this.total, this.current);
  final String title, current;
  final int done, total;
}

class Controller extends ChangeNotifier {
  Controller(this.adb, this.store, {this.version = '1.0.0'});
  final AdbExec adb;
  final Store store;
  final String version;

  DevState state = DevState.none;
  String serial = '';
  String stateDetail = '';
  DeviceInfo? info;
  Ops? ops;
  Map<String, PkgInfo> pkgs = {};
  Set<String> dynamicProtected = {};
  String listError = '';
  Map<String, bool> toggles = {};
  List<TempSensor> temps = [];
  Progress? busy;
  CancelToken? _ct;
  List<OpResult> results = [];
  String resultTitle = '', resultNote = '';
  final Set<String> selXiaomi = Catalog.recommended.map((p) => p.id).toSet();
  final Set<String> selAll = {};
  final List<String> log = [];
  Timer? _timer;
  bool _polling = false;

  // ───────────── журнал
  void addLog(String m) {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    log.add('${two(t.hour)}:${two(t.minute)}:${two(t.second)}  $m');
    if (log.length > 5000) log.removeRange(0, log.length - 5000);
    notifyListeners();
  }

  String logText() {
    final i = info;
    return [
      'Чистый Xiaomi для Windows $version',
      'Телефон: ${i == null ? '—' : '${i.name} (${i.model}, ${i.device}), ${i.hyperos}, Android ${i.android} / API ${i.sdk}'}',
      'ADB: $state $serial $stateDetail'.trim(),
      'Пакетов: ${pkgs.length}; ошибка списка: ${listError.isEmpty ? 'нет' : listError}',
      '—',
      ...log,
    ].join('\n');
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  // ───────────── подключение
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => poll());
    unawaited(_startServer());
  }

  Future<void> _startServer() async {
    final r = await adb.run(['start-server'], timeout: const Duration(seconds: 25));
    if (r.code == -1) {
      state = DevState.noAdb;
      stateDetail = r.out;
      addLog(r.out);
    }
    await poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> poll() async {
    if (_polling || busy != null) return;
    _polling = true;
    try {
      final r = await adb.run(['devices', '-l'], timeout: const Duration(seconds: 10));
      if (r.code == -1) {
        _set(DevState.noAdb, '', r.out);
        return;
      }
      final list = parseDevices(r.out);
      final ready = list.where((d) => d.state == 'device').toList();
      if (ready.length > 1) {
        // Несколько телефонов: остаёмся на выбранном, иначе берём первый.
        final keep = ready.any((d) => d.serial == serial);
        if (!keep) await _attach(ready.first);
        return;
      }
      if (ready.length == 1) {
        if (state != DevState.ready || serial != ready.first.serial) await _attach(ready.first);
        return;
      }
      if (list.any((d) => d.state == 'unauthorized')) {
        _set(
          DevState.unauthorized,
          list.first.serial,
          'Разблокируйте телефон и нажмите «Разрешить» в окне «Разрешить отладку по USB?» (поставьте галочку «Всегда разрешать»).',
        );
      } else if (list.any((d) => d.state == 'offline')) {
        _set(DevState.offline, list.first.serial, 'Телефон «offline» — переподключите кабель или выключите/включите «Отладка по USB».');
      } else {
        _set(DevState.none, '', '');
      }
    } finally {
      _polling = false;
    }
  }

  void _set(DevState s, String ser, String detail) {
    if (state == s && serial == ser && stateDetail == detail) return;
    if (state == DevState.ready && s != DevState.ready) addLog('Телефон отключён');
    state = s;
    serial = ser;
    stateDetail = detail;
    if (s != DevState.ready) {
      info = null;
      ops = null;
      pkgs = {};
    }
    notifyListeners();
  }

  Future<void> _attach(DevEntry d) async {
    serial = d.serial;
    ops = Ops(adb, d.serial);
    state = DevState.ready;
    stateDetail = '';
    addLog('Подключён телефон ${d.model} (${d.serial})');
    await refresh();
  }

  Future<void> refresh() async {
    final o = ops;
    if (o == null) return;
    try {
      info = await o.info();
      notifyListeners();
      pkgs = await o.packages();
      dynamicProtected = await o.dynamicProtected();
      listError = '';
      notifyListeners();
      final t = <String, bool>{};
      for (final tg in Toggles.all) {
        t[tg.id] = await o.isOn(tg);
      }
      toggles = t;
      temps = await o.temps();
    } catch (e) {
      listError = '$e'.replaceFirst('Exception: ', '');
      addLog('Ошибка обновления: $listError');
    }
    notifyListeners();
  }

  Iterable<PkgInfo> get installed => pkgs.values.where((p) => p.installed);
  bool isInstalled(String id) => pkgs[id]?.installed == true;
  Risk riskOf(String id) => Catalog.risk(id, system: pkgs[id]?.system ?? true, dynamic: dynamicProtected);

  /// Удалённые для пользователя 0: из резервной копии на ПК + всё, что телефон считает «не установлено для user 0».
  List<String> get removedList {
    final ids = <String>{...store.removed(serial).keys, ...pkgs.values.where((p) => !p.installed).map((p) => p.id)};
    final l = ids.toList()..sort((a, b) => Catalog.label(a).toLowerCase().compareTo(Catalog.label(b).toLowerCase()));
    return l;
  }

  // ───────────── долгие операции
  void cancel() {
    _ct?.cancel();
    addLog('Отмена…');
  }

  Future<void> runBusy(String title, Future<void> Function(List<OpResult> sink, CancelToken ct, Ops o) body) async {
    final o = ops;
    if (busy != null || o == null) return;
    final ct = _ct = CancelToken();
    busy = Progress(title, 0, 0, '');
    addLog('▶ $title');
    final sink = <OpResult>[];
    var note = '';
    try {
      await body(sink, ct, o);
      if (ct.cancelled) note = 'Операция отменена. Выполнено до отмены: ${sink.length}.';
    } on Cancelled {
      note = 'Операция отменена. Выполнено до отмены: ${sink.length}.';
    } catch (e) {
      note = 'Ошибка: ${'$e'.replaceFirst('Exception: ', '')}';
    } finally {
      busy = null;
      _ct = null;
    }
    final ok = sink.where((r) => r.ok).length;
    addLog('■ $title: успешно $ok из ${sink.length}${note.isEmpty ? '' : ' · $note'}');
    if (sink.any((r) => !r.ok && r.msg.contains('настройки безопасности'))) {
      note = [
        if (note.isNotEmpty) note,
        'Часть действий запрещена HyperOS: включите «Для разработчиков › Отладка по USB (настройки безопасности)» и повторите.',
      ].join('\n');
    }
    results = sink;
    resultTitle = title;
    resultNote = sink.isEmpty && note.isEmpty ? 'Нечего делать — всё уже чисто.' : note;
    notifyListeners();
    await refresh();
  }

  void step(String title, int done, int total, String cur) {
    busy = Progress(title, done, total, cur);
    notifyListeners();
  }

  void clearResults() {
    results = [];
    resultTitle = '';
    resultNote = '';
    notifyListeners();
  }

  /// Удаляет пакеты по одному; ошибка одного не останавливает остальные. Жёстко защищённые — только если allowHard.
  Future<void> _remove(String title, List<String> ids, List<OpResult> sink, CancelToken ct, Ops o, {bool allowHard = false}) async {
    step(title, 0, 0, 'Получаю список приложений…');
    final fresh = await o.packages(ct: ct);
    pkgs = fresh;
    final todo = <String>[];
    for (final id in ids) {
      if (!(fresh[id]?.installed ?? false)) continue;
      if (!allowHard && Catalog.isHard(id, dynamic: dynamicProtected)) {
        sink.add(OpResult(id, false, 'критичный системный пакет — пропущен'));
        continue;
      }
      todo.add(id);
    }
    addLog('Удаление: к удалению ${todo.length} из ${ids.length} (на телефоне ${fresh.values.where((p) => p.installed).length} пакетов)');
    for (var i = 0; i < todo.length; i++) {
      if (ct.cancelled) throw Cancelled();
      final id = todo[i];
      step(title, i, todo.length, Catalog.label(id));
      final r = await o.uninstall(id, ct: ct);
      if (ct.cancelled) throw Cancelled();
      if (r.ok) store.addRemoved(serial, id, model: info?.name ?? '');
      addLog(r.ok ? 'Удалён: $id' : 'Не удалось удалить: $id — ${r.msg}');
      sink.add(r);
    }
    step(title, todo.length, todo.length, '');
  }

  Future<void> _toggle(Toggle t, bool on, List<OpResult> sink, CancelToken ct, Ops o) async {
    final orig = store.originals(serial);
    final r = on ? await o.apply(t, orig, ct: ct) : await o.revert(t, orig, ct: ct);
    store.saveOriginals(serial, orig);
    addLog('${on ? 'Включено' : 'Выключено'}: ${t.title}${r.ok ? '' : ' — ${r.msg}'}');
    sink.add(r);
  }

  /// Одна кнопка: «Рекомендуется» + телеметрия (без DNS) + анимации 0.5x.
  Future<void> oneClick() => runBusy('Очистка одной кнопкой', (sink, ct, o) async {
    final tg = [...Toggles.telemetry.where((t) => t.id != 'private_dns'), Toggles.byId('anim')];
    for (var i = 0; i < tg.length; i++) {
      if (ct.cancelled) throw Cancelled();
      step('Очистка одной кнопкой', i, tg.length, tg[i].title);
      await _toggle(tg[i], true, sink, ct, o);
    }
    await _remove('Очистка одной кнопкой', Catalog.recommended.map((p) => p.id).toList(), sink, ct, o);
  });

  Future<void> disableTelemetry() => runBusy('Выключение телеметрии', (sink, ct, o) async {
    final tg = Toggles.telemetry.where((t) => t.id != 'private_dns').toList();
    for (var i = 0; i < tg.length; i++) {
      if (ct.cancelled) throw Cancelled();
      step('Выключение телеметрии', i, tg.length, tg[i].title);
      await _toggle(tg[i], true, sink, ct, o);
    }
    await _remove('Выключение телеметрии', Catalog.telemetry.map((p) => p.id).toList(), sink, ct, o);
  });

  Future<void> removeIds(String title, List<String> ids, {bool allowHard = false}) =>
      runBusy(title, (sink, ct, o) => _remove(title, ids, sink, ct, o, allowHard: allowHard));

  Future<void> setToggle(Toggle t, bool on) => runBusy(on ? t.title : 'Отмена: ${t.title}', (sink, ct, o) async {
    await _toggle(t, on, sink, ct, o);
  });

  Future<void> restore(List<String> ids) => runBusy(ids.length == 1 ? 'Восстановление' : 'Восстановление (${ids.length})', (sink, ct, o) async {
    for (var i = 0; i < ids.length; i++) {
      if (ct.cancelled) throw Cancelled();
      step('Восстановление', i, ids.length, Catalog.label(ids[i]));
      final r = await o.restore(ids[i], ct: ct);
      if (r.ok) store.dropRemoved(serial, ids[i]);
      addLog(r.ok ? 'Восстановлен: ${ids[i]}' : 'Не удалось восстановить: ${ids[i]} — ${r.msg}');
      sink.add(r);
    }
  });

  Future<void> shellAction(String title, String cmd, String okMsg, {Duration timeout = Ops.def}) => runBusy(title, (sink, ct, o) async {
    step(title, 0, 0, cmd);
    final r = await o.sh(cmd, timeout: timeout, ct: ct);
    if (ct.cancelled) throw Cancelled();
    addLog('$cmd › ${r.code}${r.ok ? '' : ': ${Parse.explain(r.out)}'}');
    sink.add(OpResult(title, r.ok, r.ok ? okMsg : Parse.explain(r.out)));
  });

  Future<void> optimize() =>
      shellAction('Оптимизация приложений', 'cmd package compile -m speed-profile -a', 'приложения перекомпилированы (speed-profile)', timeout: Ops.long);
  Future<void> bgDexopt() => shellAction('Фоновая оптимизация', 'cmd package bg-dexopt-job', 'фоновая оптимизация выполнена', timeout: Ops.long);
  Future<void> killBg() => shellAction('Закрыть фоновые процессы', 'am kill-all', 'фоновые процессы закрыты');
  Future<void> trimCaches() => shellAction('Очистить кэш', 'pm trim-caches 999G', 'кэш приложений очищен', timeout: const Duration(minutes: 2));

  Future<void> loadTemps() async {
    final o = ops;
    if (o == null || busy != null) return;
    temps = await o.temps();
    final b = await o.sh('dumpsys battery');
    final t = Parse.batteryTemp(b.out);
    if (info != null && t != null) {
      final i = info!;
      info = DeviceInfo(name: i.name, model: i.model, device: i.device, hyperos: i.hyperos, android: i.android, sdk: i.sdk, batteryTemp: t);
    }
    notifyListeners();
  }

  void notify() => notifyListeners();
}
