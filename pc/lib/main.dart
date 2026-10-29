import 'package:flutter/material.dart';

import 'src/adb.dart';
import 'src/controller.dart';
import 'src/pages.dart';
import 'src/store.dart';
import 'src/ui_kit.dart';

const appVersion = '1.0.0';

void main() {
  final c = Controller(ProcessAdb(), Store(), version: appVersion)..start();
  runApp(CleanerApp(c: c));
}

class CleanerApp extends StatelessWidget {
  const CleanerApp({super.key, required this.c, this.startPage = 0});
  final Controller c;
  final int startPage;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Чистый Xiaomi',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: AppShell(c: c, startPage: startPage),
  );
}
