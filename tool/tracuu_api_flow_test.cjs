const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const dart = fs.readFileSync(path.join(__dirname,
  '../lib/features/dang_nhap_qldt/tracuu_api.dart'), 'utf8');
const script = dart.match(/String get _script => r'''([\s\S]*?)'''/)[1]
  .replaceAll('__ATTEMPT__', '3');
const kotlin = fs.readFileSync(path.join(__dirname,
  '../android/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/QldtDailySyncWorker.kt'), 'utf8');
const nativeScript = kotlin.split('const val REGISTRATION_SCRIPT = """')[1]
  ?.split('"""')[0].replaceAll("${'$'}", '$');
assert.ok(nativeScript, 'native registration script is present');

function run({failAt, noCallback, empty = false, oldPlan = false,
  duplicatePlan = false, extraPlan = false, planName = 'metadata only'} = {}) {
  const calls = [];
  const stages = [];
  const data = {
    LayThoiGianDangKyCaNhan: {Success: true, Data: [
      {ID: 'old', THOIGIAN: '2025_2026_3'},
      {ID: 'new', THOIGIAN: '2026_2027_1'},
    ]},
    LayDSKeHoachDangKyCaNhan: {Success: true, Data: [
      {ID: 'plan', DAOTAO_THOIGIANDAOTAO_ID: oldPlan ? 'old' : 'new',
        MAKEHOACH: planName},
      ...(duplicatePlan ? [{ID: 'plan', DAOTAO_THOIGIANDAOTAO_ID: 'new',
        MAKEHOACH: 'other metadata'}] : []),
      ...(extraPlan ? [{ID: 'other', DAOTAO_THOIGIANDAOTAO_ID: 'new'}] : []),
    ]},
    LayKetQuaDangKyLopHocPhan: {Success: true, Data: empty ? [] : [
      {DANGKY_KEHOACHDANGKY_ID: 'plan', DAOTAO_THOIGIANDAOTAO_ID: 'new',
        DAOTAO_HOCPHAN_ID: 'subject', DAOTAO_HOCPHAN_TEN: 'Thiết kế web nâng cao',
        DANGKY_LOPHOCPHAN_ID: 'class', DANGKY_LOPHOCPHAN_TEN: 'WEB-2026-LT',
        NGAYBATDAU: '17/08/2026', NGAYKETTHUC: '01/11/2026'},
    ]},
  };
  const system = {userId: 'student-private', iM: 1, makeRequest(options) {
    calls.push(options.data);
    const key = options.data.func.split('.').at(-1);
    if (key === failAt) return options.error();
    if (key === noCallback) return;
    options.success(data[key]);
  }};
  const window = {edu: {system}, flutter_inappwebview: {callHandler(name, attempt, value) {
    stages.push({name, attempt, value});
  }}};
  vm.runInNewContext(script, {window, edu: window.edu});
  return {calls, stages};
}

test('reads latest semester, plan and registered classes through verified methods', () => {
  const {calls, stages} = run();
  assert.equal(calls.length, 3);
  assert.equal(calls[0].strDaoTao_ThoiGianDaoTao_Id, null);
  assert.equal(calls[1].strDaoTao_ThoiGianDaoTao_Id, 'new');
  assert.equal(calls[2].strDangKy_KeHoachDangKy_Id, 'plan');
  assert.equal(calls[2].strQLSV_NguoiHoc_Id, 'student-private');
  assert.equal(stages.at(-1).name, 'betterPhenikaaRegistrationResult');
  assert.equal(JSON.parse(stages.at(-1).value).registrations.Data.length, 1);
});

test('deduplicates the same plan ID and fetches registrations once', () => {
  const {calls, stages} = run({duplicatePlan: true});
  assert.equal(calls.length, 3);
  assert.equal(calls[2].strDangKy_KeHoachDangKy_Id, 'plan');
  assert.equal(stages.at(-1).name, 'betterPhenikaaRegistrationResult');
});

test('rejects ambiguous plan, network error and missing callback', () => {
  assert.equal(run({oldPlan: true}).stages.at(-1).value, 'PLAN_AMBIGUOUS');
  assert.equal(run({extraPlan: true}).stages.at(-1).value, 'PLAN_AMBIGUOUS');
  assert.equal(run({failAt: 'LayKetQuaDangKyLopHocPhan'}).stages.at(-1).value,
    'NETWORK_ERROR');
  const hanging = run({noCallback: 'LayDSKeHoachDangKyCaNhan'});
  assert.equal(hanging.stages.some(item => item.name === 'betterPhenikaaRegistrationResult'), false);
  assert.equal(hanging.calls.length, 2);
});

test('a successful empty registration remains distinguishable from missing response', () => {
  const result = run({empty: true}).stages.at(-1);
  assert.equal(result.name, 'betterPhenikaaRegistrationResult');
  assert.deepEqual(JSON.parse(result.value).registrations.Data, []);
});

test('native worker uses the same three verified calls without page navigation', () => {
  new vm.Script(nativeScript);
  for (const func of ['LayThoiGianDangKyCaNhan',
    'LayDSKeHoachDangKyCaNhan', 'LayKetQuaDangKyLopHocPhan']) {
    assert.ok(nativeScript.includes(func));
  }
  assert.equal(nativeScript.includes('querySelector'), false);
  assert.equal(nativeScript.includes('MutationObserver'), false);
  assert.ok(nativeScript.includes('new Set(plans'));
  assert.ok(nativeScript.includes('strDangKy_KeHoachDangKy_Id: planIds[0]'));
});
