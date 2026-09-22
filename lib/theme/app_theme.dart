import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeId {
  classic,
  lol,
  valorant,
  minecraft,
  facebook,
  shopee,
  tiktok,
  ben10,
  youtube,
  steam,
}

enum AppThemeGeometry { rounded, square, valorant, lol, pixel }

extension AppThemeIdUi on AppThemeId {
  String get storageKey => name;

  String get label => switch (this) {
    AppThemeId.classic => 'Better mặc định',
    AppThemeId.lol => 'League of Legends',
    AppThemeId.valorant => 'Valorant',
    AppThemeId.minecraft => 'Minecraft',
    AppThemeId.facebook => 'Facebook',
    AppThemeId.shopee => 'Shopee',
    AppThemeId.tiktok => 'TikTok',
    AppThemeId.ben10 => 'Ben 10',
    AppThemeId.youtube => 'YouTube',
    AppThemeId.steam => 'Steam',
  };

  String get caption => switch (this) {
    AppThemeId.classic => 'Sạch, xanh, quen thuộc',
    AppThemeId.lol => 'Hextech • vàng • lam ngọc',
    AppThemeId.valorant => 'Tactical • đỏ • góc cắt',
    AppThemeId.minecraft => 'Pixel • đất • nút khối',
    AppThemeId.facebook => 'Feed sáng • xanh Facebook',
    AppThemeId.shopee => 'Cam thương mại • card sáng',
    AppThemeId.tiktok => 'Đen • hồng • cyan',
    AppThemeId.ben10 => 'Omnitrix • đen • xanh neon',
    AppThemeId.youtube => 'Dark feed • đỏ video',
    AppThemeId.steam => 'Store dark • xanh Steam',
  };

  IconData get icon => switch (this) {
    AppThemeId.classic => Icons.check_rounded,
    AppThemeId.lol => Icons.auto_awesome_rounded,
    AppThemeId.valorant => Icons.change_history_rounded,
    AppThemeId.minecraft => Icons.view_in_ar_rounded,
    AppThemeId.facebook => Icons.facebook,
    AppThemeId.shopee => Icons.shopping_bag_rounded,
    AppThemeId.tiktok => Icons.music_note_rounded,
    AppThemeId.ben10 => Icons.watch_rounded,
    AppThemeId.youtube => Icons.play_circle_fill_rounded,
    AppThemeId.steam => Icons.sports_esports_rounded,
  };
}

@immutable
class AppThemePalette {
  const new({
    required this.id,
    required this.pageStart,
    required this.pageEnd,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.primary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
    required this.widgetStart,
    required this.widgetEnd,
    required this.widgetText,
    required this.widgetSubtext,
    required this.radius,
    required this.geometry,
    required this.dark,
    this.fontFamily,
  });

  final AppThemeId id;
  final Color pageStart;
  final Color pageEnd;
  final Color surface;
  final Color card;
  final Color cardAlt;
  final Color primary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;
  final Color widgetStart;
  final Color widgetEnd;
  final Color widgetText;
  final Color widgetSubtext;
  final double radius;
  final AppThemeGeometry geometry;
  final bool dark;
  final String? fontFamily;
}

