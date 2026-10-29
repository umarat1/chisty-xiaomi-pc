import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adb.dart';
import 'catalog.dart';
import 'controller.dart';
import 'ops.dart';
import 'ui_kit.dart';

class NavItem {
  const NavItem(this.title, this.icon);
  final String title;
  final IconData icon;
}

const navItems = [
  NavItem('Главная', Icons.home_rounded),
  NavItem('Приложения Xiaomi', Icons.apps_rounded),
  NavItem('Все приложения', Icons.view_list_rounded),
  NavItem('Телеметрия', Icons.visibility_off_rounded),
  NavItem('Скорость и нагрев', Icons.speed_rounded),
  NavItem('Восстановление', Icons.restore_rounded),
  NavItem('Журнал', Icons.receipt_long_rounded),
  NavItem('О программе', Icons.info_outline_rounded),
];

void openPath(String p) {
  try {
    if (Platform.isWindows) {
      Process.run('explorer.exe', [p]);
    } else {
      Process.run('xdg-open', [p]);
    }
  } catch (_) {}
}

void copyLog(BuildContext context, Controller c) {
  Clipboard.setData(ClipboardData(text: c.logText()));
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Журнал скопирован — вставьте его в сообщение')));
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.c, this.startPage = 0});
  final Controller c;
  final int startPage;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int page = widget.startPage;
  Controller get c => widget.c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              _sidebar(),
              Expanded(child: _page()),
            ],
          ),
          if (c.busy != null) BusyOverlay(c: c),
          if (c.busy == null && (c.results.isNotEmpty || c.resultNote.isNotEmpty)) ResultsOverlay(c: c),
        ],
      ),
    ),
  );

  Widget _page() => switch (page) {
    0 => HomePage(c: c, go: (p) => setState(() => page = p)),
    1 => XiaomiPage(c: c),
    2 => AllAppsPage(c: c),
    3 => TelemetryPage(c: c),
    4 => SpeedPage(c: c),
    5 => RestorePage(c: c),
    6 => LogPage(c: c),
    _ => AboutPage(c: c),
  };

  Widget _sidebar() => Container(
    width: 240,
    color: Pal.side,
    padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppLogo(size: 40),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Чистый Xiaomi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('для Windows', style: TextStyle(color: Pal.dim, fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 26),
        for (var i = 0; i < navItems.length; i++) _navTile(i),
        const Spacer(),
        DeviceChip(c: c),
      ],
    ),
  );

  Widget _navTile(int i) {
    final sel = i == page;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: sel ? Pal.red.withValues(alpha: .16) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => page = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(navItems[i].icon, size: 20, color: sel ? Pal.redSoft : Pal.dim),
                const SizedBox(width: 12),
                Text(
                  navItems[i].title,
                  style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? Pal.text : Pal.dim),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .28),
      gradient: const LinearGradient(colors: [Color(0xFFEF4444), Pal.redDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Icon(Icons.cleaning_services_rounded, color: Colors.white, size: size * .58),
  );
}

class DeviceChip extends StatelessWidget {
  const DeviceChip({super.key, required this.c});
  final Controller c;
  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (c.state) {
      DevState.ready => (Pal.green, c.info?.name.isNotEmpty == true ? c.info!.name : 'Телефон подключён'),
      DevState.unauthorized => (Pal.amber, 'Ждём «Разрешить» на телефоне'),
      DevState.offline => (Pal.amber, 'Телефон offline'),
      DevState.noAdb => (Pal.red, 'adb не запускается'),
      _ => (Pal.dim, 'Телефон не подключён'),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Pal.chip, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Общая обёртка страницы.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.bottom});
  final List<Widget> children;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(36, 30, 36, 30), children: children),
      ),
      ?bottom,
    ],
  );
}

Widget needDevice(Controller c) => Panel(
  child: Row(
    children: [
      const Icon(Icons.usb_rounded, color: Pal.amber),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          c.state == DevState.unauthorized ? 'Разрешите отладку на экране телефона.' : 'Подключите телефон по USB — инструкция на главной.',
          style: const TextStyle(color: Pal.dim),
        ),
      ),
    ],
  ),
);

