# Сторонние компоненты

| Компонент | Где | Лицензия |
|---|---|---|
| **Android SDK Platform-Tools r37.0.1** — `adb.exe`, `AdbWinApi.dll`, `AdbWinUsbApi.dll` (© Google LLC) | папка `adb\` в установщике; скачивается в CI с `dl.google.com`, SHA-256 проверяется | Распространяются без изменений на условиях Google. Полный текст — `adb\NOTICE.txt` из того же архива (Apache-2.0 и сопутствующие лицензии). Этот репозиторий их **не содержит** и не меняет их лицензию. |
| **Flutter / Dart / Flutter engine** (© Google) | `flutter_windows.dll`, `data\` | BSD-3-Clause |
| Шрифты и иконки Material | `data\flutter_assets` | Apache-2.0 |
| Microsoft Visual C++ Runtime (`msvcp140.dll`, `vcruntime140*.dll`) | рядом с exe | Распространяемые компоненты Visual C++ (лицензия Microsoft) |
| Списки пакетов Xiaomi/Google | `pc/lib/src/catalog_data.dart` | По мотивам [Universal Android Debloater Next Generation](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation), GPL-3.0 |

Собственный код программы — GPL-3.0 (см. `LICENSE`).