const Map<AppThemeId, AppThemePalette> appThemePalettes =
    <AppThemeId, AppThemePalette>{
      AppThemeId.classic: AppThemePalette(
        id: AppThemeId.classic,
        pageStart: Color(0xFFF9FBFF),
        pageEnd: Color(0xFFF2F6FF),
        surface: Color(0xFFFFFFFF),
        card: Color(0xFFFFFFFF),
        cardAlt: Color(0xFFF3F6FC),
        primary: Color(0xFF1747B5),
        accent: Color(0xFF4A89FF),
        textPrimary: Color(0xFF102B73),
        textSecondary: Color(0xFF7180A0),
        border: Color(0xFFE8EDF7),
        shadow: Color(0x18193B80),
        widgetStart: Color(0xFF173A8E),
        widgetEnd: Color(0xFF315AB5),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFFDDE8FF),
        radius: 14,
        geometry: AppThemeGeometry.rounded,
        dark: false,
      ),
      AppThemeId.lol: AppThemePalette(
        id: AppThemeId.lol,
        pageStart: Color(0xFF030B10),
        pageEnd: Color(0xFF071821),
        surface: Color(0xFF07161D),
        card: Color(0xFF0B1A21),
        cardAlt: Color(0xFF0F252D),
        primary: Color(0xFF0AC8B9),
        accent: Color(0xFFC89B3C),
        textPrimary: Color(0xFFF0E6D2),
        textSecondary: Color(0xFF9D947F),
        border: Color(0xFF785A28),
        shadow: Color(0x66000000),
        widgetStart: Color(0xFF06131A),
        widgetEnd: Color(0xFF0B343A),
        widgetText: Color(0xFFF0E6D2),
        widgetSubtext: Color(0xFFC8AA6E),
        radius: 2,
        geometry: AppThemeGeometry.lol,
        dark: true,
      ),
      AppThemeId.valorant: AppThemePalette(
        id: AppThemeId.valorant,
        pageStart: Color(0xFF0F1923),
        pageEnd: Color(0xFF111D27),
        surface: Color(0xFF111D27),
        card: Color(0xFF14222D),
        cardAlt: Color(0xFF1D2A34),
        primary: Color(0xFFFF4655),
        accent: Color(0xFFECE8E1),
        textPrimary: Color(0xFFECE8E1),
        textSecondary: Color(0xFF9AA7AD),
        border: Color(0xFF3A4A55),
        shadow: Color(0x66000000),
        widgetStart: Color(0xFF0F1923),
        widgetEnd: Color(0xFF24313B),
        widgetText: Color(0xFFECE8E1),
        widgetSubtext: Color(0xFFFF7B86),
        radius: 2,
        geometry: AppThemeGeometry.valorant,
        dark: true,
      ),
      AppThemeId.minecraft: AppThemePalette(
        id: AppThemeId.minecraft,
        pageStart: Color(0xFF5C3922),
        pageEnd: Color(0xFF352116),
        surface: Color(0xFF261D16),
        card: Color(0xFF30241B),
        cardAlt: Color(0xFF5D5D5D),
        primary: Color(0xFF8BC34A),
        accent: Color(0xFFFFFFFF),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFD8D1C9),
        border: Color(0xFF0B0907),
        shadow: Color(0x77000000),
        widgetStart: Color(0xFF3A2B20),
        widgetEnd: Color(0xFF6B4A2F),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFFD8D1C9),
        radius: 0,
        geometry: AppThemeGeometry.pixel,
        dark: true,
        fontFamily: 'MinecraftCustom',
      ),
      AppThemeId.facebook: AppThemePalette(
        id: AppThemeId.facebook,
        pageStart: Color(0xFFF0F2F5),
        pageEnd: Color(0xFFF0F2F5),
        surface: Color(0xFFF0F2F5),
        card: Color(0xFFFFFFFF),
        cardAlt: Color(0xFFE7F3FF),
        primary: Color(0xFF0866FF),
        accent: Color(0xFF0866FF),
        textPrimary: Color(0xFF050505),
        textSecondary: Color(0xFF65676B),
        border: Color(0xFFE4E6EB),
        shadow: Color(0x18000000),
        widgetStart: Color(0xFFFFFFFF),
        widgetEnd: Color(0xFFE7F3FF),
        widgetText: Color(0xFF050505),
        widgetSubtext: Color(0xFF65676B),
        radius: 16,
        geometry: AppThemeGeometry.rounded,
        dark: false,
      ),
      AppThemeId.shopee: AppThemePalette(
        id: AppThemeId.shopee,
        pageStart: Color(0xFFFFF5F1),
        pageEnd: Color(0xFFF7F7F7),
        surface: Color(0xFFF6F6F6),
        card: Color(0xFFFFFFFF),
        cardAlt: Color(0xFFFFE9E1),
        primary: Color(0xFFEE4D2D),
        accent: Color(0xFFFF8B5E),
        textPrimary: Color(0xFF222222),
        textSecondary: Color(0xFF777777),
        border: Color(0xFFEAEAEA),
        shadow: Color(0x16000000),
        widgetStart: Color(0xFFEE4D2D),
        widgetEnd: Color(0xFFFF6A3D),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFFFFE9E1),
        radius: 15,
        geometry: AppThemeGeometry.rounded,
        dark: false,
      ),
      AppThemeId.tiktok: AppThemePalette(
        id: AppThemeId.tiktok,
        pageStart: Color(0xFF000000),
        pageEnd: Color(0xFF111111),
        surface: Color(0xFF0A0A0A),
        card: Color(0xFF202020),
        cardAlt: Color(0xFF2A2A2A),
        primary: Color(0xFFFE2C55),
        accent: Color(0xFF25F4EE),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFB8B8B8),
        border: Color(0xFF343434),
        shadow: Color(0x77000000),
        widgetStart: Color(0xFF111111),
        widgetEnd: Color(0xFF2A1520),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFF25F4EE),
        radius: 14,
        geometry: AppThemeGeometry.rounded,
        dark: true,
      ),
      AppThemeId.ben10: AppThemePalette(
        id: AppThemeId.ben10,
        pageStart: Color(0xFF050805),
        pageEnd: Color(0xFF142016),
        surface: Color(0xFF101510),
        card: Color(0xFF182018),
        cardAlt: Color(0xFF243126),
        primary: Color(0xFF39D353),
        accent: Color(0xFF7CFF00),
        textPrimary: Color(0xFFF5FFF5),
        textSecondary: Color(0xFFA8B8A9),
        border: Color(0xFF315637),
        shadow: Color(0x77000000),
        widgetStart: Color(0xFF101510),
        widgetEnd: Color(0xFF1D5F22),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFF7CFF00),
        radius: 18,
        geometry: AppThemeGeometry.rounded,
        dark: true,
      ),
      AppThemeId.youtube: AppThemePalette(
        id: AppThemeId.youtube,
        pageStart: Color(0xFF0F0F0F),
        pageEnd: Color(0xFF151515),
        surface: Color(0xFF0F0F0F),
        card: Color(0xFF212121),
        cardAlt: Color(0xFF272727),
        primary: Color(0xFFFF0033),
        accent: Color(0xFFFFFFFF),
        textPrimary: Color(0xFFF1F1F1),
        textSecondary: Color(0xFFAAAAAA),
        border: Color(0xFF303030),
        shadow: Color(0x77000000),
        widgetStart: Color(0xFF181818),
        widgetEnd: Color(0xFF2B0E14),
        widgetText: Color(0xFFFFFFFF),
        widgetSubtext: Color(0xFFFF8A9F),
        radius: 14,
        geometry: AppThemeGeometry.rounded,
        dark: true,
      ),
      AppThemeId.steam: AppThemePalette(
        id: AppThemeId.steam,
        pageStart: Color(0xFF0E141B),
        pageEnd: Color(0xFF162536),
        surface: Color(0xFF171D25),
        card: Color(0xFF1B2838),
        cardAlt: Color(0xFF22384A),
        primary: Color(0xFF66C0F4),
        accent: Color(0xFF1A9FFF),
        textPrimary: Color(0xFFD6E9F8),
        textSecondary: Color(0xFF8F98A0),
        border: Color(0xFF2A475E),
        shadow: Color(0x66000000),
        widgetStart: Color(0xFF171D25),
        widgetEnd: Color(0xFF1B3D55),
        widgetText: Color(0xFFD6E9F8),
        widgetSubtext: Color(0xFF66C0F4),
        radius: 4,
        geometry: AppThemeGeometry.square,
        dark: true,
      ),
    };