// ───────────────────────────── Главная
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.c, required this.go});
  final Controller c;
  final void Function(int) go;

  @override
  Widget build(BuildContext context) {
    final ready = c.state == DevState.ready;
    final rec = Catalog.recommended.where((p) => c.isInstalled(p.id)).length;
    final i = c.info;
    return PageBody(
      children: [
        const H1('Чистый Xiaomi', sub: 'Удаление рекламы и телеметрии Xiaomi, ускорение и меньше нагрева — через USB, без root'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Подключение', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    StepRow(
                      n: 1,
                      done: c.state != DevState.none && c.state != DevState.noAdb,
                      title: 'Включите отладку на телефоне',
                      text:
                          'Настройки › О телефоне › 7 раз нажмите «Версия ОС». Затем Настройки › Доп. настройки › Для разработчиков: '
                          'включите «Отладка по USB» и «Отладка по USB (настройки безопасности)».',
                    ),
                    StepRow(
                      n: 2,
                      done: ready,
                      active: c.state == DevState.unauthorized || c.state == DevState.offline,
                      title: 'Подключите кабель и разрешите',
                      text: c.state == DevState.unauthorized || c.state == DevState.offline ? c.stateDetail : 'Подключите телефон к ПК кабелем USB. На телефоне появится «Разрешить отладку по USB?» — отметьте «Всегда разрешать» и нажмите «Разрешить».',
                    ),
                    StepRow(
                      n: 3,
                      done: ready,
                      title: ready ? 'Телефон найден' : 'Телефон определится автоматически',
                      text: ready
                          ? [
                              if (i != null && i.name.isNotEmpty) '${i.name} (${i.model})',
                              if (i != null && i.hyperos.isNotEmpty) i.hyperos,
                              if (i != null && i.android.isNotEmpty) 'Android ${i.android}',
                              if (i?.batteryTemp != null) 'батарея ${i!.batteryTemp!.toStringAsFixed(1)} °C',
                            ].join(' · ')
                          : 'Модель, версия HyperOS и температура батареи появятся здесь.',
                    ),
                    if (c.state == DevState.noAdb) Text('Не удалось запустить adb: ${c.stateDetail}', style: const TextStyle(color: Pal.redSoft)),
                    if (!ready && c.state == DevState.none) const DriverHint(),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          accent: true,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Очистить одной кнопкой', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      ready && c.listError.isNotEmpty
                          ? 'Список приложений не получен: ${c.listError}'
                          : ready
                          ? 'Удалит $rec из ${Catalog.recommended.length} пакетов списка «Рекомендуется» (реклама, аналитика, ненужные сервисы), '
                                'выключит отправку отчётов и фоновое сканирование, ускорит анимации до 0.5x. Всё обратимо.'
                          : 'Станет доступно после подключения телефона. Критичные системные пакеты никогда не удаляются.',
                      style: TextStyle(color: ready && c.listError.isNotEmpty ? Pal.amber : Pal.dim, fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              RedButton('Очистить', icon: Icons.auto_fix_high_rounded, big: true, onTap: ready && c.listError.isEmpty ? () => _confirmOneClick(context) : null),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _tile('Приложения Xiaomi', 'Рекомендуется / Опционально / Опасно', Icons.apps_rounded, () => go(1))),
            const SizedBox(width: 12),
            Expanded(child: _tile('Все приложения', 'Любое приложение, включая системные', Icons.view_list_rounded, () => go(2))),
            const SizedBox(width: 12),
            Expanded(child: _tile('Восстановление', '${ready ? c.removedList.length : 0} удалено — вернуть в один клик', Icons.restore_rounded, () => go(5))),
          ],
        ),
      ],
    );
  }

  Widget _tile(String t, String s, IconData ic, VoidCallback onTap) => Material(
    color: Pal.panel,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pal.line),
        ),
        child: Row(
          children: [
            Icon(ic, color: Pal.redSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(s, style: const TextStyle(color: Pal.dim, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _confirmOneClick(BuildContext context) async {
    final rec = Catalog.recommended.where((p) => c.isInstalled(p.id)).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить одной кнопкой?'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Удалить ${rec.length} пакетов «Рекомендуется» (pm uninstall --user 0 — обратимо)'),
              const Text('• Выключить отправку отчётов, фоновое сканирование Wi‑Fi/Bluetooth и журналы Xiaomi'),
              const Text('• Анимации 0.5x'),
              const SizedBox(height: 10),
              const Text('Список удалённых сохраняется на ПК. Вернуть всё можно на вкладке «Восстановление».', style: TextStyle(color: Pal.dim, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Pal.red),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (ok == true) await c.oneClick();
  }
}

class DriverHint extends StatelessWidget {
  const DriverHint({super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Pal.chip, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Телефон не появляется?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          '1) В шторке телефона выберите режим USB «Передача файлов».  2) Попробуйте другой кабель или порт (не через хаб).  '
          '3) Выключите и включите «Отладка по USB».  4) Если в Диспетчере устройств телефон с жёлтым значком — '
          'установите драйвер ADB (Windows Update › Дополнительные обновления › драйверы, или Google USB Driver).',
          style: TextStyle(color: Pal.dim, fontSize: 13, height: 1.4),
        ),
        TextButton(
          onPressed: () => openPath('https://developer.android.com/studio/run/win-usb'),
          child: const Text('Страница драйвера Google USB', style: TextStyle(color: Pal.redSoft)),
        ),
      ],
    ),
  );
}

class StepRow extends StatelessWidget {
  const StepRow({super.key, required this.n, required this.done, required this.title, required this.text, this.active = false});
  final int n;
  final bool done, active;
  final String title, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? Pal.green : (active ? Pal.amber : Pal.chip)),
          child: done ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : Text('$n', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Text(text, style: TextStyle(color: active ? Pal.amber : Pal.dim, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────────── подтверждения удаления
Future<bool> confirmRemoval(BuildContext context, Controller c, List<String> ids) async {
  if (ids.isEmpty) return false;
  final hard = ids.where((id) => c.riskOf(id) == Risk.hard).toList();
  final warn = ids.where((id) => c.riskOf(id) == Risk.warn).toList();
  if (hard.isNotEmpty) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => HardConfirm(hard: hard, total: ids.length),
    );
    return ok == true;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(warn.isEmpty ? 'Удалить ${ids.length} прил.?' : 'Внимание: опасные пакеты'),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warn.isNotEmpty) ...[
              const Text(
                'Эти пакеты — системные или помечены как опасные. Без них могут перестать работать функции телефона '
                '(галерея, темы, будильник, поиск устройства, управление питанием и т. д.):',
                style: TextStyle(color: Pal.amber),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final id in warn)
                        Text(
                          '• ${Catalog.label(id)}  ($id)${Catalog.byId[id] != null ? ' — ${Catalog.byId[id]!.desc}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const Text(
              'Удаление выполняется для пользователя 0 (pm uninstall --user 0): приложение остаётся в прошивке, его можно вернуть на вкладке «Восстановление».',
              style: TextStyle(color: Pal.dim, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: Pal.red),
          child: Text(warn.isEmpty ? 'Удалить' : 'Понимаю, удалить'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Критичные пакеты: отдельное явное подтверждение — галочка и ввод слова УДАЛИТЬ.
class HardConfirm extends StatefulWidget {
  const HardConfirm({super.key, required this.hard, required this.total});
  final List<String> hard;
  final int total;
  @override
  State<HardConfirm> createState() => _HardConfirmState();
}

class _HardConfirmState extends State<HardConfirm> {
  bool agree = false;
  final word = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final can = agree && word.text.trim().toUpperCase() == 'УДАЛИТЬ';
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Pal.red),
          SizedBox(width: 10),
          Text('Критичные системные пакеты'),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Без этих пакетов телефон может зависнуть на логотипе (бутлуп), потерять связь, рабочий стол или возможность устанавливать приложения. '
              'Если телефон перестанет загружаться, поможет только сброс к заводским настройкам (данные будут потеряны).',
              style: TextStyle(color: Pal.redSoft, height: 1.4),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final id in widget.hard) Text('• ${Catalog.label(id)}  ($id)', style: const TextStyle(fontSize: 12))],
                ),
              ),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: agree,
              onChanged: (v) => setState(() => agree = v == true),
              title: const Text('Я понимаю риск и делаю это на свой страх и риск'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            TextField(
              controller: word,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Введите слово УДАЛИТЬ', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        FilledButton(
          onPressed: can ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: Pal.redDeep),
          child: Text('Удалить ${widget.total}'),
        ),
      ],
    );
  }
}

