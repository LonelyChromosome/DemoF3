import 'dart:async';
import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/diagnostics/qldt_sync_diagnostics.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/diagnostics/verification_diagnostics.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_native_transport.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_range.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_verifier.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/tracuu_api.dart';
import 'package:better_phenikaa_schedule/features/tro_li/assistant_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool supportsLiveQldtLogin = true;
const _sessionKey = 'qldt_verified_session';
const _portalPathKey = 'qldt_verified_portal_path';
const _nativeSessionKey = 'better_phenikaa_qldt_native_session_v1';
const _profileKey = 'better_phenikaa_qldt_profile_v1';
const _accountDisplayNameKey = 'better_phenikaa_account_display_name_v1';
const _syncModeKey = 'better_phenikaa_qldt_sync_mode_v1';
const _legacyMode = 'legacy';
const _nativeMode = 'native';
const _credentialChannel = MethodChannel('better_phenikaa/qldt_credentials');

String _sanitizeQldtProfileName(Object? raw) {
  final value = raw?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  if (value.length < 3 || value.length > 120 || value.contains('@')) return '';
  final lower = value.toLowerCase();
  if (<String>{
    'tài khoản',
    'đăng xuất',
    'account',
    'profile',
    'người dùng',
    'sinh viên',
    'student',
    'user',
  }.contains(lower)) {
    return '';
  }
  return value;
}

String _profileNameFromObject(Object? node, [int depth = 0]) {
  if (node == null || depth > 5) return '';
  if (node is Map) {
    const exactKeys = <String>{
      'NAME',
      'FULLNAME',
      'FULL_NAME',
      'DISPLAYNAME',
      'DISPLAY_NAME',
      'HOTEN',
      'HO_TEN',
      'HOVATEN',
      'TENNGUOIHOC',
      'NGUOIHOTEN',
      'SINHVIENTEN',
      'TENSINHVIEN',
      'TENNGUOIDUNG',
    };
    for (final entry in node.entries) {
      final key = entry.key.toString().trim().toUpperCase();
      final compact = key.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final looksLikeName =
          exactKeys.contains(key) ||
          exactKeys.contains(compact) ||
          compact.endsWith('FULLNAME') ||
          compact.endsWith('DISPLAYNAME') ||
          compact.endsWith('HOTEN') ||
          (compact.contains('NGUOIHOC') && compact.endsWith('TEN'));
      if (!looksLikeName) continue;
      final candidate = _sanitizeQldtProfileName(entry.value);
      if (candidate.isNotEmpty) return candidate;
    }

    String given = '';
    String family = '';
    for (final entry in node.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key == 'given_name' || key == 'givenname') {
        given = _sanitizeQldtProfileName(entry.value);
      } else if (key == 'family_name' ||
          key == 'familyname' ||
          key == 'surname') {
        family = _sanitizeQldtProfileName(entry.value);
      }
    }
    if (given.isNotEmpty && family.isNotEmpty) {
      return ('$family $given').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    for (final value in node.values) {
      if (value is Map || value is List) {
        final nested = _profileNameFromObject(value, depth + 1);
        if (nested.isNotEmpty) return nested;
      }
    }
  } else if (node is List) {
    for (final value in node) {
      final nested = _profileNameFromObject(value, depth + 1);
      if (nested.isNotEmpty) return nested;
    }
  }
  return '';
}

String _displayNameFromJwtToken(String rawToken) {
  try {
    var token = rawToken.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    final parts = token.split('.');
    if (parts.length < 2) return '';
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    return _profileNameFromObject(decoded);
  } on Object {
    return '';
  }
}

Future<String> readCachedQldtDisplayName() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final profileRaw = prefs.getString(_profileKey);
    if (profileRaw != null && profileRaw.isNotEmpty) {
      try {
        final profile = Map<String, dynamic>.from(
          jsonDecode(profileRaw) as Map<dynamic, dynamic>,
        );
        if ((profile['source'] ?? '').toString() == 'qldt_api_registration') {
          final cached = _sanitizeQldtProfileName(profile['name']);
          if (cached.isNotEmpty) return cached;
        }
      } on Object {
        // Ignore legacy/untrusted profile caches.
      }
    }

    final sessionRaw = prefs.getString(_nativeSessionKey);
    if (sessionRaw == null || sessionRaw.isEmpty) return '';
    final session = Map<String, dynamic>.from(
      jsonDecode(sessionRaw) as Map<dynamic, dynamic>,
    );
    if ((session['nameSource'] ?? '').toString() != 'qldt_api_registration') return '';
    return _sanitizeQldtProfileName(session['name']);
  } on Object {
    return '';
  }
}
Future<String> readQldtAccountDisplayName() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return _sanitizeQldtProfileName(prefs.getString(_accountDisplayNameKey));
  } on Object {
    return '';
  }
}

Future<void> _saveQldtAccountDisplayName(String name) async {
  final value = _sanitizeQldtProfileName(name);
  if (value.isEmpty) {
    throw const FormatException('ACCOUNT_DISPLAY_NAME_EMPTY');
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_accountDisplayNameKey, value);
}

Future<void> clearQldtSession() async {
  await CookieManager.instance().deleteAllCookies();
  await _credentialChannel.invokeMethod<void>('clear');
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_sessionKey);
  await prefs.remove(_portalPathKey);
  await prefs.remove(_nativeSessionKey);
  await prefs.remove(_profileKey);
  await prefs.remove(_accountDisplayNameKey);
  await prefs.remove(_syncModeKey);
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

