import 'dart:async';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_verifier.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/tracuu_webview_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const bool supportsLiveQldtLogin = true;

Future<void> clearQldtSession() async {
  await CookieManager.instance().deleteAllCookies();
}

Future<QldtLoginResult?> openQldtLogin(BuildContext context) {
  return Navigator.of(context).push<QldtLoginResult>(
    MaterialPageRoute<QldtLoginResult>(
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
  Timer? _readinessTimer;
  Timer? _registrationTimer;
  ImportedScheduleData? _pendingSchedule;
  int _registrationAttempt = 0;
  bool _registrationRequested = false;
  bool _registrationProbeStarted = false;
  bool _pageReady = false;
  bool _syncing = false;
  bool _autoSyncStarted = false;
  bool _rendererGone = false;
  bool _webCanGoBack = false;
  bool _allowRoutePop = false;
  final bool _hybridComposition = true;
  int _webViewGeneration = 0;
  int _readinessAttempt = 0;
  String _status = 'Đăng nhập bằng tài khoản Microsoft của bạn.';

  @override
  void dispose() {
    _readinessTimer?.cancel();
    _registrationTimer?.cancel();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<QldtLoginResult>(
      canPop: _allowRoutePop || !_webCanGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: BackButton(onPressed: _handleBack),
          title: const Text('Đăng nhập QLĐT'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _reload,
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
              child: _rendererGone
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Khởi tạo lại trang đăng nhập'),
                      ),
                    )
                  : ColoredBox(
                      color: Colors.white,
                      child: InAppWebView(
                        key: ValueKey<int>(_webViewGeneration),
                        initialUrlRequest: URLRequest(url: _qldtUri),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          thirdPartyCookiesEnabled: true,
                          transparentBackground: false,
                          underPageBackgroundColor: Colors.white,
                          forceDark: ForceDark.OFF,
                          algorithmicDarkeningAllowed: false,
                          hardwareAcceleration: true,
                          useHybridComposition: _hybridComposition,
                          useOnRenderProcessGone: true,
                          useShouldOverrideUrlLoading: false,
                        ),
                        onWebViewCreated: _onWebViewCreated,
                        onLoadStart: (_, _) {
                          _readinessTimer?.cancel();
                          if (mounted) {
                            setState(() {
                              _pageReady = false;
                              _status = 'Đang tải trang đăng nhập QLĐT...';
                            });
                          }
                        },
                        onLoadStop: (_, _) {
                          if (_pendingSchedule == null) {
                            _beginReadinessChecks();
                          } else {
                            unawaited(_checkRegistrationPage());
                          }
                        },
                        onUpdateVisitedHistory: (_, _, _) => _updateBackState(),
                        onReceivedError: (_, request, error) {
                          if (request.isForMainFrame == true && mounted) {
                            setState(() {
                              _status =
                                  'Không tải được QLĐT: ${error.description}';
                            });
                          }
                        },
                        onReceivedHttpError: (_, request, response) {
                          if (request.isForMainFrame == true && mounted) {
                            setState(() {
                              _status =
                                  'QLĐT trả lỗi HTTP ${response.statusCode}.';
                            });
                          }
                        },
                        onRenderProcessGone: (_, detail) {
                          _readinessTimer?.cancel();
                          _controller = null;
                          if (mounted) {
                            setState(() {
                              _rendererGone = true;
                              _pageReady = false;
                              _syncing = false;
                              _status = detail.didCrash
                                  ? 'Tiến trình WebView đã bị lỗi.'
                                  : 'Tiến trình WebView đã bị hệ thống dừng.';
                            });
                          }
                        },
                      ),
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
      ),
    );
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      await _updateBackState();
      return;
    }
    if (!mounted) return;
    setState(() => _allowRoutePop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> _updateBackState() async {
    final canGoBack = await _controller?.canGoBack() ?? false;
    if (mounted && canGoBack != _webCanGoBack) {
      setState(() => _webCanGoBack = canGoBack);
    }
  }

  Future<void> _reload() async {
    _readinessTimer?.cancel();
    if (_rendererGone) {
      setState(() {
        _rendererGone = false;
        _webCanGoBack = false;
        _webViewGeneration += 1;
        _status = 'Đang khởi tạo lại trang đăng nhập...';
      });
      return;
    }
    await _controller?.reload();
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
          final data = const QldtParser().parseLiveEnvelope(raw, strict: true);
          if (!mounted) {
            return null;
          }
          _pendingSchedule = data;
          _registrationAttempt = 0;
          _registrationRequested = false;
          _registrationProbeStarted = false;
          setState(
            () => _status =
                'Đang xác minh học kỳ và môn đã đăng ký trên TraCuu...',
          );
          await _checkRegistrationPage();
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
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaRegistrationResult',
      callback: (arguments) {
        if (!mounted || _pendingSchedule == null || arguments.isEmpty) {
          return null;
        }
        try {
          final registration = const TracuuWebViewProbe().parseResult(
            arguments.first as String,
          );
          final schedule = _pendingSchedule!;
          final verified = const SemesterScheduleVerifier().verify(
            registration: registration,
            schedule: schedule,
          );
          final semester = const SemesterDataBuilder().build(
            registration: registration,
            studySchedules: verified.studySchedules,
            examSchedules: verified.examSchedules,
            displayName: schedule.displayName,
            syncedAt: schedule.syncedAt,
          );
          Navigator.of(context).pop(
            QldtLoginResult(
              schedule: semester.toImportedScheduleData(),
              semester: semester,
            ),
          );
        } on Object {
          setState(() {
            _syncing = false;
            _status = 'Không xác minh được học kỳ, kế hoạch hoặc lớp của lịch. Dữ liệu trước đó được giữ nguyên. Hãy thử lại.';
          });
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaRegistrationError',
      callback: (_) {
        if (mounted) {
          setState(() {
            _syncing = false;
            _status = 'TraCuu chưa trả dữ liệu đăng ký đầy đủ. Dữ liệu trước đó được giữ nguyên. Hãy thử lại.';
          });
        }
        return null;
      },
    );
  }

  void _beginReadinessChecks() {
    _readinessTimer?.cancel();
    _readinessAttempt = 0;
    unawaited(_checkReady());
  }

  Future<void> _checkRegistrationPage() async {
    final controller = _controller;
    if (controller == null ||
        _pendingSchedule == null ||
        !mounted ||
        _registrationProbeStarted) {
      return;
    }
    _registrationTimer?.cancel();
    try {
      final ready = await controller.evaluateJavascript(
        source: '''
        Boolean(document.querySelector('#dropSearch_HocKy') &&
          document.querySelector('#dropSearch_KeHoach') &&
          document.querySelector('#btnXemKetQuaDangKy'));
      ''',
      );
      if (!mounted || _pendingSchedule == null) return;
      if (ready == true || ready?.toString() == 'true') {
        _registrationTimer?.cancel();
        _registrationProbeStarted = true;
        await controller.evaluateJavascript(
          source: const TracuuWebViewProbe().script,
        );
        return;
      }
      if (!_registrationRequested) {
        _registrationRequested = true;
        final navigated = await controller.evaluateJavascript(
          source: '''
          (function () {
            const links = [...document.querySelectorAll('a')];
            const candidates = links.filter(node => {
              const label = (node.textContent || '').toLocaleLowerCase('vi');
              return label.includes('tra cứu') && label.includes('đăng ký');
            });
            if (candidates.length !== 1) return false;
            candidates[0].click();
            return true;
          })();
        ''',
        );
        if (navigated != true && navigated?.toString() != 'true') {
          throw const FormatException('Không tìm thấy trang TraCuu duy nhất.');
        }
      }
      _registrationAttempt++;
      if (_registrationAttempt >= 50) {
        throw const FormatException('Trang TraCuu không tải xong.');
      }
      _registrationTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) unawaited(_checkRegistrationPage());
      });
    } on Object {
      if (mounted) {
        setState(() {
          _syncing = false;
          _status = 'Không mở hoặc xác minh được TraCuu trong phiên QLĐT. Dữ liệu trước đó được giữ nguyên. Hãy thử lại.';
        });
      }
    }
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
        _readinessTimer?.cancel();
        _autoSyncStarted = true;
        await _sync();
      } else if (!ready) {
        _scheduleReadinessRetry();
      }
    } on Object {
      if (mounted) {
        setState(() => _pageReady = false);
        _scheduleReadinessRetry();
      }
    }
  }

  void _scheduleReadinessRetry() {
    _readinessAttempt += 1;
    if (_readinessAttempt >= 35) {
      if (mounted) {
        setState(() {
          _status =
              'Trang đã tải nhưng phiên QLĐT chưa sẵn sàng. '
              'Hãy tải lại hoặc đăng nhập lại.';
        });
      }
      return;
    }
    _readinessTimer?.cancel();
    _readinessTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        unawaited(_checkReady());
      }
    });
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
