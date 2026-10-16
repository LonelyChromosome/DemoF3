import 'dart:async';

import 'water_engine.dart';

import 'package:flutter/material.dart';

class WaterRouteObserver extends NavigatorObserver {
  WaterRouteObserver._();
  static final instance = WaterRouteObserver._();
  static final visible = ValueNotifier(true);
  final _routes = <Route<dynamic>>[];
  void _update() {
    final show = _routes.whereType<PageRoute<dynamic>>().lastOrNull;
    final run =
        show == null ||
        show.isFirst ||
        !show.opaque ||
        show.settings.name == '/theme/water-cooling';
    scheduleMicrotask(() => visible.value = run);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
    WaterEngine.feedback(WaterEvent.illumination);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = _routes.indexOf(oldRoute!);
    if (i >= 0) {
      if (newRoute == null) {
        _routes.removeAt(i);
      } else {
        _routes[i] = newRoute;
      }
    }
    _update();
  }
}
