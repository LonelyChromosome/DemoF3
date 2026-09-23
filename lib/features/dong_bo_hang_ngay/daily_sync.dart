import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class DailySync {
  static const MethodChannel _channel = MethodChannel(
    'better_phenikaa/daily_sync',
  );

  static Future<void> enable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('enable');
    } on Object catch (error) {
      debugPrint('Unable to schedule the 06:00 sync: $error');
    }
  }

  static Future<void> disable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('disable');
    } on Object catch (error) {
      debugPrint('Unable to cancel the 06:00 sync: $error');
    }
  }

  static Future<void> refreshWidgetToday() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('refreshWidgetToday');
    } on Object catch (error) {
      debugPrint('Unable to refresh today on the widget: $error');
    }
  }

  static Future<void> syncReminders() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('syncReminders');
  }

  static Future<void> recordAppSyncSuccess() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('recordAppSyncSuccess');
  }

  static Future<void> clearReminders() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('clearReminders');
  }
}
