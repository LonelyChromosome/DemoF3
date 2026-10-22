import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VehicleNative {
  static const channel = MethodChannel('better_phenikaa/vehicle');
  static Future<Map<String, dynamic>> state() async {
    if (kIsWeb) return <String, dynamic>{'enabled': false};
    final value = await channel.invokeMethod<dynamic>('state');
    return Map<String, dynamic>.from(value as Map);
  }
  static Future<void> enable() async { await channel.invokeMethod<dynamic>('enable'); }
  static Future<void> permissionSettings() async { await channel.invokeMethod<dynamic>('permissionSettings'); }
  static Future<void> requestNotificationAccess() async {
    await channel.invokeMethod<dynamic>('requestNotificationAccess');
  }
  static Future<void> permissions() async { await channel.invokeMethod<dynamic>('permissions'); }
  static Future<void> schedule(List<Map<String, dynamic>> windows) async {
    await channel.invokeMethod<dynamic>('schedule', <String, Object>{'windows': windows});
  }
  static Future<void> manualReset() async {
    await channel.invokeMethod<dynamic>('manualReset');
  }
  static Future<void> startNav() async { await channel.invokeMethod<dynamic>('startNav'); }
  static Future<void> stopNav() async { await channel.invokeMethod<dynamic>('stopNav'); }
  static Future<Map<String, dynamic>> nav() async {
    final value = await channel.invokeMethod<dynamic>('nav');
    return Map<String, dynamic>.from(value as Map);
  }
}
