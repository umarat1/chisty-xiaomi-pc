import 'package:chisty_xiaomi/src/adb.dart';

/// Фейковый телефон для тестов и скриншотов.
class FakeAdb implements AdbExec {
  FakeAdb({Set<String>? installed, Set<String>? system, this.state = 'device'}) : installed = installed ?? {}, system = system ?? {};
  final Set<String> installed, system;
  final Set<String> removed = {};
  final settings = <String, String>{};
  final log = <String>[];
  String state;
  Set<String> hang = {};

  @override
  Future<AdbResult> run(List<String> args, {Duration timeout = const Duration(seconds: 20), CancelToken? ct}) async {
    if (args.first == 'start-server') return const AdbResult(0, '');
    if (args.first == 'devices') {
      return AdbResult(
        0,
        'List of devices attached\n${state == 'none' ? '' : 'A1B2C3D4\t$state usb:1-1 product:degas_global model:2406APNFAG device:degas transport_id:1'}\n',
      );
    }
    final cmd = args.skip(3).join(' ');
    log.add(cmd);
    if (hang.any(cmd.contains)) return AdbResult(-4, 'Таймаут ${timeout.inSeconds} с — команда не ответила.', timedOut: true);
    final a = cmd.split(' ');
    if (cmd.startsWith('echo "ro.')) {
      return const AdbResult(
        0,
        'ro.product.marketname=Xiaomi 14T\nro.product.model=2406APNFAG\nro.product.device=degas\n'
        'ro.mi.os.version.incremental=OS2.0.206.0.VNEEUXM\nro.build.version.release=16\nro.build.version.sdk=36\nro.miui.ui.version.name=V816',
      );
    }
    if (cmd == 'dumpsys battery') return const AdbResult(0, 'Current Battery Service state:\n  level: 82\n  temperature: 352\n');
    if (cmd.startsWith('dumpsys thermalservice')) {
      return const AdbResult(
        0,
        'Current temperatures from HAL:\n\tTemperature{mValue=46.1, mType=0, mName=cpu-big, mStatus=0}\n'
        '\tTemperature{mValue=35.2, mType=2, mName=battery, mStatus=0}\n\tTemperature{mValue=38.9, mType=3, mName=skin, mStatus=0}\nCurrent cooling devices from HAL:\n',
      );
    }
    if (cmd.startsWith('pm list packages')) {
      final u = cmd.contains('-u');
      final s = cmd.contains('-s');
      var ids = u ? {...installed, ...removed} : installed;
      if (s) ids = ids.where(system.contains).toSet();
      return AdbResult(0, ids.map((e) => 'package:$e').join('\n'));
    }
    if (cmd.startsWith('pm uninstall -k --user 0 ')) {
      final id = a.last;
      if (installed.remove(id)) {
        removed.add(id);
        return const AdbResult(0, 'Success');
      }
      return const AdbResult(1, 'Failure [not installed for 0]');
    }
    if (cmd.startsWith('cmd package install-existing')) {
      installed.add(a.last);
      removed.remove(a.last);
      return AdbResult(0, 'Package ${a.last} installed for user: 0');
    }
    if (cmd.startsWith('cmd role get-role-holders')) return AdbResult(0, cmd.endsWith('HOME') ? 'com.miui.home' : '');
    if (cmd.startsWith('settings get')) return AdbResult(0, settings['${a[2]}/${a[3]}'] ?? 'null');
    if (cmd.startsWith('settings put')) {
      settings['${a[2]}/${a[3]}'] = a[4].replaceAll("'", '');
      return const AdbResult(0, '');
    }
    if (cmd.startsWith('settings delete')) {
      settings.remove('${a[2]}/${a[3]}');
      return const AdbResult(0, '');
    }
    return const AdbResult(0, '');
  }
}

const sampleSystem = {
  'android',
  'com.android.systemui',
  'com.android.settings',
  'com.android.phone',
  'com.miui.home',
  'com.miui.securitycenter',
  'com.android.providers.media',
  'com.mediatek.ims',
  'com.miui.analytics',
  'com.miui.msa.global',
  'com.miui.daemon',
  'com.miui.bugreport',
  'com.xiaomi.mipicks',
  'com.mi.globalbrowser',
  'com.miui.videoplayer',
  'com.miui.player',
  'com.miui.weather2',
  'com.miui.notes',
  'com.xiaomi.joyose',
  'com.miui.gallery',
  'com.android.deskclock',
  'com.google.android.gms',
  'com.android.vending',
  'com.google.android.youtube',
  'com.google.android.feedback',
  'com.miui.hybrid',
  'com.facebook.services',
  'com.facebook.system',
  'com.android.chrome',
  'com.google.android.gm',
  'com.miui.cleaner',
  'com.android.bluetooth',
  'com.android.camera',
};
const sampleUser = {'org.telegram.messenger', 'com.whatsapp', 'ru.yandex.yandexmaps'};
