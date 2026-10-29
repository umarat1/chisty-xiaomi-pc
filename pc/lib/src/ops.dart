import 'adb.dart';
import 'catalog.dart';

class OpResult {
  const OpResult(this.id, this.ok, this.msg);
  final String id;
  final bool ok;
  final String msg;
}

class PkgInfo {
  const PkgInfo(this.id, {required this.system, required this.installed});
  final String id;
  final bool system, installed;
}

class DeviceInfo {
  const DeviceInfo({this.name = '', this.model = '', this.device = '', this.hyperos = '', this.android = '', this.sdk = 0, this.batteryTemp});
  final String name, model, device, hyperos, android;
  final int sdk;
  final double? batteryTemp;
}

class TempSensor {
  const TempSensor(this.name, this.value);
  final String name;
  final double value;
}

class SettingEdit {
  const SettingEdit(this.ns, this.key, this.value);
  final String ns, key, value;
  String get id => '$ns/$key';
}

class Toggle {
  const Toggle(this.id, this.title, this.desc, this.edits, {this.note = ''});
  final String id, title, desc, note;
  final List<SettingEdit> edits;
}

class Toggles {
  static const adguard = 'dns.adguard-dns.com';
  static const telemetry = [
    Toggle('crash_send', 'Не отправлять отчёты о сбоях', 'Отключает отправку отчётов при падении приложений.', [
      SettingEdit('global', 'send_action_app_error', '0'),
    ]),
    Toggle(
      'scan_always',
      'Выключить фоновый поиск Wi‑Fi и Bluetooth',
      'Телефон перестаёт постоянно сканировать сети для геолокации — меньше слежки и расход батареи.',
      [SettingEdit('global', 'wifi_scan_always_enabled', '0'), SettingEdit('global', 'ble_scan_always_enabled', '0')],
    ),
    Toggle('miui_log', 'Не отправлять журналы Xiaomi', 'Ключ upload_log_pref (программа улучшения качества). Работает не на всех версиях HyperOS.', [
      SettingEdit('secure', 'upload_log_pref', '0'),
    ], note: 'лучшее, что доступно без root'),
    Toggle(
      'private_dns',
      'Блокировка рекламы и трекеров (Private DNS AdGuard)',
      'Весь DNS через $adguard: режет рекламу и трекеры во всех приложениях. Выключение вернёт прежний DNS.',
      [SettingEdit('global', 'private_dns_mode', 'hostname'), SettingEdit('global', 'private_dns_specifier', adguard)],
      note: 'если на телефоне включён VPN, DNS решает VPN',
    ),
  ];
  static const performance = [
    Toggle('anim', 'Анимации 0.5x', 'Интерфейс ощущается вдвое быстрее. Выключение вернёт прежнюю скорость.', [
      SettingEdit('global', 'window_animation_scale', '0.5'),
      SettingEdit('global', 'transition_animation_scale', '0.5'),
      SettingEdit('global', 'animator_duration_scale', '0.5'),
    ]),
    Toggle(
      'hz60',
      'Экран 60 Гц (меньше нагрев)',
      'Ограничивает частоту экрана 60 Гц — меньше нагрев и расход. HyperOS может переопределить это своим переключателем частоты.',
      [SettingEdit('system', 'peak_refresh_rate', '60.0'), SettingEdit('system', 'min_refresh_rate', '60.0')],
    ),
  ];
  static List<Toggle> get all => [...telemetry, ...performance];
  static Toggle byId(String id) => all.firstWhere((t) => t.id == id);

  static const defaults = {
    'global/window_animation_scale': '1.0',
    'global/transition_animation_scale': '1.0',
    'global/animator_duration_scale': '1.0',
    'global/private_dns_mode': 'opportunistic',
  };
}

