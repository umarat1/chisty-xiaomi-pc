// Скриншоты с настоящими шрифтами: flutter test --update-goldens test/shots
import 'dart:io';

import 'package:chisty_xiaomi/main.dart';
import 'package:chisty_xiaomi/src/controller.dart';
import 'package:chisty_xiaomi/src/pages.dart';
import 'package:chisty_xiaomi/src/store.dart';
import 'package:chisty_xiaomi/src/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_adb.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await l.load();
}

void main() {
  setUpAll(() async {
    final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/home/box/sdk/flutter'}/bin/cache/artifacts/material_fonts';
    final roboto = [
      for (final f in ['Regular', 'Medium', 'Bold']) '$dir/Roboto-$f.ttf',
    ];
    await _font('Segoe UI', roboto);
    await _font('Roboto', roboto);
    await _font('MaterialIcons', ['$dir/MaterialIcons-Regular.otf']);
    await _font('Consolas', ['/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf']);
  });

  Future<Controller> make(String state) async {
    final f = FakeAdb(installed: {...sampleSystem, ...sampleUser}, system: {...sampleSystem}, state: state);
    final c = Controller(f, Store(Directory.systemTemp.createTempSync('cxs').path));
    await c.poll();
    return c;
  }

  Future<void> shot(WidgetTester t, Controller c, int page, String name, {Future<void> Function()? before}) async {
    t.view.physicalSize = const Size(1360, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(CleanerApp(c: c, startPage: page));
    if (before != null) await before();
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull);
    await expectLater(find.byType(CleanerApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('01 home disconnected', (t) async {
    final c = await t.runAsync(() => make('none'));
    await shot(t, c!, 0, '01-home-disconnected');
  });
  testWidgets('02 home unauthorized', (t) async {
    final c = await t.runAsync(() => make('unauthorized'));
    await shot(t, c!, 0, '02-home-unauthorized');
  });
  testWidgets('03 home connected', (t) async {
    final c = await t.runAsync(() => make('device'));
    await shot(t, c!, 0, '03-home-connected');
  });
  testWidgets('04 xiaomi', (t) async {
    final c = await t.runAsync(() => make('device'));
    await shot(t, c!, 1, '04-xiaomi-apps');
  });
  testWidgets('05 all apps', (t) async {
    final c = await t.runAsync(() => make('device'));
    c!.selAll.addAll(['com.google.android.youtube', 'com.android.chrome']);
    await shot(t, c, 2, '05-all-apps');
  });
  testWidgets('06 telemetry', (t) async {
    final c = await t.runAsync(() => make('device'));
    await shot(t, c!, 3, '06-telemetry');
  });
  testWidgets('07 speed', (t) async {
    final c = await t.runAsync(() => make('device'));
    await shot(t, c!, 4, '07-speed');
  });
  testWidgets('08 restore', (t) async {
    final c = await t.runAsync(() async {
      final c = await make('device');
      await c.removeIds('x', ['com.miui.analytics', 'com.miui.msa.global', 'com.xiaomi.mipicks', 'com.mi.globalbrowser']);
      c.clearResults();
      return c;
    });
    await shot(t, c!, 5, '08-restore');
  });
  testWidgets('09 log', (t) async {
    final c = await t.runAsync(() async {
      final c = await make('device');
      await c.oneClick();
      c.clearResults();
      return c;
    });
    await shot(t, c!, 6, '09-log');
  });
  testWidgets('10 about', (t) async {
    final c = await t.runAsync(() => make('device'));
    await shot(t, c!, 7, '10-about');
  });
  testWidgets('11 progress', (t) async {
    final c = await t.runAsync(() => make('device'));
    c!.busy = const Progress('Очистка одной кнопкой', 14, 31, 'Mi Браузер');
    await shot(t, c, 0, '11-progress');
  });
  testWidgets('12 results', (t) async {
    final c = await t.runAsync(() async {
      final f = FakeAdb(installed: {...sampleSystem, ...sampleUser}, system: {...sampleSystem})..hang = {'com.miui.daemon'};
      final c = Controller(f, Store(Directory.systemTemp.createTempSync('cxs').path));
      await c.poll();
      await c.oneClick();
      return c;
    });
    await shot(t, c!, 0, '12-results');
  });
  testWidgets('13 hard confirm', (t) async {
    final c = await t.runAsync(() => make('device'));
    await shot(
      t,
      c!,
      2,
      '13-hard-confirm',
      before: () async {
        final ctx = t.element(find.byType(AllAppsPage));
        showDialog<bool>(
          context: ctx,
          builder: (_) => const HardConfirm(hard: ['com.miui.securitycenter', 'com.android.systemui'], total: 3),
        );
        await t.pump();
      },
    );
  });
  testWidgets('14 warn confirm', (t) async {
    final c = await t.runAsync(() => make('device'));
    await shot(
      t,
      c!,
      2,
      '14-warn-confirm',
      before: () async {
        final ctx = t.element(find.byType(AllAppsPage));
        confirmRemoval(ctx, c, ['com.xiaomi.joyose', 'com.miui.gallery', 'com.google.android.youtube']);
        await t.pump();
      },
    );
  });
  test('palette used', () => expect(Pal.red, isNotNull));
}