Widget removeBar(BuildContext context, Controller c, Set<String> sel, String title, {bool allowHard = false}) => Container(
  padding: const EdgeInsets.fromLTRB(36, 14, 36, 14),
  decoration: const BoxDecoration(
    color: Pal.side,
    border: Border(top: BorderSide(color: Pal.line)),
  ),
  child: Row(
    children: [
      Text('Выбрано: ${sel.length}', style: const TextStyle(color: Pal.dim)),
      const SizedBox(width: 12),
      if (sel.isNotEmpty)
        TextButton(
          onPressed: () {
            sel.clear();
            c.notify();
          },
          child: const Text('Снять выбор', style: TextStyle(color: Pal.dim)),
        ),
      const Spacer(),
      RedButton(
        'Удалить выбранные',
        icon: Icons.delete_sweep_rounded,
        onTap: sel.isEmpty || c.state != DevState.ready
            ? null
            : () async {
                final ids = sel.where(c.isInstalled).toList();
                if (await confirmRemoval(context, c, ids)) {
                  final hard = ids.any((id) => c.riskOf(id) == Risk.hard);
                  sel.clear();
                  await c.removeIds(title, ids, allowHard: allowHard && hard);
                }
              },
      ),
    ],
  ),
);

// ───────────────────────────── Приложения Xiaomi
class XiaomiPage extends StatelessWidget {
  const XiaomiPage({super.key, required this.c});
  final Controller c;
  @override
  Widget build(BuildContext context) {
    final ready = c.state == DevState.ready;
    return PageBody(
      bottom: removeBar(context, c, c.selXiaomi, 'Удаление выбранных'),
      children: [
        const H1('Приложения Xiaomi', sub: 'Проверенные списки для HyperOS. Показаны только установленные на телефоне пакеты.'),
        if (!ready) needDevice(c),
        for (final t in [Tier.recommended, Tier.optional, Tier.risky]) ..._tier(t, ready),
      ],
    );
  }

