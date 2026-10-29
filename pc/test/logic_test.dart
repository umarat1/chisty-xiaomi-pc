import 'dart:io';

import 'package:chisty_xiaomi/src/adb.dart';
import 'package:chisty_xiaomi/src/catalog.dart';
import 'package:chisty_xiaomi/src/controller.dart';
import 'package:chisty_xiaomi/src/ops.dart';
import 'package:chisty_xiaomi/src/store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_adb.dart';

Future<Controller> connected(FakeAdb f) async {
  final dir = Directory.systemTemp.createTempSync('cx');
  final c = Controller(f, Store(dir.path));
  await c.poll();
  return c;
}

void main() {
  test('catalog: no duplicates, hard list covers bootloop-critical', () {
    final ids = catalogAll.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in [
      'com.miui.securitycenter',
      'com.miui.home',
      'com.android.systemui',
      'com.android.settings',
      'android',
      'com.android.providers.media',
      'com.android.phone',
      'com.miui.global.packageinstaller',
      'com.mediatek.ims',
    ]) {
      expect(Catalog.risk(id, system: true), Risk.hard, reason: id);
    }
    expect(Catalog.risk('com.xiaomi.joyose', system: true), Risk.warn);
    expect(Catalog.risk('com.android.bluetooth', system: true), Risk.warn); // неизвестный системный
    expect(Catalog.risk('org.telegram.messenger', system: false), Risk.normal);
    expect(Catalog.risk('com.miui.analytics', system: true), Risk.normal);
    expect(Catalog.recommended.any((p) => Catalog.isHard(p.id)), isFalse);
  });

  test('parse devices / packages / battery / thermal', () {
    final d = parseDevices('List of devices attached\nabc\tunauthorized usb:1\nX1\tdevice product:p model:Xiaomi_14T device:degas\n\n');
    expect(d.length, 2);
    expect(d[1].model, 'Xiaomi 14T');
    expect(Parse.packages('package:a.b\r\npackage:c.d uid:1\njunk'), {'a.b', 'c.d'});
    expect(Parse.batteryTemp('  temperature: 352'), 35.2);
    expect(Parse.thermal('Current temperatures from HAL:\nTemperature{mValue=46.1, mType=0, mName=cpu-big, mStatus=0}').first.value, 46.1);
    expect(Parse.needsSecurity('java.lang.SecurityException: x'), isTrue);
  });

  test('one click removes only installed recommended, never hard; toggles applied; backup on PC', () async {
    final f = FakeAdb(installed: {...sampleSystem, ...sampleUser}, system: {...sampleSystem});
    final c = await connected(f);
    expect(c.state, DevState.ready);
    expect(c.info!.name, 'Xiaomi 14T');
    expect(c.info!.hyperos, contains('OS2.0'));
    await c.oneClick();
    expect(f.removed, containsAll(['com.miui.analytics', 'com.miui.msa.global', 'com.xiaomi.mipicks']));
    for (final keep in ['com.miui.home', 'com.miui.securitycenter', 'com.xiaomi.joyose', 'com.miui.weather2', 'android', 'com.android.systemui']) {
      expect(f.installed, contains(keep));
    }
    expect(f.settings['global/window_animation_scale'], '0.5');
    expect(f.settings['global/send_action_app_error'], '0');
    expect(f.settings.containsKey('global/private_dns_mode'), isFalse);
    expect(c.store.removed(c.serial).keys, containsAll(['com.miui.analytics']));
    expect(c.results.every((r) => r.ok), isTrue);
    // восстановление всего из копии
    await c.restore(c.store.removed(c.serial).keys.toList());
    expect(f.removed, isEmpty);
    expect(c.store.removed(c.serial), isEmpty);
  });

  test('hard packages are skipped unless explicitly allowed', () async {
    final f = FakeAdb(installed: {...sampleSystem}, system: {...sampleSystem});
    final c = await connected(f);
    await c.removeIds('x', ['com.miui.securitycenter', 'com.miui.weather2']);
    expect(f.installed, contains('com.miui.securitycenter'));
    expect(f.installed, isNot(contains('com.miui.weather2')));
    await c.removeIds('x', ['com.miui.securitycenter'], allowHard: true);
    expect(f.installed, isNot(contains('com.miui.securitycenter')));
  });

  test('a hanging command does not stop the batch; empty package list is an error', () async {
    final f = FakeAdb(installed: {...sampleSystem}, system: {...sampleSystem})..hang = {'com.miui.msa.global'};
    final c = await connected(f);
    await c.removeIds('x', ['com.miui.msa.global', 'com.miui.analytics']);
    expect(c.results.length, 2);
    expect(c.results.first.ok, isFalse);
    expect(c.results.first.msg, contains('Таймаут'));
    expect(c.results.last.ok, isTrue);
    f.hang = {'pm list packages'};
    await c.removeIds('y', ['com.miui.daemon']);
    expect(c.resultNote, contains('список приложений'));
    expect(f.installed, contains('com.miui.daemon'));
  });

  test('toggle revert restores original value', () async {
    final f = FakeAdb(installed: {...sampleSystem}, system: {...sampleSystem});
    f.settings['global/window_animation_scale'] = '1.0';
    final c = await connected(f);
    final anim = Toggles.byId('anim');
    await c.setToggle(anim, true);
    expect(f.settings['global/window_animation_scale'], '0.5');
    await c.setToggle(anim, false);
    expect(f.settings['global/window_animation_scale'], '1.0');
    expect(f.settings.containsKey('global/transition_animation_scale'), isFalse);
  });

  test('ProcessAdb enforces timeout and cancel', () async {
    if (Platform.isWindows) return;
    final sw = Stopwatch()..start();
    final r = await ProcessAdb('sleep').run(['10'], timeout: const Duration(milliseconds: 500));
    expect(r.timedOut, isTrue);
    expect(sw.elapsedMilliseconds, lessThan(3000));
    final ct = CancelToken();
    final fut = ProcessAdb('sleep').run(['10'], ct: ct);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    ct.cancel();
    final r2 = await fut.timeout(const Duration(seconds: 3));
    expect(r2.cancelled, isTrue);
    final r3 = await ProcessAdb('/nonexistent/adb').run(['devices']);
    expect(r3.code, -1);
  });
}
