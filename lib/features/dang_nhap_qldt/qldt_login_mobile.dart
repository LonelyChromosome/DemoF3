import 'dart:async';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_verifier.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/tracuu_webview_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool supportsLiveQldtLogin = true;
const _sessionKey = 'qldt_verified_session';
const _portalPathKey = 'qldt_verified_portal_path';
const _tracuuPathKey = 'qldt_verified_tracuu_path';

Future<void> clearQldtSession() async {
  await CookieManager.instance().deleteAllCookies();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_sessionKey);
  await prefs.remove(_portalPathKey);
  await prefs.remove(_tracuuPathKey);
}

Future<QldtLoginResult?> openQldtLogin(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return null;
  final cached = prefs.getBool(_sessionKey) ?? false;
  final portalPath =
      prefs.getString(_tracuuPathKey) ?? prefs.getString(_portalPathKey);
  return await Navigator.of(context).push<QldtLoginResult>(
    MaterialPageRoute<QldtLoginResult>(
      fullscreenDialog: true,
      builder: (_) =>
          _QldtWebLoginScreen(cachedSession: cached, portalPath: portalPath),
    ),
  );
}

class _QldtWebLoginScreen extends StatefulWidget {
  const new({required this.cachedSession, required this.portalPath});

  final bool cachedSession;
  final String? portalPath;

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
  bool _registrationChecking = false;
  bool _pageReady = false;
  bool _syncing = false;
  bool _autoSyncStarted = false;
  bool _rendererGone = false;
  bool _webCanGoBack = false;
  bool _allowRoutePop = false;
  bool _showWebPage = false;
  final bool _hybridComposition = true;
  int _webViewGeneration = 0;
  int _readinessAttempt = 0;
  String _status = 'Đăng nhập bằng tài khoản Microsoft của bạn.';