AppThemePalette get appThemePalette =>
    appThemePalettes[AppThemeController.instance.theme] ??
    appThemePalettes[AppThemeId.classic]!;

class AppThemeController extends ChangeNotifier {
  new _();

  static final AppThemeController instance = AppThemeController._();
  static const _preferenceKey = 'better_phenikaa_theme_v2';
  static const _widgetPreferenceKey = 'appTheme';
  static const MethodChannel _widgetThemeChannel = MethodChannel(
    'better_phenikaa/widget_theme',
  );

  AppThemeId _theme = AppThemeId.classic;
  bool _loaded = false;

  AppThemeId get theme => _theme;
  AppThemePalette get palette => appThemePalettes[_theme]!;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_preferenceKey);
    if (saved != null) {
      for (final candidate in AppThemeId.values) {
        if (candidate.storageKey == saved) {
          _theme = candidate;
          break;
        }
      }
    }
    if (!prefs.containsKey(_widgetPreferenceKey)) {
      await prefs.setString(_widgetPreferenceKey, _theme.storageKey);
    }
    notifyListeners();
    final widgetTheme = prefs.getString(_widgetPreferenceKey);
    if (widgetTheme != _theme.storageKey) {
      final nativeApplied = await _applyWidgetThemeImmediately(
        _theme.storageKey,
      );
      if (!nativeApplied) {
        await prefs.setString(_widgetPreferenceKey, _theme.storageKey);
        await _syncWidgetTheme();
      }
    }
  }

  Future<void> select(AppThemeId value) async {
    if (_theme == value) return;
    _theme = value;
    notifyListeners();

    // Dispatch the native widget update at the exact theme tap. The widget's
    // theme-only path is a partial RemoteViews update and never rebinds StackView.
    final nativeUpdate = _applyWidgetThemeImmediately(value.storageKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, value.storageKey);
    final nativeApplied = await nativeUpdate;
    if (!nativeApplied) {
      await prefs.setString(_widgetPreferenceKey, value.storageKey);
      await _syncWidgetTheme();
    }
  }

  Future<bool> _applyWidgetThemeImmediately(String themeKey) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _widgetThemeChannel.invokeMethod<int>(
        'applyTheme',
        <String, Object>{'theme': themeKey},
      );
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _syncWidgetTheme() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      androidName: 'ScheduleWidgetProvider',
    );
  }
}

