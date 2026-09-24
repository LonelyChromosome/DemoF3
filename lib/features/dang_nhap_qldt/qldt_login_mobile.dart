import 'dart:async';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_sync_diagnostics.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_verifier.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/tracuu_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool supportsLiveQldtLogin = true;
const _sessionKey = 'qldt_verified_session';
const _portalPathKey = 'qldt_verified_portal_path';

Future<void> clearQldtSession() async {
  await CookieManager.instance().deleteAllCookies();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_sessionKey);
  await prefs.remove(_portalPathKey);
}

Future<QldtLoginResult?> openQldtLogin(
  BuildContext context, {
  String? testHtml,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return null;
  final cached = prefs.getBool(_sessionKey) ?? false;
  final portalPath = prefs.getString(_portalPathKey);
  return await Navigator.of(context).push<QldtLoginResult>(
    MaterialPageRoute<QldtLoginResult>(
      fullscreenDialog: true,
      builder: (_) => _QldtWebLoginScreen(
        cachedSession: cached,
        portalPath: portalPath,
        testHtml: testHtml,
      ),
    ),
  );
}

class _QldtWebLoginScreen extends StatefulWidget {
  const new({
    required this.cachedSession,
    required this.portalPath,
    this.testHtml,
  });

  final bool cachedSession;
  final String? portalPath;
  final String? testHtml;

  @override
  State<_QldtWebLoginScreen> createState() => _QldtWebLoginScreenState();
}

class _QldtWebLoginScreenState extends State<_QldtWebLoginScreen> {
  static final WebUri _qldtUri = WebUri(
    'https://qldtbeta.phenikaa-uni.edu.vn/',
  );

  InAppWebViewController? _controller;
  Timer? _readinessTimer;
  Timer? _syncWatchdog;
  Timer? _phaseTimer;
  Timer? _sessionTimer;
  final QldtSyncDiagnostics _diagnostics = QldtSyncDiagnostics();
  QldtSyncPhase? _currentPhase;
  ImportedScheduleData? _pendingSchedule;
  int _syncEpoch = 0;
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
    _syncWatchdog?.cancel();
    _phaseTimer?.cancel();
    _sessionTimer?.cancel();
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
                              initialUrlRequest: widget.testHtml == null
                                  ? URLRequest(url: WebUri(_initialUrl))
                                  : null,
                              initialData: widget.testHtml == null
                                  ? null
                                  : InAppWebViewInitialData(
                                      data: widget.testHtml!,
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
                                    if (_pendingSchedule == null &&
                                        !_syncing &&
                                        !_autoSyncStarted) {
                                      _pageReady = false;
                                      _status = _showWebPage
                                          ? 'Đang tải trang đăng nhập QLĐT...'
                                          : 'Đang kiểm tra phiên QLĐT...';
                                    }
                                  });
                                }
                              },
                              onLoadStop: (_, _) {
                                if (_pendingSchedule == null &&
                                    !_autoSyncStarted) {
                                  _beginReadinessChecks();
                                }
                              },
                              onUpdateVisitedHistory: (_, _, _) {
                                unawaited(_updateBackState());
                              },
                              onReceivedError: (_, request, error) {
                                if (request.isForMainFrame == true && mounted) {
                                  if (_syncing) {
                                    _stopSync(
                                      _syncEpoch,
                                      'Không tải được QLĐT. Kiểm tra mạng rồi thử lại.',
                                      code: 'NETWORK_ERROR',
                                    );
                                  } else {
                                    setState(() {
                                      _showWebPage = true;
                                      _status = 'Không tải được QLĐT. Kiểm tra mạng rồi thử lại.';
                                    });
                                  }
                                }
                              },
                              onReceivedHttpError: (_, request, response) {
                                if (request.isForMainFrame == true && mounted) {
                                  if (_syncing) {
                                    _stopSync(
                                      _syncEpoch,
                                      'QLĐT trả lỗi HTTP ${response.statusCode}.',
                                      code: 'HTTP_ERROR',
                                    );
                                  } else {
                                    setState(
                                      () => _status =
                                          'QLĐT trả lỗi HTTP ${response.statusCode}.',
                                    );
                                  }
                                }
                              },
                              onRenderProcessGone: (_, detail) {
                                _readinessTimer?.cancel();
                                _controller = null;
                                if (_syncing) {
                                  _stopSync(
                                    _syncEpoch,
                                    'Tiến trình WebView đã dừng.',
                                    code: 'RENDERER_GONE',
                                  );
                                }
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
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.white,
                              child: Center(
                                child: _syncing || !_autoSyncStarted
                                    ? const CircularProgressIndicator()
                                    : const Icon(Icons.error_outline, size: 48),
                              ),
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
    try {
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
    } on Object {
      return;
    }
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
    if (!_syncing) {
      _diagnostics.start(QldtSyncPhase.session);
    }
    if (widget.cachedSession && !_syncing) {
      _sessionTimer = Timer(const Duration(seconds: 35), () {
        if (!mounted || _pageReady || _syncing) return;
        _diagnostics.finish('SESSION_TIMEOUT');
        setState(() {
          _showWebPage = true;
          _status = 'Phiên QLĐT đã hết hạn hoặc cổng sinh viên không phản hồi. Hãy đăng nhập lại.';
        });
      });
    }
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaSyncResult',
      callback: (arguments) async {
        if (!mounted ||
            !_syncing ||
            arguments.length < 2 ||
            arguments.first?.toString() != '$_syncEpoch') {
          return null;
        }
        final epoch = _syncEpoch;
        try {
          final raw = arguments[1]?.toString() ?? '';
          final data = const QldtParser().parseLiveEnvelope(raw, strict: true);
          if (!mounted || !_syncing || epoch != _syncEpoch) {
            return null;
          }
          _pendingSchedule = data;
          setState(() {
            _showWebPage = false;
            _status = 'Đang lấy học kỳ và môn đăng ký từ QLĐT...';
          });
          _startPhase(
            QldtSyncPhase.semesterPlan,
            const Duration(seconds: 20),
            epoch,
          );
          await _requestRegistration(epoch);
        } on Object {
          _stopSync(
            epoch,
            'Dữ liệu lịch QLĐT không hợp lệ. Dữ liệu cũ được giữ nguyên.',
          );
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaSyncError',
      callback: (arguments) {
        if (arguments.length >= 2 &&
            arguments.first?.toString() == '$_syncEpoch' &&
            _syncing) {
          _stopSync(_syncEpoch, arguments[1].toString());
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaRegistrationStage',
      callback: (arguments) {
        if (!mounted ||
            !_syncing ||
            arguments.length < 2 ||
            arguments.first?.toString() != '$_syncEpoch') {
          return null;
        }
        final stage = arguments[1]?.toString();
        if (stage == 'semesterPlan') {
          _startPhase(
            QldtSyncPhase.semesterPlan,
            const Duration(seconds: 20),
            _syncEpoch,
          );
        } else if (stage == 'subjects') {
          _startPhase(
            QldtSyncPhase.subjects,
            const Duration(seconds: 20),
            _syncEpoch,
          );
        } else if (stage == 'verification') {
          _startPhase(
            QldtSyncPhase.verification,
            const Duration(seconds: 10),
            _syncEpoch,
          );
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaRegistrationResult',
      callback: (arguments) async {
        if (!mounted ||
            !_syncing ||
            _pendingSchedule == null ||
            arguments.length < 2 ||
            arguments.first?.toString() != '$_syncEpoch') {
          return null;
        }
        final epoch = _syncEpoch;
        try {
          final registration = const TracuuApi().parse(arguments[1] as String);
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
          _startPhase(
            QldtSyncPhase.sessionCache,
            const Duration(seconds: 10),
            epoch,
          );
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_sessionKey, true);
          } on Object {
            // A cache failure must not discard a verified schedule.
          }
          if (!mounted || !_syncing || epoch != _syncEpoch) return null;
          _phaseTimer?.cancel();
          _syncWatchdog?.cancel();
          _diagnostics.finish('OK');
          try {
            await _diagnostics.flushed.timeout(const Duration(seconds: 2));
          } on Object {
            // Diagnostic persistence cannot block a verified schedule.
          }
          if (!mounted || !_syncing || epoch != _syncEpoch) return null;
          Navigator.of(context).pop(
            QldtLoginResult(
              schedule: semester.toImportedScheduleData(),
              semester: semester,
            ),
          );
        } on Object catch (error) {
          _stopSync(epoch, _verificationErrorMessage(error));
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaRegistrationError',
      callback: (arguments) {
        if (mounted &&
            _syncing &&
            arguments.length >= 2 &&
            arguments.first?.toString() == '$_syncEpoch') {
          final code = arguments[1].toString();
          final reason = switch (code) {
            'SESSION_EXPIRED' => 'Phiên QLĐT đã hết hạn.',
            'NETWORK_ERROR' ||
            'REQUEST_ERROR' => 'Yêu cầu dữ liệu TraCuu thất bại.',
            'NO_SEMESTER' => 'TraCuu không trả học kỳ hợp lệ.',
            'PLAN_AMBIGUOUS' =>
              'Không xác định được kế hoạch đăng ký duy nhất.',
            _ => 'TraCuu trả dữ liệu không hợp lệ.',
          };
          _stopSync(
            _syncEpoch,
            '$reason Dữ liệu cũ được giữ nguyên. Hãy thử lại.',
            code: code,
          );
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

  Future<void> _requestRegistration(int epoch) async {
    final controller = _controller;
    if (controller == null || !mounted || !_syncing || epoch != _syncEpoch) {
      return;
    }
    try {
      await controller.evaluateJavascript(
        source: const TracuuApi().scriptForAttempt(epoch),
      );
    } on Object {
      _stopSync(
        epoch,
        'Không gọi được dữ liệu TraCuu trong phiên QLĐT. Hãy thử lại.',
        code: 'REGISTRATION_REQUEST_ERROR',
      );
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
      if (!mounted || (_autoSyncStarted && !_syncing)) {
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
        _sessionTimer?.cancel();
        _diagnostics.finish('OK');
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
        _sessionTimer?.cancel();
        _diagnostics.finish('SESSION_TIMEOUT');
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
    final epoch = ++_syncEpoch;
    _currentPhase = null;
    _syncWatchdog?.cancel();
    _syncWatchdog = Timer(const Duration(seconds: 70), () {
      _stopSync(
        epoch,
        'Đồng bộ quá 70 giây. Dữ liệu cũ được giữ nguyên. Hãy thử lại.',
        code: 'TOTAL_TIMEOUT',
      );
    });
    _startPhase(QldtSyncPhase.schedule, const Duration(seconds: 20), epoch);
    setState(() {
      _syncing = true;
      _showWebPage = false;
      _status = 'Đang lấy lịch cá nhân từ QLĐT...';
    });
    _pendingSchedule = null;

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
              $epoch,
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
                $epoch,
                JSON.stringify({name: name, response: response})
              );
            },
            error: function () {
              window.flutter_inappwebview.callHandler(
                'betterPhenikaaSyncError',
                $epoch,
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
            $epoch,
            'Không thực hiện được yêu cầu lịch QLĐT.'
          );
        }
      })();
    ''';

    try {
      await controller.evaluateJavascript(source: script);
    } on Object {
      _stopSync(epoch, 'Không thể yêu cầu lịch QLĐT. Hãy thử lại.');
    }
  }

  void _startPhase(QldtSyncPhase phase, Duration limit, int epoch) {
    if (_currentPhase != null && phase.index <= _currentPhase!.index) return;
    _currentPhase = phase;
    _phaseTimer?.cancel();
    _diagnostics.start(phase);
    _phaseTimer = Timer(limit, () {
      final reason =
          '${phase.name} không phản hồi trong ${limit.inSeconds} giây.';
      _stopSync(
        epoch,
        '$reason Dữ liệu cũ được giữ nguyên. Hãy thử lại.',
        code: '${phase.name.toUpperCase()}_TIMEOUT',
      );
    });
  }

  void _stopSync(int epoch, String status, {String code = 'FAILED'}) {
    if (!mounted || epoch != _syncEpoch) return;
    _syncWatchdog?.cancel();
    _phaseTimer?.cancel();
    _diagnostics.finish(code);
    _pendingSchedule = null;
    setState(() {
      _syncing = false;
      _status = status;
    });
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }
}
