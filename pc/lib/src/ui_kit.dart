import 'package:flutter/material.dart';

class Pal {
  static const red = Color(0xFFE53935);
  static const redDeep = Color(0xFFB71C1C);
  static const redSoft = Color(0xFFFF6B66);
  static const amber = Color(0xFFFFA726);
  static const green = Color(0xFF43A047);
  static const bg = Color(0xFF09090B);
  static const side = Color(0xFF0F0F12);
  static const panel = Color(0xFF16161A);
  static const chip = Color(0xFF1F1F24);
  static const line = Color(0x22FFFFFF);
  static const text = Color(0xFFF2F2F2);
  static const dim = Color(0xFF9A9AA0);
}

ThemeData appTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'Segoe UI');
  return base.copyWith(
    scaffoldBackgroundColor: Pal.bg,
    colorScheme: base.colorScheme.copyWith(primary: Pal.red, secondary: Pal.redSoft, surface: Pal.panel, onPrimary: Colors.white),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Pal.red : Colors.transparent),
      side: const BorderSide(color: Pal.dim, width: 1.4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Pal.dim),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Pal.red : Pal.chip),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Pal.panel,
      titleTextStyle: TextStyle(fontFamily: 'Segoe UI', fontSize: 20, fontWeight: FontWeight.w800, color: Pal.text),
    ),
    textTheme: base.textTheme.apply(bodyColor: Pal.text, displayColor: Pal.text),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.accent = false, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final bool accent;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Pal.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent ? Pal.red.withValues(alpha: .7) : Pal.line),
      gradient: accent ? const LinearGradient(colors: [Color(0xFF2A0F10), Pal.panel], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
    ),
    child: child,
  );
}

class H1 extends StatelessWidget {
  const H1(this.text, {super.key, this.sub});
  final String text;
  final String? sub;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sub!, style: const TextStyle(color: Pal.dim, fontSize: 14)),
          ),
      ],
    ),
  );
}

class Section extends StatelessWidget {
  const Section(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Pal.redSoft, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class Badge2 extends StatelessWidget {
  const Badge2(this.text, {super.key, this.color = Pal.dim});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .5)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

class RedButton extends StatelessWidget {
  const RedButton(this.text, {super.key, this.icon, this.onTap, this.big = false});
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool big;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap,
    icon: Icon(icon ?? Icons.play_arrow_rounded, size: big ? 26 : 18),
    label: Text(
      text,
      style: TextStyle(fontSize: big ? 19 : 14, fontWeight: FontWeight.w700),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: Pal.red,
      disabledBackgroundColor: Pal.chip,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: big ? 34 : 18, vertical: big ? 22 : 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(big ? 18 : 12)),
    ),
  );
}

class GhostButton extends StatelessWidget {
  const GhostButton(this.text, {super.key, this.icon, this.onTap});
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon ?? Icons.chevron_right, size: 18),
    label: Text(text),
    style: OutlinedButton.styleFrom(
      foregroundColor: Pal.text,
      side: const BorderSide(color: Pal.line),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