  List<Widget> _tier(Tier t, bool ready) {
    final list = Catalog.tier(t).where((p) => !ready || c.isInstalled(p.id)).toList();
    final all = list.isNotEmpty && list.every((p) => c.selXiaomi.contains(p.id));
    final desc = switch (t) {
      Tier.recommended => 'Реклама, аналитика и ненужные сервисы — безопасно удалять.',
      Tier.optional => 'Рабочие приложения Xiaomi: удаляйте, если не пользуетесь.',
      Tier.risky => 'Может сломать функции телефона — каждое удаление с предупреждением.',
      Tier.protectedHard => '',
    };
    return [
      Section(
        '${t.title} · ${list.length}',
        trailing: list.isEmpty
            ? null
            : TextButton(
                onPressed: () {
                  if (all) {
                    c.selXiaomi.removeAll(list.map((p) => p.id));
                  } else {
                    c.selXiaomi.addAll(list.map((p) => p.id));
                  }
                  c.notify();
                },
                child: Text(all ? 'Снять все' : 'Выбрать все', style: const TextStyle(color: Pal.redSoft)),
              ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(desc, style: const TextStyle(color: Pal.dim, fontSize: 13)),
      ),
      Panel(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Нет установленных пакетов из этого списка', style: TextStyle(color: Pal.dim)),
              )
            : Column(
                children: [
                  for (final p in list)
                    PkgRow(
                      id: p.id,
                      title: p.title,
                      desc: p.desc,
                      selected: c.selXiaomi.contains(p.id),
                      badges: [
                        if (p.telemetry) const Badge2('телеметрия', color: Pal.amber),
                        if (t == Tier.risky) const Badge2('опасно', color: Pal.red),
                      ],
                      onChanged: (v) {
                        v ? c.selXiaomi.add(p.id) : c.selXiaomi.remove(p.id);
                        c.notify();
                      },
                    ),
                ],
              ),
      ),
    ];
  }
}

