import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_mobile.dart'
    as mobile;
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'missing callback ends loading and retry uses loaded registration',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final response = jsonEncode(<String, Object>{
        'Success': true,
        'Data': <Map<String, Object>>[
          <String, Object>{
            'PHANLOAI': 'LICHHOC',
            'TENHOCPHAN': 'Thiết kế web nâng cao',
            'TENLOPHOCPHAN': 'WEB-2026-LT',
            'NGAYHOC': '23/09/2026',
            'GIOBATDAU': 7,
            'PHUTBATDAU': 0,
            'GIOKETTHUC': 9,
            'PHUTKETTHUC': 0,
            'PHONGHOC_TEN': 'A1',
          },
        ],
      });
      final html =
          '''
      <!doctype html><html><body>
      <select id="dropSearch_HocKy">
        <option value="old">2025_2026_3</option>
        <option value="new" selected>2026_2027_1</option>
      </select>
      <select id="dropSearch_KeHoach">
        <option value="new-plan" selected>2026_2027_1,1 Đăng ký HK1</option>
      </select>
      <a id="btnXemKetQuaDangKy">Xem</a>
      <div id="zoneKetQuaDangKy"><div id="zonemasonrybq">
        <div class="subject-item"><h4>Môn Thiết kế web nâng cao</h4>
          <div class="classroom-section-item">
            <a class="btnChiTietLopHocPhan">WEB-2026-LT</a>
            <div class="classroom-day">17/08/2026 - 01/11/2026</div>
          </div>
        </div>
      </div></div>
      <script>
        let calls = 0;
        window.edu = {system: {userId: 'fixture', iM: 1,
          makeRequest: function (options) {
            calls++;
            if (calls > 1) options.success($response);
          }
        }};
      </script>
      </body></html>
    ''';
      QldtLoginResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await mobile.openQldtLogin(context, testHtml: html);
                },
                child: const Text('Mở QLĐT giả lập'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở QLĐT giả lập'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 23)),
      );
      await tester.pump();
      expect(find.textContaining('schedule không phản hồi'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Thử đồng bộ lại'), findsOneWidget);
      expect(result, isNull);

      await tester.tap(find.text('Thử đồng bộ lại'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 8)),
      );
      await tester.pump();
      final labels = find
          .byType(Text)
          .evaluate()
          .map((element) => (element.widget as Text).data)
          .join(' | ');
      expect(
        result?.semester?.subjects.single.name,
        'Thiết kế web nâng cao',
        reason: labels,
      );
    },
  );
}
