import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const bool supportsLiveQldtLogin = true;

Future<void> clearQldtSession() async {
  await CookieManager.instance().deleteAllCookies();
}

Future<ImportedScheduleData?> openQldtLogin(BuildContext context) {
  return Navigator.of(context).push<ImportedScheduleData>(
    MaterialPageRoute<ImportedScheduleData>(
      fullscreenDialog: true,
      builder: (_) => const _QldtWebLoginScreen(),
    ),
  );
}

class _QldtWebLoginScreen extends StatefulWidget {
  const new();

  @override
  State<_QldtWebLoginScreen> createState() => _QldtWebLoginScreenState();
}

class _QldtWebLoginScreenState extends State<_QldtWebLoginScreen> {
  static final WebUri _qldtUri = WebUri(
    'https://qldtbeta.phenikaa-uni.edu.vn/',
  );

  InAppWebViewController? _controller;
  bool _pageReady = false;
  bool _syncing = false;
  bool _autoSyncStarted = false;
  String _status = 'Đăng nhập bằng tài khoản Microsoft của bạn.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập QLĐT'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Material(
            color: const Color(0xFFF2F6FF),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    _pageReady
                        ? Icons.verified_user_outlined
                        : Icons.info_outline,
                    color: const Color(0xFF1747B5),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_syncing) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: _qldtUri),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: false,
              ),
              onWebViewCreated: _onWebViewCreated,
              onLoadStop: (_, _) => _checkReady(),
            ),
          ),
          if (_pageReady && !_syncing && _autoSyncStarted)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _sync,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử đồng bộ lại'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaSyncResult',
      callback: (arguments) async {
        if (!mounted || arguments.isEmpty) {
          return null;
        }
        try {
          final raw = arguments.first?.toString() ?? '';
          final data = const QldtParser().parseLiveEnvelope(raw);
          if (!mounted) {
            return null;
          }
          Navigator.of(context).pop(data);
        } on Object catch (error) {
          if (mounted) {
            setState(() {
              _syncing = false;
              _status = 'Không đọc được dữ liệu QLĐT: $error';
            });
          }
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaSyncError',
      callback: (arguments) {
        if (mounted) {
          setState(() {
            _syncing = false;
            _status = arguments.isEmpty
                ? 'QLĐT không trả dữ liệu.'
                : arguments.first.toString();
          });
        }
        return null;
      },
    );
  }

  Future<void> _checkReady() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      final result = await controller.evaluateJavascript(
        source: '''
          Boolean(
            window.edu && edu.system && edu.system.userId &&
            edu.system.iM != null && typeof edu.system.makeRequest === 'function'
          );
        ''',
      );
      final ready = result == true || result?.toString() == 'true';
      if (!mounted) {
        return;
      }

      setState(() {
        _pageReady = ready;
        _status = ready
            ? 'Đã nhận phiên QLĐT. App đang tự lấy lịch và sẽ quay lại ngay khi hoàn tất.'
            : 'Hoàn tất đăng nhập Microsoft; app sẽ tự đồng bộ khi QLĐT sẵn sàng.';
      });

      if (ready && !_autoSyncStarted && !_syncing) {
        _autoSyncStarted = true;
        await _sync();
      }
    } on Object {
      if (mounted) {
        setState(() => _pageReady = false);
      }
    }
  }

  Future<void> _sync() async {
    final controller = _controller;
    if (controller == null || _syncing) {
      return;
    }
    setState(() {
      _syncing = true;
      _status = 'Đang lấy lịch cá nhân từ QLĐT...';
    });

    final now = DateTime.now();
    final academicStartYear = now.month >= 8 ? now.year : now.year - 1;
    final start = DateTime(academicStartYear, 8);
    final end = DateTime(academicStartYear + 1, 7, 31);
    final startText = _formatDate(start);
    final endText = _formatDate(end);

    final script =
        '''
      (function () {
        try {
          if (!(window.edu && edu.system && edu.system.userId &&
                edu.system.iM != null && typeof edu.system.makeRequest === 'function')) {
            window.flutter_inappwebview.callHandler(
              'betterPhenikaaSyncError',
              'Phiên QLĐT chưa sẵn sàng.'
            );
            return;
          }

          var requestData = {
            action: 'SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv',
            func: 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan',
            iM: edu.system.iM,
            strQLSV_NguoiHoc_Id: edu.system.userId,
            strNgayBatDau: '$startText',
            strNgayKetThuc: '$endText'
          };

          edu.system.makeRequest({
            success: function (response) {
              var nameNode = document.querySelector('#lblHoTenNguoiDangNhap');
              var name = nameNode ? (nameNode.textContent || '').trim() : '';
              if (!name) {
                var spans = document.querySelectorAll('.nav-account button > span');
                for (var i = 0; i < spans.length; i++) {
                  var candidate = (spans[i].textContent || '').trim();
                  if (candidate) {
                    name = candidate;
                    break;
                  }
                }
              }
              window.flutter_inappwebview.callHandler(
                'betterPhenikaaSyncResult',
                JSON.stringify({name: name, response: response})
              );
            },
            error: function () {
              window.flutter_inappwebview.callHandler(
                'betterPhenikaaSyncError',
                'QLĐT báo lỗi khi tải lịch cá nhân.'
              );
            },
            type: 'POST',
            action: requestData.action,
            contentType: true,
            data: requestData,
            fakedb: []
          }, false, false, false, null);
        } catch (error) {
          window.flutter_inappwebview.callHandler(
            'betterPhenikaaSyncError',
            'Lỗi JavaScript: ' + error
          );
        }
      })();
    ''';

    try {
      await controller.evaluateJavascript(source: script);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _syncing = false;
          _status = 'Không thể yêu cầu QLĐT: $error';
        });
      }
    }
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }
}