class PkgRow extends StatelessWidget {
  const PkgRow({
    super.key,
    required this.id,
    required this.title,
    this.desc = '',
    required this.selected,
    required this.onChanged,
    this.badges = const [],
    this.trailing,
  });
  final String id, title, desc;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final List<Widget> badges;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!selected),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Checkbox(value: selected, onChanged: (v) => onChanged(v == true)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...badges,
                  ],
                ),
                Text(
                  desc.isEmpty ? id : '$id · $desc',
                  style: const TextStyle(color: Pal.dim, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

// ───────────────────────────── Все приложения
enum AppFilter { all, system, user, xiaomi, google }

class AllAppsPage extends StatefulWidget {
  const AllAppsPage({super.key, required this.c});
  final Controller c;
  @override
  State<AllAppsPage> createState() => _AllAppsPageState();
}

class _AllAppsPageState extends State<AllAppsPage> {
  String q = '';
  AppFilter f = AppFilter.all;
  Controller get c => widget.c;

  @override
  Widget build(BuildContext context) {
    final ready = c.state == DevState.ready;
    final list = c.installed.where((p) {
      final ok = switch (f) {
        AppFilter.all => true,
        AppFilter.system => p.system,
        AppFilter.user => !p.system,
        AppFilter.xiaomi => Catalog.isXiaomi(p.id),
        AppFilter.google => Catalog.isGoogle(p.id),
      };
      if (!ok) return false;
      if (q.isEmpty) return true;
      final s = q.toLowerCase();
      return p.id.toLowerCase().contains(s) || Catalog.label(p.id).toLowerCase().contains(s);
    }).toList()..sort((a, b) => Catalog.label(a.id).toLowerCase().compareTo(Catalog.label(b.id).toLowerCase()));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 30, 36, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              H1('Все приложения', sub: 'Любое установленное приложение, включая системные (${c.installed.length}). Удаление — для пользователя 0, обратимо.'),
              if (!ready) needDevice(c),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => q = v.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Поиск по названию или пакету',
                        filled: true,
                        fillColor: Pal.panel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Pal.line),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final (v, t) in [
                    (AppFilter.all, 'Все'),
                    (AppFilter.system, 'Системные'),
                    (AppFilter.user, 'Пользовательские'),
                    (AppFilter.xiaomi, 'Xiaomi'),
                    (AppFilter.google, 'Google'),
                  ])
                    ChoiceChip(
                      label: Text(t),
                      selected: f == v,
                      onSelected: (_) => setState(() => f = v),
                      selectedColor: Pal.red.withValues(alpha: .25),
                      side: BorderSide(color: f == v ? Pal.red : Pal.line),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Показано: ${list.length}', style: const TextStyle(color: Pal.dim, fontSize: 12)),
                  const SizedBox(width: 18),
                  const Icon(Icons.lock_rounded, size: 13, color: Pal.red),
                  const Text(' критично — двойное подтверждение   ', style: TextStyle(color: Pal.dim, fontSize: 12)),
                  const Icon(Icons.warning_amber_rounded, size: 13, color: Pal.amber),
                  const Text(' опасно — предупреждение', style: TextStyle(color: Pal.dim, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(36, 0, 36, 16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              final r = c.riskOf(p.id);
              return PkgRow(
                id: p.id,
                title: Catalog.label(p.id),
                desc: Catalog.byId[p.id]?.desc ?? '',
                selected: c.selAll.contains(p.id),
                badges: [
                  if (p.system) const Badge2('системное') else const Badge2('пользовательское', color: Pal.green),
                  if (Catalog.byId[p.id]?.tier == Tier.recommended) const Badge2('рекомендуется', color: Pal.green),
                ],
                trailing: switch (r) {
                  Risk.hard => const Tooltip(
                    message: 'Критично для системы',
                    child: Icon(Icons.lock_rounded, color: Pal.red, size: 18),
                  ),
                  Risk.warn => const Tooltip(
                    message: 'Опасно',
                    child: Icon(Icons.warning_amber_rounded, color: Pal.amber, size: 18),
                  ),
                  Risk.normal => null,
                },
                onChanged: (v) {
                  v ? c.selAll.add(p.id) : c.selAll.remove(p.id);
                  c.notify();
                },
              );
            },
          ),
        ),
        removeBar(context, c, c.selAll, 'Удаление приложений', allowHard: true),
      ],
    );
  }
}