class _QldtWebLoginScreenState extends State<_QldtWebLoginScreen>
    with SingleTickerProviderStateMixin {
  static final WebUri _qldtUri = WebUri(
    'https://qldtbeta.phenikaa-uni.edu.vn/',
  );

  InAppWebViewController? _controller;
  Timer? _readinessTimer;
  Timer? _syncWatchdog;
  Timer? _phaseTimer;
  Timer? _sessionTimer;
  Timer? _legacyFallbackTimer;
  final QldtSyncDiagnostics? _diagnostics = qldtDiagnosticsEnabled
      ? QldtSyncDiagnostics()
      : null;
  QldtSyncPhase? _currentPhase;
  ImportedScheduleData? _pendingSchedule;
  QldtNativeSession? _nativeSession;
  String _resolvedDisplayName = '';
  String? _pendingRegistrationRaw;
  String? _failureDiagnosticsJson;
  final List<String> _scheduleStages = <String>[];
  int _syncEpoch = 0;
  bool _pageReady = false;
  bool _syncing = false;
  bool _autoSyncStarted = false;
  bool _usingNativeTransport = false;
  bool _switchingToNative = false;
  bool _rendererGone = false;
  bool _webCanGoBack = false;
  bool _allowRoutePop = false;
  bool _showWebPage = false;
  bool _portalInputLocked = false;
  bool _sawMicrosoftAuth = false;
  late final AnimationController _reloadSpinController;
  String? _submittedUsername;
  String? _submittedPassword;
  String? _savedUsername;
  String? _savedPassword;
  bool _autoEmailSubmitted = false;
  bool _autoPasswordSubmitted = false;
  final bool _hybridComposition = true;
  int _webViewGeneration = 0;
  int _readinessAttempt = 0;
  String _status = 'Đăng nhập bằng tài khoản Microsoft của bạn.';
  AssistantPack _assistantPack = AssistantPack.normal;

  @override
  void initState() {
    super.initState();
    _reloadSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat();
    unawaited(_loadSavedCredentials());
    unawaited(_loadAssistantPack());
    _showWebPage = !widget.cachedSession;
    _portalInputLocked = widget.cachedSession;
    if (widget.cachedSession) {
      _status = 'Đang kiểm tra phiên QLĐT và đồng bộ...';
    }
  }

  Future<void> _loadAssistantPack() async {
    final pack = await AssistantSelection.load();
    if (mounted) _assistantPack = pack;
  }

  @override
  void dispose() {
    _readinessTimer?.cancel();
    _syncWatchdog?.cancel();
    _phaseTimer?.cancel();
    _sessionTimer?.cancel();
    _legacyFallbackTimer?.cancel();
    _reloadSpinController.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<QldtLoginResult>(
      canPop: !_portalInputLocked && (_allowRoutePop || !_webCanGoBack),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_portalInputLocked) {
          unawaited(_handleBack());
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Scaffold(
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
                              onLoadStart: (_, url) {
                                _trackAuthNavigation(url?.toString());
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
                              onLoadStop: (controller, url) {
                                _trackAuthNavigation(url?.toString());
                                unawaited(
                                  _handleLoginPage(controller, url?.toString()),
                                );
                                if (_pendingSchedule == null &&
                                    !_autoSyncStarted) {
                                  _beginReadinessChecks();
                                }
                              },
                              onUpdateVisitedHistory: (controller, url, _) {
                                _trackAuthNavigation(url?.toString());
                                unawaited(
                                  _handleLoginPage(controller, url?.toString()),
                                );
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
                                  }
                                  _readinessTimer?.cancel();
                                  setState(() {
                                    _pageReady = false;
                                    _showWebPage = true;
                                    _status =
                                        'QLĐT trả lỗi HTTP ${response.statusCode}. Hãy thử tải lại.';
                                  });
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
                        if (_portalInputLocked || !_showWebPage)
                          Positioned.fill(
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                const ModalBarrier(
                                  dismissible: false,
                                  color: Colors.white,
                                ),
                                Center(
                                  child: RotationTransition(
                                    turns: _reloadSpinController,
                                    child: const Icon(
                                      Icons.refresh_rounded,
                                      size: 46,
                                      color: Color(0xFF1747B5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            if (!_syncing &&
                (_autoSyncStarted || _failureDiagnosticsJson != null))
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _pageReady ? _sync : _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử đồng bộ lại'),
                    ),
                  ),
                ),
              ),
            if (qldtDiagnosticsEnabled &&
                _failureDiagnosticsJson != null &&
                !_syncing)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _failureDiagnosticsJson!),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép chẩn đoán QLĐT.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Sao chép chẩn đoán QLĐT'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
          if (_portalInputLocked)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const ModalBarrier(
                    dismissible: false,
                    color: Colors.white,
                  ),
                  SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            RotationTransition(
                              turns: _reloadSpinController,
                              child: const Icon(
                                Icons.refresh_rounded,
                                size: 52,
                                color: Color(0xFF1747B5),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _status,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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

  String _cleanProfileName(Object? raw) =>
      _sanitizeQldtProfileName(raw);

  Future<String> _cachedProfileNameFor(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);
      if (raw == null || raw.isEmpty) return '';
      final json = Map<String, dynamic>.from(
        jsonDecode(raw) as Map<dynamic, dynamic>,
      );
      if ((json['userId'] ?? '').toString() != userId) return '';
      if ((json['source'] ?? '').toString() != 'qldt_api_registration') return '';
      return _cleanProfileName(json['name']);
    } on Object {
      return '';
    }
  }

  Future<void> _rememberProfileName(
    QldtNativeSession session,
    String rawName,
  ) async {
    final name = _cleanProfileName(rawName);
    if (name.isEmpty) return;
    _resolvedDisplayName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _profileKey,
        jsonEncode(<String, String>{
          'userId': session.userId,
          'name': name,
          'source': 'qldt_api_registration',
        }),
      );
    } on Object {
      // Profile cache must never block schedule sync.
    }
  }

  Future<void> _cacheNativeSession(QldtNativeSession session) async {
    final prefs = await SharedPreferences.getInstance();
    // Raw QLĐT API name is sync metadata only. The user's chosen account
    // display name is persisted separately and never written into schedule data.
    final name = _cleanProfileName(_resolvedDisplayName);
    await prefs.setString(
      _nativeSessionKey,
      jsonEncode(<String, dynamic>{
        'tokenJWT': session.tokenJwt,
        'userId': session.userId,
        'iM': session.iM,
        'appId': session.appId,
        'strChucNangId': session.functionId,
        'cookie': session.cookie,
        'name': name,
        'nameSource': name.isEmpty ? '' : 'qldt_api_registration',
      }),
    );
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
    _phaseTimer?.cancel();
    _syncWatchdog?.cancel();
    _sessionTimer?.cancel();
    _legacyFallbackTimer?.cancel();
    ++_syncEpoch;
    _autoSyncStarted = false;
    _pendingSchedule = null;
    _nativeSession = null;
    _pendingRegistrationRaw = null;
    _currentPhase = null;
    setState(() {
      _syncing = false;
      _pageReady = false;
      _showWebPage = false;
      _status = 'Đang tải lại QLĐT...';
    });
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

  bool _isMicrosoftLogin(String? url) {
    final host = Uri.tryParse(url ?? '')?.host.toLowerCase();
    return host == 'login.microsoftonline.com' ||
        host == 'login.live.com' ||
        (host?.endsWith('.microsoftonline.com') ?? false);
  }

  void _trackAuthNavigation(String? url) {
    if (widget.testHtml != null) return;
    if (_isMicrosoftLogin(url)) {
      _sawMicrosoftAuth = true;
      return;
    }
    final host = Uri.tryParse(url ?? '')?.host.toLowerCase();
    if (!_sawMicrosoftAuth || host != _qldtUri.host.toLowerCase()) return;
    if (_portalInputLocked || !mounted) return;
    setState(() {
      _portalInputLocked = true;
      _showWebPage = false;
      _status = 'Đang tải dữ liệu QLĐT...';
    });
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final saved = await _credentialChannel.invokeMapMethod<String, String>(
        'read',
      );
      if (!mounted || saved == null) return;
      _savedUsername = saved['username'];
      _savedPassword = saved['password'];
      final controller = _controller;
      if (controller != null) {
        final url = await controller.getUrl();
        await _handleLoginPage(controller, url?.toString());
      }
    } on Object {
      // Manual Microsoft login remains available if the local key is unavailable.
    }
  }

  Future<void> _handleLoginPage(
    InAppWebViewController controller,
    String? url,
  ) async {
    if (!_isMicrosoftLogin(url) || widget.testHtml != null) return;
    // Capture only the values in the existing Microsoft form at submit time.
    // No input or keystroke listeners, and no credential data in diagnostics.
    try {
      await controller.evaluateJavascript(
        source: '''
        (function () {
          if (!['login.microsoftonline.com', 'login.live.com'].includes(location.hostname) &&
              !location.hostname.endsWith('.microsoftonline.com')) return;
          if (window.__betterPhenikaaSubmittedCapture) return;
          window.__betterPhenikaaSubmittedCapture = true;
          function capture() {
            var password = document.querySelector('input[type="password"]');
            var email = document.querySelector('input[type="email"], input[name="loginfmt"], #i0116');
            if (email && email.value) {
              window.flutter_inappwebview.callHandler('betterPhenikaaLoginSubmitted', 'username', email.value);
            }
            if (password && password.value) {
              window.flutter_inappwebview.callHandler('betterPhenikaaLoginSubmitted', 'password', password.value);
            }
          }
          document.addEventListener('submit', capture, true);
          document.addEventListener('click', function (event) {
            if (event.target.closest('#idSIButton9, button[type="submit"], input[type="submit"]')) capture();
          }, true);
        })();
      ''',
      );
      final username = _savedUsername;
      final password = _savedPassword;
      if (username == null || password == null) return;
      await controller.evaluateJavascript(
        source:
            '''
        (function () {
          if (!['login.microsoftonline.com', 'login.live.com'].includes(location.hostname) &&
              !location.hostname.endsWith('.microsoftonline.com')) return;
          if (window.__betterPhenikaaAutoLogin) return;
          window.__betterPhenikaaAutoLogin = true;
          var emailDone = ${_autoEmailSubmitted ? 'true' : 'false'};
          var passwordDone = ${_autoPasswordSubmitted ? 'true' : 'false'};
          var username = ${jsonEncode(username)};
          var password = ${jsonEncode(password)};
          var attempts = 0;
          var timer = setInterval(function () {
            if (++attempts > 80 || (emailDone && passwordDone)) { clearInterval(timer); return; }
            var field = document.querySelector('input[type="password"]');
            if (field && !passwordDone) {
              passwordDone = true;
              var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
              setter.call(field, password);
              field.dispatchEvent(new Event('input', { bubbles: true }));
              field.dispatchEvent(new Event('change', { bubbles: true }));
              window.flutter_inappwebview.callHandler('betterPhenikaaAutoStep', 'password');
              setTimeout(function () { document.querySelector('#idSIButton9, button[type="submit"], input[type="submit"]')?.click(); }, 100);
              clearInterval(timer);
            } else if (!emailDone) {
              field = document.querySelector('input[type="email"], input[name="loginfmt"], #i0116');
              if (!field) return;
              emailDone = true;
              var setter2 = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
              setter2.call(field, username);
              field.dispatchEvent(new Event('input', { bubbles: true }));
              field.dispatchEvent(new Event('change', { bubbles: true }));
              window.flutter_inappwebview.callHandler('betterPhenikaaAutoStep', 'email');
              setTimeout(function () { document.querySelector('#idSIButton9, button[type="submit"], input[type="submit"]')?.click(); }, 100);
              clearInterval(timer);
            }
          }, 250);
        })();
      ''',
      );
    } on Object {
      // The original form stays usable if a provider changes its markup.
    }
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaAutoStep',
      callback: (arguments) {
        if (arguments.isNotEmpty && arguments.first == 'email') {
          _autoEmailSubmitted = true;
        }
        if (arguments.isNotEmpty && arguments.first == 'password') {
          _autoPasswordSubmitted = true;
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaLoginSubmitted',
      callback: (arguments) {
        if (arguments.length != 2 || arguments[1] is! String) return null;
        final value = arguments[1] as String;
        if (arguments[0] == 'username' && value.length <= 256) {
          _submittedUsername = value.trim();
        } else if (arguments[0] == 'password' && value.length <= 512) {
          _submittedPassword = value;
        }
        return null;
      },
    );
    if (!_syncing) {
      _diagnostics?.start(QldtSyncPhase.session);
    }
    if (widget.cachedSession && !_syncing) {
      _sessionTimer = Timer(const Duration(seconds: 35), () {
        if (!mounted || _pageReady || _syncing) return;
        _diagnostics?.finish('SESSION_TIMEOUT');
        setState(() {
          _showWebPage = true;
          _status = 'Phiên QLĐT đã hết hạn hoặc cổng sinh viên không phản hồi. Hãy đăng nhập lại.';
        });
      });
    }
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaScheduleStage',
      callback: (arguments) {
        if (mounted &&
            _syncing &&
            arguments.length >= 2 &&
            arguments.first?.toString() == '$_syncEpoch') {
          final stage = arguments[1]?.toString();
          if (<String>{
            'request',
            'success',
            'error',
            'exception',
          }.contains(stage)) {
            _scheduleStages.add(stage!);
          }
        }
        return null;
      },
    );
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
          final registrationRaw = _pendingRegistrationRaw;
          _pendingRegistrationRaw = null;
          setState(() {
            _showWebPage = false;
            _status = 'Đang lấy học kỳ và môn đăng ký từ QLĐT...';
          });
          if (registrationRaw != null) {
            unawaited(_completeRegistration(epoch, registrationRaw));
          }
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
        final safeStage = switch (stage) {
          'scriptStart' ||
          'semesterRequest' ||
          'semesterResponse' ||
          'semesterPlan' ||
          'subjects' ||
          'verification' => stage,
          _ => 'UNKNOWN',
        };
        _diagnostics?.mark('REG_STAGE_$safeStage');
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
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'betterPhenikaaRegistrationResult',
      callback: (arguments) async {
        if (!mounted ||
            !_syncing ||
            arguments.length < 2 ||
            arguments.first?.toString() != '$_syncEpoch') {
          return null;
        }
        final epoch = _syncEpoch;
        final raw = arguments[1]?.toString() ?? '';
        if (_pendingSchedule == null) {
          _pendingRegistrationRaw = raw;
          unawaited(_requestScheduleForRegistration(epoch, raw));
          return null;
        }
        await _completeRegistration(epoch, raw);
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
          final code = switch (arguments[1].toString()) {
            'SESSION_EXPIRED' => 'SESSION_EXPIRED',
            'NETWORK_ERROR' => 'NETWORK_ERROR',
            'REQUEST_ERROR' => 'REQUEST_ERROR',
            'NO_SEMESTER' => 'NO_SEMESTER',
            'PLAN_AMBIGUOUS' => 'PLAN_AMBIGUOUS',
            _ => 'INVALID_RESPONSE',
          };
          if (qldtDiagnosticsEnabled &&
              code == 'PLAN_AMBIGUOUS' &&
              arguments.length >= 3) {
            try {
              _failureDiagnosticsJson =
                  QldtSyncDiagnostics.sanitizePlanSnapshot(
                    arguments[2].toString(),
                  );
            } on Object {
              _failureDiagnosticsJson = null;
            }
          }
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

  Future<void> _completeRegistration(int epoch, String raw) async {
    if (!mounted || !_syncing || epoch != _syncEpoch) return;
    RegisteredSemester? registration;
    var verificationStage = 'registration_parse';
    try {
      _startPhase(
        QldtSyncPhase.verification,
        const Duration(seconds: 10),
        epoch,
      );
      registration = const TracuuApi().parse(raw);
      final apiDisplayName = const TracuuApi().displayNameFromVerifiedResult(raw);
      if (apiDisplayName.isEmpty) {
        throw const FormatException('QLDT_API_NAME_MISSING');
      }
      final session = _nativeSession;
      if (session != null) {
        await _rememberProfileName(session, apiDisplayName);
      } else {
        _resolvedDisplayName = _cleanProfileName(apiDisplayName);
      }
      final schedule = _pendingSchedule!;
      verificationStage = 'schedule_verify';
      final verified = const SemesterScheduleVerifier().verify(
        registration: registration,
        schedule: schedule,
      );
      verificationStage = 'semester_build';
      final displayName = _resolvedDisplayName;
      if (displayName.isEmpty) {
        throw const FormatException('QLDT_API_NAME_MISSING');
      }

      final semester = const SemesterDataBuilder().build(
        registration: registration,
        studySchedules: verified.studySchedules,
        examSchedules: verified.examSchedules,
        displayName: displayName,
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
      if (_submittedUsername != null && _submittedPassword != null) {
        try {
          await _credentialChannel.invokeMethod<void>('save', <String, String>{
            'username': _submittedUsername!,
            'password': _submittedPassword!,
          });
        } on Object {
          // A credential-store failure must not discard a verified schedule.
        }
      }
      _submittedPassword = null;
      if (!mounted || !_syncing || epoch != _syncEpoch) return;
      _phaseTimer?.cancel();
      _syncWatchdog?.cancel();
      _diagnostics?.finish('OK');
      if (_diagnostics case final diagnostics?) {
        try {
          await diagnostics.flushed.timeout(const Duration(seconds: 2));
        } on Object {
          // Diagnostic persistence cannot block a verified schedule.
        }
      }
      if (!mounted || !_syncing || epoch != _syncEpoch) return;
      await _ensureAccountDisplayName(displayName);
      if (!mounted || !_syncing || epoch != _syncEpoch) return;
      Navigator.of(context).pop(
        QldtLoginResult(
          schedule: semester.toImportedScheduleData(),
          semester: semester,
          registrationRoute: const TracuuApi().routeForVerifiedResult(raw),
          termStartedAt: SemesterScheduleRange.fromRegistration(registration)
              ?.start,
        ),
      );
    } on Object catch (error) {
      final currentSchedule = _pendingSchedule;
      if (qldtDiagnosticsEnabled &&
          registration != null &&
          currentSchedule != null) {
        try {
          final snapshot = jsonDecode(
            const VerificationDiagnostics().capture(
              registration: registration,
              schedule: currentSchedule,
            ),
          ) as Map<String, dynamic>;
          snapshot['stage'] = verificationStage;
          snapshot['errorCategory'] = _verificationErrorCategory(error);
          snapshot['errorSubtype'] = _verificationErrorSubtype(error);
          _failureDiagnosticsJson = jsonEncode(snapshot);
        } on Object {
          _failureDiagnosticsJson = null;
        }
      }
      if (qldtDiagnosticsEnabled && _failureDiagnosticsJson == null) {
        final report = <String, Object?>{
          'version': 1,
          'kind': 'verification',
          'stage': verificationStage,
          'errorCategory': _verificationErrorCategory(error),
          'errorSubtype': _verificationErrorSubtype(error),
        };
        if (verificationStage == 'registration_parse') {
          try {
            report['registrationScope'] = jsonDecode(
              const VerificationDiagnostics().captureRegistrationScope(raw),
            );
          } on Object {
            report['registrationScope'] = 'unavailable';
          }
        }
        _failureDiagnosticsJson = jsonEncode(report);
      }
      _stopSync(epoch, _verificationErrorMessage(error));
    }
  }

  Future<void> _ensureAccountDisplayName(String fullName) async {
    final existing = await readQldtAccountDisplayName();
    if (existing.isNotEmpty) return;

    final words = fullName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      throw const FormatException('QLDT_API_NAME_MISSING');
    }
    if (!mounted) return;

    final arranged = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => _QldtNameArrangeScreen(words: words),
      ),
    );
    if (arranged == null || arranged.trim().isEmpty) {
      throw const FormatException('ACCOUNT_DISPLAY_NAME_REQUIRED');
    }
    await _saveQldtAccountDisplayName(arranged);
  }

  String _verificationErrorCategory(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('lớp')) return 'class';
    if (message.contains('kế hoạch')) return 'plan';
    if (message.contains('học kỳ')) return 'semester';
    if (message.contains('môn')) return 'subject';
    return 'other';
  }

  String _verificationErrorSubtype(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('lớp khác học kỳ hoặc kế hoạch')) {
      return 'registration_scope_mismatch';
    }
    if (message.contains('môn hoặc lớp thiếu trường')) {
      return 'registration_required_field';
    }
    if (message.contains('id lớp với dữ liệu khác nhau')) {
      return 'registration_class_conflict';
    }
    if (message.contains('không xác minh được lớp của lịch')) {
      return 'schedule_class_mismatch';
    }
    if (message.contains('buổi học ngoài khoảng ngày lớp')) {
      return 'study_outside_class_dates';
    }
    return 'other';
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

  Future<void> _checkReady() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final raw = await controller.evaluateJavascript(
        source: r'''
          (function () {
            try {
              var s = window.edu && edu.system;
              if (!s || !s.userId || s.iM == null || !s.tokenJWT ||
                  !s.appId || !s.strChucNang_Id) {
                return null;
              }
              return JSON.stringify({
                tokenJWT: String(s.tokenJWT),
                userId: String(s.userId),
                iM: String(s.iM),
                appId: String(s.appId),
                strChucNangId: String(s.strChucNang_Id),
                cookie: String(document.cookie || ''),
                name: ''
              });
            } catch (_) {
              return null;
            }
          })();
        ''',
      );

      QldtNativeSession? session;
      final text = raw?.toString();
      if (text != null && text.isNotEmpty && text != 'null') {
        final candidate = QldtNativeSession.fromJson(
          jsonDecode(text) as Map<String, dynamic>,
        );
        if (candidate.isValid) session = candidate;
      }

      if (!mounted || (_autoSyncStarted && !_syncing)) return;

      final ready = session != null;
      if (session != null) {
        _nativeSession = session;
        final cachedName = await _cachedProfileNameFor(session.userId);
        if (cachedName.isNotEmpty) {
          _resolvedDisplayName = cachedName;
        }
      }

      setState(() {
        _pageReady = ready;
        _status = ready
            ? 'Đã xác nhận phiên QLĐT. Đang đồng bộ...'
            : 'Đang lấy session QLĐT sau đăng nhập...';
      });

      if (ready && !_autoSyncStarted && !_syncing) {
        _readinessTimer?.cancel();
        _sessionTimer?.cancel();
        _diagnostics?.finish('OK');
        _autoSyncStarted = true;
        await _cacheNativeSession(session!);
        unawaited(_rememberPortal(controller));
        await _sync();
      } else if (!ready) {
        _scheduleReadinessRetry();
      }
    } on Object {
      if (!mounted) return;
      setState(() => _pageReady = false);
      _scheduleReadinessRetry();
    }
  }

  void _scheduleReadinessRetry() {
    _readinessAttempt += 1;
    if (_readinessAttempt >= 60) {
      if (mounted) {
        _sessionTimer?.cancel();
        _diagnostics?.finish('SESSION_TIMEOUT');
        setState(() {
          _showWebPage = true;
          _autoSyncStarted = false;
          _status = 'Phiên QLĐT chưa sẵn sàng hoặc đã hết hạn. Hãy đăng nhập lại nếu cần.';
        });
      }
      return;
    }
    _readinessTimer?.cancel();
    _readinessTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        unawaited(_checkReady());
      }
    });
  }

  Future<void> _sync() async {
    final controller = _controller;
    if (controller == null || _syncing) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _syncing) return;
    final mode = prefs.getString(_syncModeKey) ?? _legacyMode;

    final epoch = ++_syncEpoch;
    _currentPhase = null;
    _syncWatchdog?.cancel();
    _phaseTimer?.cancel();
    _legacyFallbackTimer?.cancel();
    _switchingToNative = false;
    _usingNativeTransport = mode == _nativeMode;

    setState(() {
      _syncing = true;
      _showWebPage = false;
      _status = _usingNativeTransport
          ? 'Đang đồng bộ bằng native HTTP...'
          : 'Đang đồng bộ bằng luồng QLĐT chính...';
    });
    _pendingSchedule = null;
    _pendingRegistrationRaw = null;
    _failureDiagnosticsJson = null;
    _scheduleStages.clear();

    if (_usingNativeTransport) {
      try {
        await _syncNative(epoch);
      } on Object catch (error) {
        if (!mounted || !_syncing || epoch != _syncEpoch) return;
        _stopSync(
          epoch,
          'Native HTTP lỗi: ${error.runtimeType}: $error',
          code: 'NATIVE_SYNC_FAILED',
        );
      }
      return;
    }

    _startPhase(QldtSyncPhase.semesterPlan, const Duration(seconds: 20), epoch);
    _legacyFallbackTimer = Timer(const Duration(seconds: 5), () {
      if (mounted &&
          _syncing &&
          !_usingNativeTransport &&
          epoch == _syncEpoch) {
        unawaited(_switchToNative('LEGACY_5S_TIMEOUT'));
      }
    });
    await _syncLegacyDispatch(controller, epoch);
  }

  bool _shouldFallbackFromLegacy(String code) {
    return <String>{
      'NETWORK_ERROR',
      'REQUEST_ERROR',
      'SESSION_EXPIRED',
      'HTTP_ERROR',
      'RENDERER_GONE',
      'LEGACY_DISPATCH_ERROR',
      'LEGACY_SCHEDULE_DISPATCH_ERROR',
    }.contains(code);
  }

  Future<void> _switchToNative(String reason) async {
    if (!mounted || !_syncing || _usingNativeTransport || _switchingToNative) {
      return;
    }
    _switchingToNative = true;
    _legacyFallbackTimer?.cancel();
    _syncWatchdog?.cancel();
    _phaseTimer?.cancel();

    final nativeEpoch = ++_syncEpoch;
    _usingNativeTransport = true;
    _currentPhase = null;
    _pendingSchedule = null;
    _pendingRegistrationRaw = null;
    _scheduleStages.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_syncModeKey, _nativeMode);
    } on Object {
      // The current fallback can still run even if mode persistence fails.
    }

    if (!mounted || !_syncing || nativeEpoch != _syncEpoch) return;
    setState(() {
      _status = 'Luồng chính lỗi ($reason). Đang chuyển sang native HTTP...';
    });

    try {
      await _syncNative(nativeEpoch);
    } on Object catch (error) {
      if (!mounted || !_syncing || nativeEpoch != _syncEpoch) return;
      _stopSync(
        nativeEpoch,
        'Native HTTP lỗi: ${error.runtimeType}: $error',
        code: 'NATIVE_SYNC_FAILED',
      );
    } finally {
      _switchingToNative = false;
    }
  }

  Future<void> _syncNative(int epoch) async {
    final session = _nativeSession;
    if (session == null || !session.isValid) {
      throw const FormatException('NATIVE_SESSION_UNAVAILABLE');
    }

    final transport = const QldtNativeTransport();
    final registration = await transport.fetchRegistration(session);
    if (!mounted || !_syncing || epoch != _syncEpoch) return;

    _startPhase(QldtSyncPhase.subjects, const Duration(seconds: 20), epoch);
    final parsedRegistration = const TracuuApi().parse(registration.raw);
    final range = SemesterScheduleRange.fromRegistration(parsedRegistration);
    if (range == null) {
      throw const FormatException('NO_SUBJECTS');
    }
    if (DateTime.now().isAfter(range.end.add(const Duration(days: 1)))) {
      throw const FormatException('SEMESTER_EXPIRED');
    }

    _startPhase(QldtSyncPhase.schedule, const Duration(seconds: 45), epoch);
    if (mounted) {
      setState(() => _status = 'Đang lấy lịch cá nhân bằng native HTTP...');
    }

    final scheduleRaw = await transport.fetchScheduleEnvelope(
      session: session,
      start: range.start,
      end: range.end,
    );
    if (!mounted || !_syncing || epoch != _syncEpoch) return;

    _pendingSchedule = const QldtParser().parseLiveEnvelope(
      scheduleRaw,
      strict: true,
    );
    await _completeRegistration(epoch, registration.raw);
  }

  Future<void> _syncLegacyDispatch(
    InAppWebViewController controller,
    int epoch,
  ) async {
    try {
      final dispatch = await controller.evaluateJavascript(
        source: const TracuuApi().scriptForAttempt(epoch),
      );
      if (!mounted || !_syncing || epoch != _syncEpoch) return;
      if (dispatch == 'BRIDGE_MISSING') {
        _syncWatchdog?.cancel();
        _phaseTimer?.cancel();
        setState(() {
          _syncing = false;
          _autoSyncStarted = false;
          _pageReady = false;
          _status = 'Đang đợi trang QLĐT sẵn sàng để đồng bộ...';
        });
        _beginReadinessChecks();
      }
    } on Object {
      _stopSync(
        epoch,
        'Không thể yêu cầu môn đăng ký từ QLĐT. Hãy thử lại.',
        code: 'LEGACY_DISPATCH_ERROR',
      );
    }
  }

  Future<void> _requestScheduleForRegistration(int epoch, String raw) async {
    final controller = _controller;
    if (controller == null || !mounted || !_syncing || epoch != _syncEpoch) {
      return;
    }
    try {
      final registration = const TracuuApi().parse(raw);
      final range = SemesterScheduleRange.fromRegistration(registration);
      if (range == null) {
        _stopSync(
          epoch,
          'Học kỳ mới chưa có môn đăng ký. Dữ liệu cũ được giữ nguyên.',
          code: 'NO_SUBJECTS',
        );
        return;
      }
      if (DateTime.now().isAfter(range.end.add(const Duration(days: 1)))) {
        _stopSync(
          epoch,
          'Học kỳ mới nhất đã hết thời gian lưu trữ.',
          code: 'SEMESTER_EXPIRED',
        );
        return;
      }
      await _requestSchedule(controller, epoch, range);
    } on Object {
      _stopSync(epoch, 'Không xác định được khoảng học kỳ từ TraCuu.');
    }
  }

  Future<void> _requestSchedule(
    InAppWebViewController controller,
    int epoch,
    SemesterScheduleRange range,
  ) async {
    if (!mounted || !_syncing || epoch != _syncEpoch) return;
    _startPhase(QldtSyncPhase.schedule, const Duration(seconds: 45), epoch);
    setState(() => _status = 'Đang lấy lịch cá nhân trong học kỳ...');
    _scheduleStages
      ..clear()
      ..add('dispatch');
    final startText = _formatDate(range.start);
    final endText = _formatDate(range.end);
    final script =
        '''
      (function () {
        function scheduleStage(value) {
          try {
            window.flutter_inappwebview.callHandler(
              'betterPhenikaaScheduleStage', $epoch, value
            );
          } catch (_) {}
        }
        try {
          if (!(window.flutter_inappwebview &&
                typeof window.flutter_inappwebview.callHandler === 'function')) {
            return 'bridge_unavailable';
          }
          if (!(window.edu && edu.system && edu.system.userId &&
                edu.system.iM != null && typeof edu.system.makeRequest === 'function')) {
            return 'portal_unavailable';
          }

          var requestData = {
            action: 'SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv',
            func: 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan',
            iM: edu.system.iM,
            strQLSV_NguoiHoc_Id: edu.system.userId,
            strNgayBatDau: '$startText',
            strNgayKetThuc: '$endText'
          };

          scheduleStage('request');
          edu.system.makeRequest({
            success: function (response) {
              scheduleStage('success');
              window.flutter_inappwebview.callHandler(
                'betterPhenikaaSyncResult',
                $epoch,
                JSON.stringify({name: '', response: response})
              );            },
            error: function () {
              scheduleStage('error');
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
          return 'request_dispatched';
        } catch (error) {
          scheduleStage('exception');
          window.flutter_inappwebview.callHandler(
            'betterPhenikaaSyncError',
            $epoch,
            'Không thực hiện được yêu cầu lịch QLĐT.'
          );
          return 'request_exception';
        }
      })();
    ''';

    try {
      final dispatch = await controller.evaluateJavascript(source: script);
      if (!mounted || !_syncing || epoch != _syncEpoch) return;
      if (dispatch == 'bridge_unavailable' ||
          dispatch == 'portal_unavailable') {
        _syncWatchdog?.cancel();
        _phaseTimer?.cancel();
        setState(() {
          _syncing = false;
          _autoSyncStarted = false;
          _pageReady = false;
          _status = 'Đang đợi trang QLĐT sẵn sàng để đồng bộ...';
        });
        _beginReadinessChecks();
      } else if (dispatch == 'request_dispatched' &&
          !_scheduleStages.contains('request')) {
        _scheduleStages.add('request');
      }
    } on Object {
      _stopSync(
        epoch,
        'Không thể yêu cầu lịch QLĐT. Hãy thử lại.',
        code: 'LEGACY_SCHEDULE_DISPATCH_ERROR',
      );
    }
  }

  void _startPhase(QldtSyncPhase phase, Duration limit, int epoch) {
    if (_currentPhase != null && phase.index <= _currentPhase!.index) return;
    _currentPhase = phase;
    _phaseTimer?.cancel();
    _diagnostics?.start(phase);
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
    if (!_usingNativeTransport && _shouldFallbackFromLegacy(code)) {
      unawaited(_switchToNative(code));
      return;
    }
    _legacyFallbackTimer?.cancel();
    _syncWatchdog?.cancel();
    _phaseTimer?.cancel();
    _diagnostics?.finish(code);
    if (qldtDiagnosticsEnabled) {
      _failureDiagnosticsJson ??= jsonEncode(<String, Object?>{
        'version': 1,
        'kind': 'sync_stage',
        'failureCode': RegExp(r'^[A-Z_]{1,40}$').hasMatch(code)
            ? code
            : 'FAILED',
        'phase': _currentPhase?.name,
        'scheduleStages': _scheduleStages,
        'pageReady': _pageReady,
      });
    }
    _pendingSchedule = null;
    _pendingRegistrationRaw = null;
    setState(() {
      _syncing = false;
      _status = code.endsWith('_TIMEOUT')
          ? AssistantText.of(AssistantEvent.syncTimeout, _assistantPack)
          : code == 'FAILED'
          ? AssistantText.of(AssistantEvent.syncFailed, _assistantPack)
          : status;
    });
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }
}


