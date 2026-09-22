import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_login_web.dart'
    if (dart.library.io) 'qldt_login_mobile.dart'
    as implementation;
import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_models.dart';
import 'package:flutter/widgets.dart';

bool get supportsLiveQldtLogin => implementation.supportsLiveQldtLogin;

Future<ImportedScheduleData?> openQldtLogin(BuildContext context) {
  return implementation.openQldtLogin(context);
}

Future<void> clearQldtSession() => implementation.clearQldtSession();