// ───────────────────────────── Телеметрия
class TelemetryPage extends StatelessWidget {
  const TelemetryPage({super.key, required this.c});
  final Controller c;
  @override
  Widget build(BuildContext context) {
    final ready = c.state == DevState.ready;
    final tel = Catalog.telemetry;
    final left = tel.where((p) => c.isInstalled(p.id)).length;
    return PageBody(
      children: [
        const H1('Телеметрия и реклама', sub: 'Службы аналитики Xiaomi и отправка отчётов'),
        if (!ready) needDevice(c),
        Panel(
          accent: true,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ready ? 'Установлено служб слежки: $left из ${tel.length}. Кнопка удалит их и выключит отправку отчётов.' : 'Подключите телефон.',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              RedButton('Выключить телеметрию', icon: Icons.visibility_off_rounded, onTap: ready ? c.disableTelemetry : null),
            ],
          ),
        ),
        const Section('Переключатели (обратимые)'),
        for (final t in Toggles.telemetry) ToggleCard(c: c, t: t),
        const Section('Службы телеметрии'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            children: [
              for (final p in tel)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        ready && !c.isInstalled(p.id) ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 18,
                        color: ready && !c.isInstalled(p.id) ? Pal.green : Pal.dim,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${p.title} — ${p.desc}', style: const TextStyle(fontSize: 13))),
                      Text(!ready ? '' : (c.isInstalled(p.id) ? 'установлено' : 'удалено'), style: const TextStyle(color: Pal.dim, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Section('Честно о пределах'),
        const Panel(
          child: Text(
            'Без root нельзя удалить системные службы из прошивки — только отключить их для пользователя (это и делает программа). '
            'Часть данных Xiaomi отправляют сервисы, без которых телефон не работает (Security, XMSF) — они защищены. '
            'Private DNS AdGuard дополнительно режет трекеры на уровне сети. После сброса к заводским настройкам всё вернётся.',
            style: TextStyle(color: Pal.dim, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class ToggleCard extends StatelessWidget {
  const ToggleCard({super.key, required this.c, required this.t});
  final Controller c;
  final Toggle t;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(t.desc + (t.note.isEmpty ? '' : ' (${t.note})'), style: const TextStyle(color: Pal.dim, fontSize: 13)),
              ],
            ),
          ),
          Switch(value: c.toggles[t.id] ?? false, onChanged: c.state == DevState.ready ? (v) => c.setToggle(t, v) : null),
        ],
      ),
    ),
  );
}

// ───────────────────────────── Скорость
class SpeedPage extends StatelessWidget {
  const SpeedPage({super.key, required this.c});
  final Controller c;
  @override
  Widget build(BuildContext context) {
    final ready = c.state == DevState.ready;
    final bt = c.info?.batteryTemp;
    return PageBody(
      children: [
        const H1('Скорость и нагрев', sub: 'Ускорение интерфейса, оптимизация приложений и контроль температуры'),
        if (!ready) needDevice(c),
        Panel(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.thermostat_rounded, color: Pal.amber, size: 34),
                  const SizedBox(width: 10),
                  Text(bt == null ? '— °C' : '${bt.toStringAsFixed(1)} °C', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  Text(
                    bt == null
                        ? ''
                        : 'батарея · ${bt < 38
                              ? 'нагрева нет'
                              : bt < 42
                              ? 'лёгкий нагрев'
                              : 'сильный нагрев'}',
                    style: const TextStyle(color: Pal.dim),
                  ),
                  const Spacer(),
                  IconButton(onPressed: ready ? c.loadTemps : null, icon: const Icon(Icons.refresh_rounded), tooltip: 'Обновить'),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 22,
                runSpacing: 6,
                children: [
                  for (final s in c.temps.take(8))
                    Text('${s.name}: ${s.value.toStringAsFixed(1)} °C', style: TextStyle(fontSize: 13, color: s.value >= 45 ? Pal.redSoft : Pal.dim)),
                ],
              ),
            ],
          ),
        ),
        const Section('Быстрые действия'),
        _action(
          'Оптимизировать приложения',
          'cmd package compile -m speed-profile -a — быстрее запуск и меньше нагрузка. 5–15 минут, телефон может нагреться во время работы.',
          ready ? c.optimize : null,
        ),
        _action('Фоновая оптимизация (как ночью на зарядке)', 'cmd package bg-dexopt-job — оптимизирует то, что система не успела.', ready ? c.bgDexopt : null),
        _action('Закрыть фоновые процессы', 'am kill-all — завершает кэшированные фоновые процессы. Безопасно.', ready ? c.killBg : null),
        _action('Очистить кэш приложений', 'pm trim-caches — освобождает кэш (данные и входы не трогаются).', ready ? c.trimCaches : null),
        const Section('Переключатели (обратимые)'),
        for (final t in Toggles.performance) ToggleCard(c: c, t: t),
        const Section('Советы против перегрева'),
        const Panel(
          child: Text(
            '• Не удаляйте Joyose (com.xiaomi.joyose) — он управляет тепловыми профилями.\n'
            '• Не играйте и не снимайте 4K на зарядке.\n'
            '• Режим «Баланс» в Батарее и 60 Гц заметно снижают нагрев.\n'
            '• Чехол без утепления и снятие телефона с солнца дают больше, чем любые твики.',
            style: TextStyle(color: Pal.dim, height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _action(String t, String d, VoidCallback? onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(d, style: const TextStyle(color: Pal.dim, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RedButton('Пуск', onTap: onTap),
        ],
      ),
    ),
  );
}

// ───────────────────────────── Восстановление
class RestorePage extends StatefulWidget {
  const RestorePage({super.key, required this.c});
  final Controller c;
  @override
  State<RestorePage> createState() => _RestorePageState();
}

class _RestorePageState extends State<RestorePage> {
  final sel = <String>{};
  Controller get c => widget.c;
  @override
  Widget build(BuildContext context) {
    final ready = c.state == DevState.ready;
    final list = ready ? c.removedList : <String>[];
    final saved = ready ? c.store.removed(c.serial) : <String, String>{};
    return PageBody(
      bottom: Container(
        padding: const EdgeInsets.fromLTRB(36, 14, 36, 14),
        decoration: const BoxDecoration(
          color: Pal.side,
          border: Border(top: BorderSide(color: Pal.line)),
        ),
        child: Row(
          children: [
            GhostButton('Папка резервной копии', icon: Icons.folder_open_rounded, onTap: () => openPath(c.store.dir)),
            const Spacer(),
            GhostButton(
              'Вернуть выбранные (${sel.length})',
              icon: Icons.restore_rounded,
              onTap: sel.isEmpty || !ready
                  ? null
                  : () {
                      final l = sel.toList();
                      sel.clear();
                      c.restore(l);
                    },
            ),
            const SizedBox(width: 10),
            RedButton(
              'Вернуть все из копии (${saved.length})',
              icon: Icons.settings_backup_restore_rounded,
              onTap: saved.isEmpty || !ready ? null : () => c.restore(saved.keys.toList()),
            ),
          ],
        ),
      ),
      children: [
        const H1('Восстановление', sub: 'Возврат удалённых приложений: cmd package install-existing --user 0'),
        if (!ready) needDevice(c),
        Panel(
          child: Text(
            'Список удалённых сохраняется на ПК: ${c.store.dir}. Здесь показаны и пакеты из копии, и всё, что телефон считает удалённым для пользователя 0 '
            '(даже если удалялось другой программой).',
            style: const TextStyle(color: Pal.dim, fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Удалённых приложений нет', style: TextStyle(color: Pal.dim)),
                )
              : Column(
                  children: [
                    for (final id in list)
                      PkgRow(
                        id: id,
                        title: Catalog.label(id),
                        desc: saved[id] != null ? 'удалено ${saved[id]!.replaceFirst('T', ' ')}' : '',
                        selected: sel.contains(id),
                        badges: [if (c.isInstalled(id)) const Badge2('уже установлено', color: Pal.green)],
                        trailing: TextButton(
                          onPressed: ready ? () => c.restore([id]) : null,
                          child: const Text('Вернуть', style: TextStyle(color: Pal.redSoft)),
                        ),
                        onChanged: (v) => setState(() => v ? sel.add(id) : sel.remove(id)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ───────────────────────────── Журнал
class LogPage extends StatelessWidget {
  const LogPage({super.key, required this.c});
  final Controller c;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(36, 30, 36, 12),
        child: Row(
          children: [
            const Expanded(child: H1('Журнал', sub: 'Все команды и результаты. Пришлите его, если что-то пошло не так.')),
            GhostButton('Скопировать', icon: Icons.copy_rounded, onTap: () => copyLog(context, c)),
            const SizedBox(width: 8),
            GhostButton(
              'Сохранить в файл',
              icon: Icons.save_alt_rounded,
              onTap: () {
                final p = c.store.saveLog(c.logText());
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text('Сохранено: $p'),
                    action: SnackBarAction(label: 'Открыть папку', onPressed: () => openPath(File(p).parent.path)),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            GhostButton('Очистить', icon: Icons.delete_outline_rounded, onTap: c.clearLog),
          ],
        ),
      ),
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(36, 0, 36, 30),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Pal.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Pal.line),
          ),
          child: c.log.isEmpty
              ? const Text('Пока пусто', style: TextStyle(color: Pal.dim))
              : Align(
                  alignment: Alignment.topLeft,
                  child: ListView.builder(
                    reverse: true,
                    shrinkWrap: true,
                    itemCount: c.log.length,
                    itemBuilder: (_, i) {
                      final l = c.log[c.log.length - 1 - i];
                      final bad = l.contains('Не удалось') || l.contains('Ошибка') || l.contains('Таймаут');
                      return SelectableText(
                        l,
                        style: TextStyle(fontFamily: 'Consolas', fontSize: 12.5, height: 1.5, color: bad ? Pal.redSoft : Pal.text),
                      );
                    },
                  ),
                ),
        ),
      ),
    ],
  );
}

// ───────────────────────────── О программе
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.c});
  final Controller c;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Row(
        children: [
          const AppLogo(size: 84),
          const SizedBox(width: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Чистый Xiaomi для Windows', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text('Версия ${c.version}', style: const TextStyle(color: Pal.dim)),
              const SizedBox(height: 6),
              const Text('Автор: Урдуханов Марат Закирович', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => openPath('https://sessia.top'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('sessia.top', style: TextStyle(color: Pal.redSoft)),
              ),
            ],
          ),
        ],
      ),
      const Section('Как это работает'),
      const Panel(
        child: Text(
          'Программа использует официальный adb от Google (входит в комплект) и подключается к телефону по USB с правами отладки — '
          'так же, как Android Studio. Root не нужен, загрузчик не разблокируется, гарантия сохраняется. '
          'Приложения удаляются только для пользователя (pm uninstall --user 0) и возвращаются командой install-existing. '
          'Каждая команда ограничена по времени, зависшие пропускаются, операцию можно отменить.',
          style: TextStyle(color: Pal.dim, height: 1.5),
        ),
      ),
      const Section('Лицензии'),
      const Panel(
        child: Text(
          '• Android SDK Platform-Tools (adb.exe, AdbWinApi.dll, AdbWinUsbApi.dll) — © Google LLC, распространяются в неизменном виде, см. adb\\NOTICE.txt\n'
          '• Списки пакетов — по мотивам Universal Android Debloater Next Generation, GPL-3.0\n'
          '• Flutter — © Google, BSD-3-Clause; шрифты и иконки Material — Apache-2.0',
          style: TextStyle(color: Pal.dim, height: 1.6, fontSize: 13),
        ),
      ),
    ],
  );
}

// ───────────────────────────── прогресс и результаты
class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key, required this.c});
  final Controller c;
  @override
  Widget build(BuildContext context) {
    final p = c.busy!;
    return Container(
      color: const Color(0xCC000000),
      alignment: Alignment.center,
      child: SizedBox(
        width: 520,
        child: Panel(
          accent: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: p.total > 0 ? p.done / p.total : null,
                color: Pal.red,
                backgroundColor: Pal.chip,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 10),
              Text(
                p.total > 0 ? '${p.done} / ${p.total}   ${p.current}' : p.current,
                style: const TextStyle(color: Pal.dim),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              const Text('Каждая команда ограничена по времени — зависшие пропускаются.', style: TextStyle(color: Pal.dim, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => copyLog(context, c),
                    child: const Text('Скопировать лог', style: TextStyle(color: Pal.dim)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: c.cancel,
                    style: FilledButton.styleFrom(backgroundColor: Pal.chip),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(color: Pal.redSoft, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultsOverlay extends StatelessWidget {
  const ResultsOverlay({super.key, required this.c});
  final Controller c;
  @override
  Widget build(BuildContext context) {
    final ok = c.results.where((r) => r.ok).length;
    final all = ok == c.results.length && c.resultNote.isEmpty;
    return Container(
      color: const Color(0xCC000000),
      alignment: Alignment.center,
      child: SizedBox(
        width: 620,
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.resultTitle, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (c.results.isNotEmpty)
                Text(
                  'Успешно: $ok из ${c.results.length}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: all ? Pal.green : Pal.amber),
                ),
              if (c.resultNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(c.resultNote, style: const TextStyle(color: Pal.amber, fontSize: 13)),
                ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in c.results)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(r.ok ? Icons.check_rounded : Icons.close_rounded, size: 16, color: r.ok ? Pal.green : Pal.redSoft),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${Catalog.byId[r.id]?.title ?? (Catalog.safePkg(r.id) ? Catalog.label(r.id) : r.id)}${r.ok ? '' : ' — ${r.msg}'}',
                                  style: TextStyle(fontSize: 13, color: r.ok ? Pal.text : Pal.redSoft),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => copyLog(context, c),
                    child: const Text('Скопировать лог', style: TextStyle(color: Pal.dim)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: c.clearResults,
                    style: FilledButton.styleFrom(backgroundColor: Pal.red),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