/// Разбор вывода команд.
class Parse {
  static Set<String> packages(String out) => out
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.startsWith('package:'))
      .map((l) => l.substring(8).split(' ').first.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  static String? setting(String out) {
    final v = out.trim().split('\n').last.trim();
    return (v.isEmpty || v == 'null') ? null : v;
  }

  static double? batteryTemp(String dumpsysBattery) {
    final m = RegExp(r'^\s*temperature:\s*(-?\d+)', multiLine: true).firstMatch(dumpsysBattery);
    return m == null ? null : int.parse(m.group(1)!) / 10.0;
  }

  static const _names = {'cpu': 'CPU', 'gpu': 'GPU', 'battery': 'Батарея', 'skin': 'Корпус', 'usb_port': 'USB', 'power_amplifier': 'Модем', 'npu': 'NPU'};

  /// `dumpsys thermalservice` › раздел «Current temperatures from HAL».
  static List<TempSensor> thermal(String out) {
    final i = out.indexOf('Current temperatures from HAL');
    if (i < 0) return [];
    var sec = out.substring(i);
    final end = sec.indexOf('Current cooling devices');
    if (end > 0) sec = sec.substring(0, end);
    final re = RegExp(r'mValue=(-?[\d.]+),\s*mType=(-?\d+),\s*mName=([^,]+),');
    final res = <TempSensor>[];
    for (final m in re.allMatches(sec)) {
      final v = double.tryParse(m.group(1)!) ?? 0;
      if (v <= 0 || v > 150) continue;
      final name = m.group(3)!.trim();
      final key = _names.keys.firstWhere((k) => name.toLowerCase().contains(k), orElse: () => '');
      res.add(TempSensor(key.isEmpty ? name : '${_names[key]} · $name', v));
    }
    res.sort((a, b) => b.value.compareTo(a.value));
    return res;
  }

  static bool needsSecurity(String out) =>
      out.contains('SecurityException') ||
      out.contains('Permission Denial') ||
      out.contains('INJECT_EVENTS') ||
      out.contains('GRANT_RUNTIME_PERMISSIONS') ||
      out.contains('USB debugging (Security settings)');

  static String explain(String out) {
    if (Parse.needsSecurity(out)) return 'нужна «Отладка по USB (настройки безопасности)» — ${_cut(out, 120)}';
    return out.trim().isEmpty ? 'нет ответа' : _cut(out, 180);
  }

  static String _cut(String s, int n) {
    final t = s.replaceAll('\n', ' ').trim();
    return t.length <= n ? t : '${t.substring(0, n)}…';
  }
}

/// Команды к одному телефону через `adb -s <serial> shell`.
class Ops {
  Ops(this.adb, this.serial);
  final AdbExec adb;
  final String serial;

  static const def = Duration(seconds: 20);
  static const long = Duration(minutes: 30);

  Future<AdbResult> sh(String cmd, {Duration timeout = def, CancelToken? ct}) => adb.run(['-s', serial, 'shell', cmd], timeout: timeout, ct: ct);

  Future<DeviceInfo> info() async {
    final keys = [
      'ro.product.marketname',
      'ro.product.model',
      'ro.product.device',
      'ro.mi.os.version.incremental',
      'ro.build.version.release',
      'ro.build.version.sdk',
      'ro.miui.ui.version.name',
    ];
    final r = await sh(keys.map((k) => 'echo "$k=\$(getprop $k)"').join('; '));
    final m = <String, String>{};
    for (final l in r.out.split('\n')) {
      final i = l.indexOf('=');
      if (i > 0) m[l.substring(0, i).trim()] = l.substring(i + 1).trim();
    }
    final b = await sh('dumpsys battery');
    final os = m['ro.mi.os.version.incremental'] ?? '';
    return DeviceInfo(
      name: (m['ro.product.marketname'] ?? '').isNotEmpty ? m['ro.product.marketname']! : (m['ro.product.model'] ?? ''),
      model: m['ro.product.model'] ?? '',
      device: m['ro.product.device'] ?? '',
      hyperos: os.isNotEmpty ? 'HyperOS $os' : ((m['ro.miui.ui.version.name'] ?? '').isNotEmpty ? 'MIUI ${m['ro.miui.ui.version.name']}' : ''),
      android: m['ro.build.version.release'] ?? '',
      sdk: int.tryParse(m['ro.build.version.sdk'] ?? '') ?? 0,
      batteryTemp: Parse.batteryTemp(b.out),
    );
  }

