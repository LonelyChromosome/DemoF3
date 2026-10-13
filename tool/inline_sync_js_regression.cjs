'use strict';
// Execute the exact JS transported by HeadlessQldtSync without a live account.
// These prove that one silent cached registration request and one silent
// 7-day schedule chunk cannot indefinitely block the native result callback.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');

const src = fs.readFileSync(
  'android/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/QldtDailySyncWorker.kt',
  'utf8'
);
const pattern = /const val INLINE_REGISTRATION_SCRIPT = """([\s\S]*?)"""/;
const registration = src.match(pattern)?.[1];
assert(registration, 'Kotlin registration script missing');
const scheduleSection = src.slice(src.indexOf('private fun requestSchedule('));
const schedule = scheduleSection.match(/val script = if \(inlinePull\) """([\s\S]*?)"""\.trimIndent\(\) else/)?.[1];
assert(schedule, 'Kotlin weekly-chunk script missing');

function fakeClock() {
  let now = 0;
  let index = 1;
  let events = [];
  return {
    setTimeout(cb, delay) {
      const event = {id: index++, at: now + delay, cb, cancelled: false};
      events.push(event);
      return event.id;
    },
    clearTimeout(id) {
      const event = events.find(e => e.id === id);
      if (event) event.cancelled = true;
    },
    advance(delta) {
      const target = now + delta;
      for (let loops = 0; loops < 10000; loops++) {
        const next = events
          .filter(e => !e.cancelled && e.at <= target)
          .sort((a, b) => a.at - b.at)[0];
        if (!next) break;
        now = next.at;
        next.cancelled = true;
        next.cb();
      }
      now = target;
    },
  };
}
function runRegistration(cachedSilent) {
  const clock = fakeClock();
  const output = [];
  const errors = [];
  let rowsRequests = 0;
  const latest = '2026_2027_1';
  const semesterId = 'semester-1';
  const planId = 'plan-1';
  const route = {
    userId: 'u', semesterId, semesterName: latest, planId
  };
  const validRow = {
    DANGKY_KEHOACHDANGKY_ID: planId,
    DAOTAO_THOIGIANDAOTAO_ID: semesterId,
    DAOTAO_HOCPHAN_ID: 'course-1',
    DAOTAO_HOCPHAN_TEN: 'Thiết kế web nâng cao',
    DANGKY_LOPHOCPHAN_ID: 'class-1',
    DANGKY_LOPHOCPHAN_TEN: 'Web-N01.TH1',
    NGAYBATDAU: '01/09/2026',
    NGAYKETTHUC: '31/12/2026'
  };
  const system = {
    userId: 'u', iM: 'ok',
    makeRequest(req) {
      const f = req.data.func;
      if (f === 'pkg_dangkyhoc_chung.LayKetQuaDangKyLopHocPhan') {
        rowsRequests++;
        if (cachedSilent && rowsRequests === 1) return; // never returns
        req.success({Success: true, Data: [validRow]});
      } else if (f === 'pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan') {
        req.success({Success: true, Data: [{THOIGIAN: latest, ID: semesterId}]});
      } else if (f === 'pkg_dangkyhoc_thongtin.LayDSKeHoachDangKyCaNhan') {
        req.success({Success: true, Data: [{
          ID: planId, MAKEHOACH: latest, DAOTAO_THOIGIANDAOTAO_ID: semesterId
        }]});
      } else {
        throw new Error('Unexpected QLĐT registration function: ' + f);
      }
    }
  };
  const bridge = {
    onError: msg => errors.push(msg),
    onRegistration: json => output.push(JSON.parse(json))
  };
  const script = registration
    .replaceAll('__ROUTE__', JSON.stringify(route))
    .split('$' + "{'$'}").join('$');
  vm.runInNewContext(script, {
    window: {BetterPhenikaaNative: bridge, edu: {system}},
    edu: {system},
    setTimeout: clock.setTimeout.bind(clock),
    clearTimeout: clock.clearTimeout.bind(clock)
  }, {timeout: 3000});
  if (cachedSilent) {
    assert.strictEqual(output.length, 0, 'Must wait briefly for cached lookup');
    clock.advance(1850);
    assert.strictEqual(rowsRequests, 2, 'Must make verified direct fallback');
  }
  assert.strictEqual(output.length, 1, 'Verified registration emitted once');
  assert.strictEqual(output[0].subjects.length, 1, 'Enrolled class preserved');
  assert.strictEqual(errors.length, 0, 'No spurious registration errors');
  clock.advance(16000);
  assert.strictEqual(output.length, 1, 'Late watchdog must not re-emit result');
}
runRegistration(false);
runRegistration(true);

function runSchedule(silentFirst) {
  const clock = fakeClock();
  const result = [];
  const errors = [];
  const phases = [];
  const calls = {};
  const chunks = [
    {start: '01/09/2026', end: '07/09/2026'},
    {start: '08/09/2026', end: '14/09/2026'}
  ];
  const system = {
    userId: 'u', iM: 'ok',
    makeRequest(req) {
      const chunk = req.data.strNgayBatDau;
      calls[chunk] = (calls[chunk] || 0) + 1;
      if (silentFirst && chunk === chunks[0].start && calls[chunk] === 1) {
        return; // lost callback, no success and no error
      }
      req.success({
        Success: true,
        Data: [{NGAYHOC: chunk, TENHOCPHAN: 'Thiết kế web nâng cao'}]
      });
    }
  };
  const bridge = {
    onError: e => errors.push(e),
    onSchedule: text => result.push(JSON.parse(text)),
    onAuthStep: phase => phases.push(phase)
  };
  const script = schedule
    .replaceAll('$JAVASCRIPT_BRIDGE', 'BetterPhenikaaNative')
    .replaceAll('$chunks', JSON.stringify(chunks));
  vm.runInNewContext(script, {
    window: {BetterPhenikaaNative: bridge, edu: {system}},
    edu: {system},
    document: {querySelector: () => ({textContent: 'Sinh viên'})},
    setTimeout: clock.setTimeout.bind(clock),
    clearTimeout: clock.clearTimeout.bind(clock)
  }, {timeout: 3000});
  if (silentFirst) {
    assert.strictEqual(result.length, 0, 'Cannot commit partial schedule');
    clock.advance(10050);
    assert.strictEqual(calls[chunks[0].start], 2, 'Retry silent chunk exactly once');
  }
  assert.strictEqual(result.length, 1, 'Exactly one complete schedule result');
  assert.strictEqual(result[0].response.Data.length, 2, 'No missing chunk');
  assert.strictEqual(errors.length, 0, 'Successful retry must not report error');
  assert(phases.includes('SCHEDULE_2_OF_2'), 'Chunk progress diagnostic missing');
}
runSchedule(false);
runSchedule(true);
console.log('PASS: cached-route no-callback fallback, chunk retry, exact-once complete results');