  @override
  void initState() {
    super.initState();
    _showWebPage = !widget.cachedSession;
    if (widget.cachedSession) {
      _status = 'Đang kiểm tra phiên QLĐT và đồng bộ...';
    }
  }

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
                  : Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.white,
                            child: InAppWebView(
                              key: ValueKey<int>(_webViewGeneration),
                              initialUrlRequest: URLRequest(
                                url: WebUri(_initialUrl),
                              ),
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
                                    if (_pendingSchedule == null && !_syncing) {
                                      _pageReady = false;
                                      _status = _showWebPage
                                          ? 'Đang tải trang đăng nhập QLĐT...'
                                          : 'Đang kiểm tra phiên QLĐT...';
                                    }
                                  });
                                }
                              },
                              onLoadStop: (_, _) {
                                if (_pendingSchedule == null) {
                                  _beginReadinessChecks();
                                } else {
                                  _registrationRequested = false;
                                  unawaited(_checkRegistrationPage());
                                }
                              },
                              onUpdateVisitedHistory: (_, _, _) {
                                unawaited(_updateBackState());
                                if (_pendingSchedule != null) {
                                  _registrationRequested = false;
                                  unawaited(_checkRegistrationPage());
                                }
                              },
                              onReceivedError: (_, request, error) {
                                if (request.isForMainFrame == true && mounted) {
                                  setState(() {
                                    _showWebPage = _pendingSchedule == null;
                                    _syncing = false;
                                    _status = 'Không tải được QLĐT. Kiểm tra mạng rồi thử lại.';
                                  });
                                }
                              },
                              onReceivedHttpError: (_, request, response) {
                                if (request.isForMainFrame == true && mounted) {
                                  setState(() {
                                    _showWebPage = _pendingSchedule == null;
                                    _syncing = false;
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
                        if (!_showWebPage)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Colors.white,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                      ],
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

  String get _initialUrl {
    final path = widget.portalPath;
    if (path == null || !path.startsWith('/') || path.startsWith('//')) {
      return _qldtUri.toString();
    }
    return Uri.parse(_qldtUri.toString()).resolve(path).toString();
  }

  Future<void> _rememberPortal(InAppWebViewController controller) async {
    final uri = Uri.tryParse((await controller.getUrl())?.toString() ?? '');
    if (uri == null ||
        uri.host != _qldtUri.host ||
        uri.hasQuery ||
        uri.hasFragment) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_portalPathKey, uri.path);
    await prefs.setBool(_sessionKey, true);
  }

  Future<void> _rememberVerifiedTracuu() async {
    final uri = Uri.tryParse((await _controller?.getUrl())?.toString() ?? '');
    if (uri == null ||
        uri.host != _qldtUri.host ||
        uri.hasQuery ||
        uri.hasFragment) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tracuuPathKey, uri.path);
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
          setState(() {
            _showWebPage = false;
            _status = 'Đang xác minh học kỳ và môn đã đăng ký trên TraCuu...';
          });
          await _checkRegistrationPage();
        } on Object {
          if (mounted) {
            setState(() {
              _syncing = false;
              _status =
                  'Dữ liệu lịch QLĐT không hợp lệ. Dữ liệu cũ được giữ nguyên.';
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
      callback: (arguments) async {
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_sessionKey, true);
          await _rememberVerifiedTracuu();
          if (!mounted) return null;
          Navigator.of(context).pop(
            QldtLoginResult(
              schedule: semester.toImportedScheduleData(),
              semester: semester,
            ),
          );
        } on Object catch (error) {
          setState(() {
            _syncing = false;
            _status = _verificationErrorMessage(error);
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
            _registrationProbeStarted = false;
            _status = 'TraCuu chưa tải đủ danh sách đăng ký hoặc yêu cầu Xem thất bại. Dữ liệu cũ được giữ nguyên. Hãy thử lại.';
          });
        }
        return null;
      },
    );
  }

  String _verificationErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    final reason = message.contains('kế hoạch')
        ? 'Kế hoạch đăng ký không khớp'
        : message.contains('học kỳ')
        ? 'Học kỳ đăng ký không khớp'
        : message.contains('lớp')
        ? 'Không đối chiếu được lớp học phần hoặc ca thi'
        : 'Dữ liệu đăng ký không hợp lệ';
    return '$reason. Dữ liệu cũ được giữ nguyên. Hãy thử lại.';
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
        _registrationProbeStarted ||
        _registrationChecking) {
      return;
    }
    _registrationChecking = true;
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
              return (label.includes('tra cứu') && label.includes('đăng ký')) ||
                label.trim() === 'đăng ký học';
            });
            if (candidates.length !== 1) return false;
            candidates[0].click();
            return true;
          })();
        ''',
        );
        if (navigated != true && navigated?.toString() != 'true') {
          _registrationRequested = false;
        }
      }
      _registrationAttempt++;
      if (_registrationAttempt >= 200) {
        throw const FormatException(
          'Trang TraCuu không xuất hiện sau khi chờ.',
        );
      }
      _registrationTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) unawaited(_checkRegistrationPage());
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _syncing = false;
          _registrationProbeStarted = false;
          _status = error is FormatException
              ? 'TraCuu chưa sẵn sàng sau 60 giây. Dữ liệu cũ được giữ nguyên. Hãy thử lại.'
              : 'Không đọc được trang TraCuu. Dữ liệu cũ được giữ nguyên. Hãy thử lại.';
        });
      }
    } finally {
      _registrationChecking = false;
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
        unawaited(_rememberPortal(controller));
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
          _showWebPage = true;
          _autoSyncStarted = false;
          _status = 'Phiên QLĐT chưa sẵn sàng hoặc đã hết hạn. Hãy đăng nhập lại nếu cần.';
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
      _showWebPage = false;
      _status = 'Đang lấy lịch cá nhân từ QLĐT...';
    });
    _pendingSchedule = null;
    _registrationTimer?.cancel();
    _registrationAttempt = 0;
    _registrationRequested = false;
    _registrationProbeStarted = false;

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
            'Không thực hiện được yêu cầu lịch QLĐT.'
          );
        }
      })();
    ''';

    try {
      await controller.evaluateJavascript(source: script);
    } on Object {
      if (mounted) {
        setState(() {
          _syncing = false;
          _status = 'Không thể yêu cầu lịch QLĐT. Hãy thử lại.';
        });
      }
    }
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }
}
