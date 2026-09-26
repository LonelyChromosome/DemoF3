# ThemeVaccine

This directory contains only widget host size and render geometry adaptation.
The reference widget XML, themes, actions, schedule data, sync, and notifications
remain the baseline.

## Geometry

- `WidgetHostSizeResolver` reads each widget instance's options. Android 12+
  exact sizes remain the source for the small widget's size-specific layouts.
  When only legacy ranges are available, portrait uses the narrow/tall pair and
  landscape uses the wide/short pair. Transient bitmaps use the closest exact
  size for the current orientation.
- `WidgetGeometry` preserves the 4×2 reference dimensions through 156dp.
  A taller host fills its panel while keeping the card, track and dot geometry
  together; the additional space is distributed around that group.

## Compatibility, tracked separately

The existing refresh cover, collection token, pending selection, theme
transition generation, and per-widget state in `ScheduleWidgetProvider` remain
unchanged. Ghost layers, stale children and rebind races require separate
launcher observations and tests. Geometry passing does not establish that
those compatibility cases pass.

Android 11 and older cannot set the 4×2 panel height through the Android 12
`RemoteViews` size API. Only taller hosts use the separate
`overview_widget_tall.xml` layout; the reference XML remains untouched.
Its output still needs a launcher screenshot and interaction check before it
can be marked as passing visual parity.
