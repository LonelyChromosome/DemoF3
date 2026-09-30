# Tiên Môn Premium — START HERE

This branch is a prepared workspace for the Tiên Môn Premium visual subsystem.

## Authority
The user's supplied assets and the final rules in `docs/TIEN_MON_PREMIUM_REFERENCE.md` are authoritative. Do not redesign, reinterpret, simplify, replace, recolor, crop, stretch, or substitute the concept with older Tiên Môn work already present in the repository.

## Branch / baseline
- Branch: `tienmon_preinumtheme`
- Created from `feature/big-update`
- Baseline commit: `4caead29e5cfd399241431d8e781d3f6ab0a144f`
- Do not merge `main` into this work.

## Read only these first
1. `docs/TIEN_MON_PREMIUM_REFERENCE.md`
2. `assets/tien_mon_premium/scene_manifest.json`
3. `lib/features/giao_dien/tien_mon_premium/tien_mon_premium_contract.dart`
4. `tools/tien_mon_premium/import_assets.py`

Do not begin by scanning all old Tiên Môn branches/assets. Historical Tiên Môn code may be consulted only for a specific implementation question. It is not an asset source of truth.

## Three authoritative user inputs
The asset importer accepts the three user-supplied files and validates them by SHA-256:
- 8 app wallpapers ZIP — SHA-256 `6986484b506492ed740b17e43d45be5c44cdd78ed9d88fb9597972b76a101586`
- `FzCoTrang.ttf` — SHA-256 `1a7b3066c5bb45bf7d3073280a8f27d77dc5b050a4dd564390468dd9071aaeea`
- 4x2 widget backgrounds ZIP — SHA-256 `d60270f36a268237ee9722c9a006e58d46eba8bc76815eb457457522d5f8e91c`

Run:

```bash
python tools/tien_mon_premium/import_assets.py \
  --wallpapers <path-to-wallpapers.zip> \
  --font <path-to-FzCoTrang.ttf> \
  --widget <path-to-widget4x2Background.zip>
```

The importer validates dimensions/hashes, writes the canonical runtime paths, and registers the asset directories/font in `pubspec.yaml`.

## Work scope
Build the Tiên Môn Premium subsystem and its standalone demo/harness. Keep production business/data logic untouched.

Preferred implementation area:
- `lib/features/giao_dien/tien_mon_premium/`
- `lib/tien_mon_premium_demo.dart`
- Premium-specific tests/harnesses
- Premium-specific Android widget renderer helpers when needed

Do not spend Work compute on QLĐT login, semester sync, database integration, production notification scheduling, or merging Premium into the normal Theme Engine. Those are later integration tasks.

## Production files to consult only when needed
- `lib/features/lich_hoc/week_timetable.dart`
- `lib/features/giao_dien/bo_may/theme_tokens.dart`
- `lib/features/giao_dien/bo_may/theme_generator.dart`
- `lib/features/giao_dien/xem_truoc/theme_picker.dart`
- `lib/features/tien_ich_lich_hoc/widget_publisher.dart`
- `android/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/OverviewWidgetProvider.kt`
- `android/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetProvider.kt`
- `android/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetService.kt`
- `android/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/WidgetVisualPalette.kt`

## Architectural boundary
`DemoF3 data/actions -> Tiên Môn adapter -> TienMonPremiumEngine -> App renderer / Widget renderer`

Tiên Môn Premium is not a normal `AppThemeId` preset constrained by the existing Theme Engine. The small widget may reuse the existing widget engine's stable redraw strategy, but Premium visual ownership remains separate.
