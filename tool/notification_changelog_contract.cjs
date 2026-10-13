'use strict';
// Prevent the in-app Notification Center from regressing to a hard-coded 1.6 log.
const fs = require('fs');
const assert = require('assert');
const app = fs.readFileSync('lib/app/app.dart', 'utf8');
const begin = app.indexOf('class _NotificationCenterScreen extends StatelessWidget');
const end = app.indexOf('class _NotificationExamCard extends StatelessWidget', begin);
assert(begin >= 0 && end > begin);
const screen = app.slice(begin, end);
assert(screen.includes('appVersionName: appVersionName') === false ||
  app.includes('appVersionName: appVersionName,')); // shell passes actual installed version
assert(app.includes('changelog: NotificationChangelog.forInstalledVersion(appVersionName)'));
assert(screen.includes('changelog.versionName'));
assert(screen.includes('for (final line in changelog.entries)'));
assert(!screen.includes("'cooc1.6'"));
assert(!screen.includes("for (final line in const ['Bổ sung VFX'"));
console.log('PASS: Notification Center update log follows installed BPA version');
