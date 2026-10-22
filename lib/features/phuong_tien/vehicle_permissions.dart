import 'dart:async';
import 'package:flutter/material.dart';
import 'vehicle_native.dart';

bool vehiclePermissionsReady(Map<String, dynamic> state) =>
    ['location', 'motion', 'notifications', 'background', 'notificationAccess']
        .every((key) => state[key] == true);

Future<void> showVehiclePermissions(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const VehiclePermissionSetup(),
    );

class VehiclePermissionSetup extends StatefulWidget {
  const VehiclePermissionSetup({super.key});
  @override
  State<VehiclePermissionSetup> createState() => _VehiclePermissionSetupState();
}

class _VehiclePermissionSetupState extends State<VehiclePermissionSetup>
    with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
  }
  Future<void> refresh() async {
    try {
      final value = await VehicleNative.state();
      if (mounted) setState(() => data = value);
    } catch (_) {
      if (mounted) setState(() => error = 'Chưa đọc được quyền. Hãy thử lại.');
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }
  bool get runtimeReady => ['location', 'motion', 'notifications']
      .every((key) => data?[key] == true);
  bool get blocked => (data?['blockedPermissions'] as List?)?.isNotEmpty == true;
  Future<void> next() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final state = await VehicleNative.state();
      if (!mounted) return;
      data = state;
      if (state['enabled'] != true) {
        // This explicit action opts in, even with an empty timetable.
        await VehicleNative.enable();
      } else if (!runtimeReady) {
        if (blocked) {
          await VehicleNative.permissionSettings();
        } else {
          await VehicleNative.permissions();
        }
      } else if (state['background'] != true) {
        await VehicleNative.backgroundPermission();
      } else if (state['notificationAccess'] != true) {
        await VehicleNative.requestNotificationAccess();
      } else {
        Navigator.of(context).pop();
      }
      await refresh();
    } catch (_) {
      if (mounted) setState(() => error = 'Chưa mở được yêu cầu quyền. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final state = data;
    final ready = state != null && vehiclePermissionsReady(state);
    final enabled = state?['enabled'] == true;
    final label = !enabled ? 'Bật Find Bike và cấp quyền'
        : !runtimeReady ? (blocked ? 'Mở cài đặt quyền' : 'Cấp quyền còn thiếu')
        : state?['background'] != true ? 'Cho phép vị trí nền'
        : state?['notificationAccess'] != true ? 'Cho phép đọc thông báo'
        : 'Hoàn tất';
    Widget row(String key, IconData icon, String title, String detail) {
      final granted = state?[key] == true;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(granted ? 'Đã cấp' : detail),
        trailing: Icon(granted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: granted ? Colors.green : null),
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('findbike-permission-setup'),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Thiết lập Find Bike', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Cấp quyền để ghi vị trí đỗ xe theo lịch học và nhận biết khi ra cổng.'),
        row('location', Icons.gps_fixed, 'Vị trí chính xác', 'Tìm và lưu vị trí đỗ xe.'),
        row('motion', Icons.directions_walk, 'Hoạt động thể chất', 'Dùng bước chân để nhận biết đã dừng xe.'),
        row('notifications', Icons.notifications_outlined, 'Gửi thông báo', 'Báo trạng thái ghi hành trình và đỗ xe.'),
        row('background', Icons.location_on_outlined, 'Vị trí khi chạy nền',
            'Chọn Quyền → Vị trí → Luôn cho phép trên màn hình Android.'),
        row('notificationAccess', Icons.mark_email_read_outlined, 'Đọc thông báo Phenikaa Uni',
            'Bật quyền truy cập thông báo cho BPA để kết thúc lượt xe.'),
        if (enabled && runtimeReady && !ready) ...[
          const SizedBox(height: 8),
          const Text('Android yêu cầu xác nhận riêng hai quyền cuối. Quay lại đây sau khi cấp.'),
        ],
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('findbike-permission-next'),
          onPressed: busy || state == null ? null : next,
          child: Text(busy ? 'Đang xin quyền…' : label),
        ),
        TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(ready ? 'Đóng' : 'Để sau')),
      ]),
    );
  }
}