ThemeData buildBetterTheme(AppThemePalette palette) {
  final brightness = palette.dark ? Brightness.dark : Brightness.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: palette.fontFamily ?? 'Roboto',
  );
  final shape = themeButtonShape(palette);
  return base.copyWith(
    scaffoldBackgroundColor: palette.surface,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: palette.primary,
          secondary: palette.accent,
          surface: palette.surface,
          onSurface: palette.textPrimary,
        ),
    textTheme: base.textTheme.apply(
      fontFamily: palette.fontFamily ?? 'Roboto',
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    iconTheme: IconThemeData(color: palette.textPrimary),
    cardTheme: CardThemeData(
      color: palette.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(palette.radius),
        side: BorderSide(color: palette.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.dark && palette.id != AppThemeId.lol
            ? Colors.white
            : palette.id == AppThemeId.lol
            ? const Color(0xFF06171D)
            : Colors.white,
        shape: shape,
        textStyle: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: themeLetterSpacing(palette),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        side: BorderSide(color: palette.border),
        shape: shape,
      ),
    ),
    dividerColor: palette.border,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      modalBackgroundColor: palette.surface,
    ),
  );
}

OutlinedBorder themeButtonShape(AppThemePalette palette) {
  return switch (palette.geometry) {
    AppThemeGeometry.valorant => const BeveledRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
    ),
    AppThemeGeometry.lol => const BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    AppThemeGeometry.pixel ||
    AppThemeGeometry.square => const RoundedRectangleBorder(),
    AppThemeGeometry.rounded => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(palette.radius),
    ),
  };
}

double themeLetterSpacing(AppThemePalette palette) => switch (palette.id) {
  AppThemeId.valorant => .85,
  AppThemeId.lol => .65,
  AppThemeId.minecraft => .15,
  _ => 0,
};

String themedHeading(String value, AppThemePalette palette) =>
    palette.id == AppThemeId.valorant ? value.toUpperCase() : value;

class AppThemeBackdrop extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ThemeBackdropPainter(appThemePalette),
      child: SizedBox.expand(child: child),
    );
  }
}

class _ThemeBackdropPainter extends CustomPainter {
  const new(this.palette);

  final AppThemePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[palette.pageStart, palette.pageEnd],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    switch (palette.id) {
      case AppThemeId.minecraft:
        final block = (size.shortestSide / 11).clamp(26.0, 48.0);
        final paint = Paint();
        for (var y = 0.0; y < size.height; y += block) {
          for (var x = 0.0; x < size.width; x += block) {
            final index = ((x / block).floor() + (y / block).floor()) % 4;
            paint.color = <Color>[
              const Color(0xFF5A3824),
              const Color(0xFF6A4229),
              const Color(0xFF4C2D1C),
              const Color(0xFF765037),
            ][index];
            canvas.drawRect(Rect.fromLTWH(x, y, block + .5, block + .5), paint);
          }
        }
        paint.color = const Color(0xFF5D963E).withValues(alpha: .55);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, block * .28), paint);
      case AppThemeId.valorant:
        final paint = Paint()..color = palette.primary.withValues(alpha: .13);
        final path = Path()
          ..moveTo(size.width * .62, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height * .31)
          ..close();
        canvas.drawPath(path, paint);
        final path2 = Path()
          ..moveTo(0, size.height * .78)
          ..lineTo(size.width * .26, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path2, paint);
      case AppThemeId.lol:
        final glow = Paint()
          ..shader =
              RadialGradient(
                colors: <Color>[
                  palette.primary.withValues(alpha: .18),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(size.width * .5, size.height * .08),
                  radius: size.width * .55,
                ),
              );
        canvas.drawRect(rect, glow);
        final line = Paint()
          ..color = palette.accent.withValues(alpha: .16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(
          Offset(size.width * .5, size.height * .12),
          size.width * .31,
          line,
        );
      case AppThemeId.tiktok:
        final pink = Paint()..color = palette.primary.withValues(alpha: .08);
        final cyan = Paint()..color = palette.accent.withValues(alpha: .07);
        canvas.drawCircle(
          Offset(size.width * .9, size.height * .18),
          size.width * .36,
          pink,
        );
        canvas.drawCircle(
          Offset(size.width * .05, size.height * .76),
          size.width * .3,
          cyan,
        );
      case AppThemeId.ben10:
        final ring = Paint()
          ..color = palette.accent.withValues(alpha: .10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10;
        canvas.drawCircle(
          Offset(size.width * .86, size.height * .12),
          size.width * .22,
          ring,
        );
      case AppThemeId.youtube:
        final glow = Paint()..color = palette.primary.withValues(alpha: .07);
        canvas.drawCircle(Offset(size.width * .52, 0), size.width * .55, glow);
      case AppThemeId.steam:
        final glow = Paint()
          ..shader = LinearGradient(
            colors: <Color>[
              Colors.transparent,
              palette.primary.withValues(alpha: .11),
            ],
          ).createShader(rect);
        canvas.drawRect(rect, glow);
      case AppThemeId.shopee:
        final band = Paint()..color = palette.primary.withValues(alpha: .10);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height * .14),
          band,
        );
      case AppThemeId.facebook:
      case AppThemeId.classic:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeBackdropPainter oldDelegate) =>
      oldDelegate.palette.id != palette.id;
}