  /// Все пакеты пользователя 0: установленные и удалённые для пользователя (`-u`), с признаком «системный».
  /// Пустой список установленных невозможен — это ошибка, а не «удалять нечего».
  Future<Map<String, PkgInfo>> packages({CancelToken? ct}) async {
    final inst = await sh('pm list packages --user 0', timeout: const Duration(seconds: 40), ct: ct);
    final installed = Parse.packages(inst.out);
    if (installed.isEmpty) {
      throw Exception('не удалось получить список приложений (код ${inst.code}): ${Parse.explain(inst.out)}');
    }
    final all = Parse.packages((await sh('pm list packages -u --user 0', timeout: const Duration(seconds: 40), ct: ct)).out);
    final sys = Parse.packages((await sh('pm list packages -s -u --user 0', timeout: const Duration(seconds: 40), ct: ct)).out);
    final ids = {...installed, ...all};
    return {for (final id in ids) id: PkgInfo(id, system: sys.contains(id), installed: installed.contains(id))};
  }

  /// Лаунчер, клавиатура, звонилка, SMS по умолчанию — защищены дополнительно.
  Future<Set<String>> dynamicProtected({CancelToken? ct}) async {
    final s = <String>{};
    for (final role in ['android.app.role.HOME', 'android.app.role.SMS', 'android.app.role.DIALER']) {
      final r = await sh('cmd role get-role-holders --user 0 $role', ct: ct);
      if (r.ok) s.addAll(r.out.split(RegExp(r'[;,\s]+')).where(Catalog.safePkg));
    }
    final ime = Parse.setting((await sh('settings get secure default_input_method', ct: ct)).out);
    if (ime != null && Catalog.safePkg(ime.split('/').first)) s.add(ime.split('/').first);
    return s;
  }

  Future<OpResult> uninstall(String id, {CancelToken? ct}) async {
    if (!Catalog.safePkg(id)) return OpResult(id, false, 'недопустимое имя');
    final r = await sh('pm uninstall -k --user 0 $id', ct: ct);
    final ok = r.ok && r.out.contains('Success');
    return OpResult(id, ok, ok ? 'удалён' : Parse.explain(r.out));
  }

  Future<OpResult> restore(String id, {CancelToken? ct}) async {
    if (!Catalog.safePkg(id)) return OpResult(id, false, 'недопустимое имя');
    var r = await sh('cmd package install-existing --user 0 $id', ct: ct);
    if (!r.ok) r = await sh('pm install-existing --user 0 $id', ct: ct);
    final ok = r.ok && (r.out.contains('installed') || r.out.contains('Success'));
    return OpResult(id, ok, ok ? 'восстановлен' : Parse.explain(r.out));
  }

  Future<String?> getSetting(SettingEdit e, {CancelToken? ct}) async => Parse.setting((await sh('settings get ${e.ns} ${e.key}', ct: ct)).out);

  Future<bool> isOn(Toggle t) async {
    for (final e in t.edits) {
      if (await getSetting(e) != e.value) return false;
    }
    return true;
  }

  /// Применяет переключатель; originals получает исходные значения (для отката).
  Future<OpResult> apply(Toggle t, Map<String, String?> originals, {CancelToken? ct}) async {
    var err = '';
    for (final e in t.edits) {
      if (!originals.containsKey(e.id)) originals[e.id] = await getSetting(e, ct: ct) ?? '__null__';
      final r = await sh("settings put ${e.ns} ${e.key} '${e.value}'", ct: ct);
      if (!r.ok) err = Parse.explain(r.out);
    }
    return OpResult(t.title, err.isEmpty, err.isEmpty ? 'применено' : err);
  }

  Future<OpResult> revert(Toggle t, Map<String, String?> originals, {CancelToken? ct}) async {
    var err = '';
    for (final e in t.edits.reversed) {
      var orig = originals[e.id];
      orig ??= Toggles.defaults[e.id];
      final r = (orig == null || orig == '__null__')
          ? await sh('settings delete ${e.ns} ${e.key}', ct: ct)
          : await sh("settings put ${e.ns} ${e.key} '$orig'", ct: ct);
      if (!r.ok) err = Parse.explain(r.out);
      originals.remove(e.id);
    }
    return OpResult(t.title, err.isEmpty, err.isEmpty ? 'возвращено' : err);
  }

  Future<List<TempSensor>> temps() async => Parse.thermal((await sh('dumpsys thermalservice', timeout: const Duration(seconds: 30))).out);
}
