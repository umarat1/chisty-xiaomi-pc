import 'catalog_data.dart';
export 'catalog_data.dart';

/// Насколько рискованно удалять пакет.
enum Risk {
  /// Обычное удаление (с простым подтверждением).
  normal,

  /// «Опасно»: предупреждение перед удалением.
  warn,

  /// Критично для загрузки системы: нужно отдельное явное подтверждение.
  hard,
}

class Catalog {
  static final Map<String, Pkg> byId = {for (final p in catalogAll) p.id: p};
  static List<Pkg> tier(Tier t) => catalogAll.where((p) => p.tier == t).toList();
  static List<Pkg> get recommended => tier(Tier.recommended);
  static List<Pkg> get telemetry => catalogAll.where((p) => p.telemetry).toList();

  /// Короткий «жёсткий» список: без этих пакетов HyperOS может не загрузиться или потерять связь/установку приложений.
  static const hardExact = {
    'android',
    'com.android.systemui',
    'com.android.settings',
    'com.android.phone',
    'com.android.server.telecom',
    'com.android.shell',
    'com.android.packageinstaller',
    'com.google.android.packageinstaller',
    'com.miui.global.packageinstaller',
    'com.android.permissioncontroller',
    'com.google.android.permissioncontroller',
    'com.android.networkstack',
    'com.google.android.networkstack',
    'com.miui.home',
    'com.miui.securitycenter',
    'com.miui.securityadd',
    'com.miui.securitycore',
    'com.lbe.security.miui',
    'com.miui.rom',
    'com.miui.core',
    'com.miui.system',
    'com.xiaomi.xmsf',
    'com.xiaomi.micloud.sdk',
  };

  static const hardPrefixes = [
    'com.android.providers.',
    'com.google.android.providers.',
    'com.mediatek.',
    'vendor.mediatek.',
    'com.mtk.',
    'com.android.networkstack.',
    'com.google.android.networkstack.',
  ];

  static bool isHard(String id, {Set<String> dynamic = const {}}) =>
      hardExact.contains(id) || byId[id]?.tier == Tier.protectedHard || dynamic.contains(id) || hardPrefixes.any(id.startsWith);

  /// Классификация для вкладки «Все приложения».
  static Risk risk(String id, {required bool system, Set<String> dynamic = const {}}) {
    if (isHard(id, dynamic: dynamic)) return Risk.hard;
    final p = byId[id];
    if (p != null) {
      return switch (p.tier) {
        Tier.recommended || Tier.optional => Risk.normal,
        Tier.risky => Risk.warn,
        Tier.protectedHard => Risk.hard,
      };
    }
    // Неизвестный системный пакет — «Опасно», пользовательское приложение — обычное.
    return system ? Risk.warn : Risk.normal;
  }

  static bool isXiaomi(String id) =>
      id.startsWith('com.miui.') ||
      id.startsWith('com.xiaomi.') ||
      id.startsWith('com.mi.') ||
      id.startsWith('com.milink.') ||
      id.startsWith('com.mipay.') ||
      id.startsWith('com.mfashiongallery.') ||
      id.startsWith('com.lbe.') ||
      id.startsWith('miui.');

  static bool isGoogle(String id) => id.startsWith('com.google.') || id == 'com.android.vending';

  static final _safe = RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$');

  /// Имя пакета безопасно подставлять в команду (защита от инъекций).
  static bool safePkg(String p) => p == 'android' || _safe.hasMatch(p);

  /// Человекочитаемое название: из каталога, из словаря известных или из имени пакета.
  static String label(String id) {
    final p = byId[id];
    if (p != null) return p.title;
    final k = known[id];
    if (k != null) return k;
    final parts = id.split('.');
    var last = parts.last;
    if (const {'android', 'app', 'apps', 'global', 'overlay', 'service', 'services'}.contains(last) && parts.length > 1) {
      last = '${parts[parts.length - 2]} $last';
    }
    return last.isEmpty ? id : last[0].toUpperCase() + last.substring(1);
  }

  static const known = {
    'com.google.android.youtube': 'YouTube',
    'com.google.android.apps.youtube.music': 'YouTube Music',
    'com.google.android.gm': 'Gmail',
    'com.google.android.apps.maps': 'Google Карты',
    'com.google.android.apps.photos': 'Google Фото',
    'com.google.android.apps.docs': 'Google Диск',
    'com.google.android.googlequicksearchbox': 'Google',
    'com.google.android.apps.messaging': 'Google Сообщения',
    'com.google.android.dialer': 'Google Телефон',
    'com.google.android.contacts': 'Google Контакты',
    'com.google.android.calendar': 'Google Календарь',
    'com.google.android.apps.wellbeing': 'Цифровое благополучие',
    'com.google.android.apps.tachyon': 'Google Meet',
    'com.google.android.videos': 'Google TV',
    'com.google.android.apps.googleassistant': 'Google Ассистент',
    'com.google.android.apps.nbu.files': 'Files by Google',
    'com.google.android.apps.safetyhub': 'Личная безопасность',
    'com.google.android.marvin.talkback': 'TalkBack',
    'com.google.android.tts': 'Синтез речи Google',
    'com.google.ar.lens': 'Google Lens',
    'com.android.chrome': 'Chrome',
    'com.android.vending': 'Google Play',
    'com.google.android.gms': 'Сервисы Google Play',
    'com.android.bluetooth': 'Bluetooth',
    'com.android.nfc': 'NFC',
    'com.android.stk': 'SIM-меню',
    'com.android.printspooler': 'Печать',
    'com.android.bips': 'Печать (встроенная)',
    'com.android.wallpaperbackup': 'Резервная копия обоев',
    'com.android.dreams.basic': 'Заставка',
    'com.android.egg': 'Пасхалка Android',
    'com.facebook.katana': 'Facebook',
    'com.instagram.android': 'Instagram',
    'com.whatsapp': 'WhatsApp',
    'org.telegram.messenger': 'Telegram',
    'com.netflix.mediaclient': 'Netflix',
    'com.spotify.music': 'Spotify',
    'com.amazon.mShop.android.shopping': 'Amazon',
    'com.booking': 'Booking.com',
    'com.linkedin.android': 'LinkedIn',
    'com.microsoft.office.outlook': 'Outlook',
    'com.microsoft.skydrive': 'OneDrive',
    'com.ebay.mobile': 'eBay',
    'com.zhiliaoapp.musically': 'TikTok',
    'ru.yandex.searchplugin': 'Яндекс',
    'ru.yandex.yandexmaps': 'Яндекс Карты',
  };
}
