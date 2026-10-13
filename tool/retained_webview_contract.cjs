'use strict';
// CI source contract: the pull button must attach the original WebView/login
// and must never start the separate QLDT-native HeadlessQldtSync.
const fs = require('fs');
const assert = require('assert');
const mobile = fs.readFileSync('lib/features/dang_nhap_qldt/qldt_login_mobile.dart','utf8');
const root = fs.readFileSync('lib/app/app.dart','utf8');
const common = fs.readFileSync('lib/features/dang_nhap_qldt/qldt_login.dart','utf8');
const pull = root.slice(root.indexOf('Future<void> _runPullSync('),
  root.indexOf('void _cancelPullSync()'));
assert(pull.includes('openQldtLogin(context, inlinePull: true)'), 'Pull must reuse QLDT login pipeline');
assert(!pull.includes('_inlineSyncChannel'), 'Pull must not call the new native headless WebView');
assert(pull.includes('_save(imported)'), 'Commit fully verified source data');
assert(pull.includes('AttendanceSummary.fromVerifiedSchedule(imported.schedule)'));
assert(pull.includes('practiceCardIdsFromVerifiedSchedule(imported.schedule)'));
assert(mobile.includes('InAppWebViewKeepAlive()'), 'Keep-alive token required');
assert(mobile.includes('final silentPull = inlinePull && hasRetainedQldtLivePortal;'),
  'A cold-start pull must use foreground original QLDT login instead of a hidden dead session');
assert(mobile.includes('inlinePull: silentPull,'),
  'The hidden QLDT UI must only be used for a verified live portal');
assert(mobile.includes('cachedSession: cached || silentPull,'),
  'Cold reauthorization must not falsely claim an authenticated portal');
assert(root.includes('if (hasRetainedQldtLivePortal)'),
  'Recap background sync must not unexpectedly navigate to QLDT after process restart');
assert(mobile.includes('keepAlive: widget.testHtml == null ? _retainedQldtView : null'));
assert(mobile.includes('PageRouteBuilder<QldtLoginResult>'), 'Pull must not cover timetable UI');
assert(mobile.includes("void _abortInlineSync(String reason)"));
assert(mobile.includes('if (inlinePull) _inlineQldtFailure = null;'));
assert(mobile.includes('InAppWebViewController.disposeKeepAlive(retained)'), 'Logout must discard QLDT WebView');
assert(mobile.includes('const TracuuApi().scriptForAttempt(epoch)'));
assert(mobile.includes('(widget.cachedSession && _retainedQldtPortalReady)'),
  'Regular account-sync must reuse cached WebView without waiting for a navigation event');
assert(mobile.includes('(!widget.inlinePull || !_retainedQldtPortalReady)'),
  'A verified pull must not reload the portal URL');
assert(mobile.includes('const SemesterScheduleVerifier().verify('));
assert(common.includes('bool cancelQldtInlineSync()'));
console.log('PASS: retained authenticated QLDT WebView, original parser/verifier, isolated native worker');
