import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'inplace_refresh_stub.dart'
    if (dart.library.io) 'inplace_refresh_io.dart' as platform;

/// Fetch and verify QLDT data without opening a new route or WebView.
Future<QldtLoginResult> reloadQldtInPlace(ImportedScheduleData current) =>
    platform.reloadQldtInPlace(current);