class AppThemePanel extends StatelessWidget {
  const new({
    required this.child,
    this.padding,
    this.width,
    this.constraints,
    this.alt = false,
    this.elevated = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final BoxConstraints? constraints;
  final bool alt;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final decoration = BoxDecoration(
      color: alt ? palette.cardAlt : palette.card,
      border: Border.all(
        color: palette.border,
        width: palette.geometry == AppThemeGeometry.pixel ? 3 : 1,
      ),
      borderRadius: palette.geometry == AppThemeGeometry.rounded
          ? BorderRadius.circular(palette.radius)
          : BorderRadius.zero,
      boxShadow: elevated
          ? <BoxShadow>[
              BoxShadow(
                color: palette.shadow,
                blurRadius: palette.geometry == AppThemeGeometry.pixel ? 0 : 18,
                offset: palette.geometry == AppThemeGeometry.pixel
                    ? const Offset(4, 4)
                    : const Offset(0, 6),
              ),
            ]
          : null,
    );
    final box = Container(
      width: width,
      constraints: constraints,
      padding: padding,
      decoration: decoration,
      child: child,
    );
    return switch (palette.geometry) {
      AppThemeGeometry.valorant => ClipPath(
        clipper: const _ValorantClipper(),
        child: box,
      ),
      AppThemeGeometry.lol => ClipPath(
        clipper: const _LolClipper(),
        child: box,
      ),
      _ => box,
    };
  }
}

class _ValorantClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) {
    const cut = 12.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LolClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) {
    const cut = 11.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Future<void> showAppThemePicker(BuildContext context) async {
  final controller = AppThemeController.instance;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99000000),
    builder: (context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final palette = controller.palette;
        final radius = palette.geometry == AppThemeGeometry.rounded
            ? 28.0
            : 0.0;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .78,
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(top: BorderSide(color: palette.border)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: palette.textSecondary.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'Giao diện',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: themeLetterSpacing(palette),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đổi skin cho toàn bộ app và widget. Lịch và dữ liệu không thay đổi.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.45,
                        ),
                    itemCount: AppThemeId.values.length,
                    itemBuilder: (context, index) {
                      final id = AppThemeId.values[index];
                      final preview = appThemePalettes[id]!;
                      final selected = controller.theme == id;
                      return InkWell(
                        onTap: () => controller.select(id),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(
                              palette.geometry == AppThemeGeometry.rounded
                                  ? 14
                                  : 2,
                            ),
                            border: Border.all(
                              color: selected
                                  ? palette.primary
                                  : palette.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: <Color>[
                                        preview.pageStart,
                                        preview.primary,
                                        preview.accent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      preview.geometry ==
                                              AppThemeGeometry.rounded
                                          ? 9
                                          : 1,
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: const EdgeInsets.all(7),
                                      child: Icon(
                                        selected
                                            ? Icons.check_circle_rounded
                                            : id.icon,
                                        color: preview.widgetText,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                id.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                id.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class AppThemeSettingButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final palette = controller.palette;
        return AppThemePanel(
          elevated: false,
          alt: true,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: InkWell(
            onTap: () => showAppThemePicker(context),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[palette.primary, palette.accent],
                    ),
                    borderRadius: BorderRadius.circular(
                      palette.geometry == AppThemeGeometry.rounded ? 10 : 1,
                    ),
                  ),
                  child: Icon(
                    controller.theme.icon,
                    color: palette.widgetText,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Giao diện',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.theme.label,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}
