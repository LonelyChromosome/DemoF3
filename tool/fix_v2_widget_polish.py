from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"missing marker: {label}")
    return text.replace(old, new, 1)


# 1) Account theme tile must rebuild immediately when the active theme changes.
theme_path = Path("lib/theme/app_theme.dart")
t = theme_path.read_text(encoding="utf-8")
start = t.index("class AppThemeSettingButton extends StatelessWidget")
new_tail = r'''class AppThemeSettingButton extends StatelessWidget {
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
'''
t = t[:start] + new_tail

# 3) Persist both Flutter preference keys concurrently and avoid a redundant
# HomeWidget preference write. The native widget reads FlutterSharedPreferences,
# so the direct update broadcast is all that is needed after the two writes finish.
old_select = '''  Future<void> select(AppThemeId value) async {
    if (_theme == value) return;
    _theme = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, value.storageKey);
    await prefs.setString(_widgetPreferenceKey, value.storageKey);
    await _syncWidgetTheme();
  }

  Future<void> _syncWidgetTheme() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await HomeWidget.saveWidgetData<String>('appTheme', _theme.storageKey);
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      androidName: 'ScheduleWidgetProvider',
    );
  }
'''
new_select = '''  Future<void> select(AppThemeId value) async {
    if (_theme == value) return;
    _theme = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait<bool>(<Future<bool>>[
      prefs.setString(_preferenceKey, value.storageKey),
      prefs.setString(_widgetPreferenceKey, value.storageKey),
    ]);
    await _syncWidgetTheme();
  }

  Future<void> _syncWidgetTheme() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      androidName: 'ScheduleWidgetProvider',
    );
  }
'''
if old_select in t:
    t = t.replace(old_select, new_select, 1)
elif "Future.wait<bool>" not in t:
    raise RuntimeError("missing marker: theme selection sync")
theme_path.write_text(t, encoding="utf-8")

# 2 + 3) Keep the RemoteViews adapter identity stable across theme changes.
# Rebinding the whole StackView made Samsung Launcher briefly show a transformed
# loading card. notifyAppWidgetViewDataChanged already refreshes every bitmap.
provider_path = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetProvider.kt"
)
p = provider_path.read_text(encoding="utf-8")
old_uri = '            data = Uri.parse("better-phenikaa://widget/$widgetId/$sizeToken/${theme.key}")\n'
new_uri = '            data = Uri.parse("better-phenikaa://widget/$widgetId/$sizeToken")\n'
if old_uri in p:
    p = p.replace(old_uri, new_uri, 1)
elif new_uri not in p:
    raise RuntimeError("missing marker: stable widget adapter uri")
provider_path.write_text(p, encoding="utf-8")

# Remove the last classic-blue native background from each StackView item.
# The rendered bitmap already supplies the complete themed surface; leaving the
# old drawable underneath exposed a 1px/edge strip during StackView transforms.
item_path = Path("platform/android_widget/app/src/main/res/layout/schedule_widget_item.xml")
x = item_path.read_text(encoding="utf-8")
old_bg = '    android:background="@drawable/schedule_widget_background"\n'
new_bg = '    android:background="@android:color/transparent"\n'
if old_bg in x:
    x = x.replace(old_bg, new_bg, 1)
elif new_bg not in x:
    raise RuntimeError("missing marker: item background")
if '    android:outlineProvider="background">\n' in x:
    x = x.replace(
        '    android:outlineProvider="background">\n',
        '    android:outlineProvider="none">\n',
        1,
    )
elif '    android:outlineProvider="none">\n' not in x:
    raise RuntimeError("missing marker: item outline")
item_path.write_text(x, encoding="utf-8")

# Release bump.
pubspec_path = Path("pubspec.yaml")
s = pubspec_path.read_text(encoding="utf-8")
if re.search(r"^version:\s*2\.0\.2\+7\s*$", s, flags=re.M):
    s = re.sub(r"^version:\s*2\.0\.2\+7\s*$", "version: 2.0.3+8", s, count=1, flags=re.M)
elif not re.search(r"^version:\s*2\.0\.3\+8\s*$", s, flags=re.M):
    raise RuntimeError("version marker missing")
pubspec_path.write_text(s, encoding="utf-8")