final class _QldtNameToken {
  const _QldtNameToken({required this.id, required this.text});

  final int id;
  final String text;
}

class _QldtNameArrangeScreen extends StatefulWidget {
  const _QldtNameArrangeScreen({required this.words});

  final List<String> words;

  @override
  State<_QldtNameArrangeScreen> createState() => _QldtNameArrangeScreenState();
}

class _QldtNameArrangeScreenState extends State<_QldtNameArrangeScreen> {
  static const _blue = Color(0xFF1747B5);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFD9E2F1);
  static const _surface = Color(0xFFF7F9FD);

  late final List<_QldtNameToken> _tokens = <_QldtNameToken>[
    for (var i = 0; i < widget.words.length; i++)
      _QldtNameToken(id: i, text: widget.words[i]),
  ];
  late final List<int> _availableOrder =
      _tokens.reversed.map((token) => token.id).toList(growable: false);
  final List<int> _selected = <int>[];

  _QldtNameToken _token(int id) =>
      _tokens.firstWhere((token) => token.id == id);

  void _select(int id) {
    if (_selected.contains(id)) return;
    setState(() => _selected.add(id));
  }

  void _unselect(int id) {
    setState(() => _selected.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final complete = _selected.length == _tokens.length;
    final chosenName = _selected.map((id) => _token(id).text).join(' ');
    final available = _availableOrder.where((id) => !_selected.contains(id));

    final fixedTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _blue,
        brightness: Brightness.light,
      ),
    );

    return Theme(
      data: fixedTheme,
      child: PopScope<String>(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Xin Chào!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chúng tôi có thể gọi bạn là:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nhấp để sắp xếp tên của bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 96),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _border),
                      ),
                      alignment: _selected.isEmpty
                          ? Alignment.center
                          : Alignment.topLeft,
                      child: _selected.isEmpty
                          ? const Text(
                              'Tên của bạn',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: <Widget>[
                                for (final id in _selected)
                                  _AnimatedNameChip(
                                    key: ValueKey<String>('selected-$id'),
                                    label: _token(id).text,
                                    selectedArea: true,
                                    onTap: () => _unselect(id),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        for (final id in available)
                          _AnimatedNameChip(
                            key: ValueKey<String>('available-$id'),
                            label: _token(id).text,
                            selectedArea: false,
                            onTap: () => _select(id),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: complete ? _blue : const Color(0xFFDCE2EA),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: complete
                              ? () => Navigator.of(context).pop(chosenName)
                              : null,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 40,
                            color: complete
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedNameChip extends StatelessWidget {
  const _AnimatedNameChip({
    super.key,
    required this.label,
    required this.selectedArea,
    required this.onTap,
  });

  final String label;
  final bool selectedArea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: selectedArea ? 22 : -22,
        end: 0,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) => Transform.translate(
        offset: Offset(0, offset),
        child: child,
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: Color(0xFFD9E2F1)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
