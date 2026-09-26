const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function createContext(makeRequest) {
  const code = fs.readFileSync(path.join(__dirname, 'capture.js'), 'utf8');
  const system = { userId: 'private-student-id', iM: 'private-session', makeRequest };
  const context = {
    window: { edu: { system } },
    performance: { now: () => 100 },
    setInterval: () => {},
    setTimeout: () => 1,
    clearTimeout: () => {},
    Date, Promise, Object, JSON, String,
  };
  vm.runInNewContext(code, context);
  return { system, diagnostic: context.window.__demoF3ScheduleDiagnostic };
}

test('probe calls the schedule API and exports metadata without private data', async () => {
  let received;
  const { diagnostic } = createContext(options => {
    received = options;
    options.success({ Success: true, Data: [{
      TENHOCPHAN: 'Môn riêng tư',
      strNguoiHoc_Id: 'private-student-id',
    }] });
  });
  const result = await diagnostic.probe();
  assert.equal(received.data.func, 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan');
  assert.equal(received.data.strQLSV_NguoiHoc_Id, 'private-student-id');
  assert.equal(result.phase, 'success');
  assert.equal(result.response.Data.count, 1);
  const exported = JSON.stringify({ result, snapshot: diagnostic.snapshot() });
  assert.equal(exported.includes('private-student-id'), false);
  assert.equal(exported.includes('private-session'), false);
  assert.equal(exported.includes('Môn riêng tư'), false);
});

test('a request without callback remains pending until the probe timeout', async () => {
  let timeout;
  const code = fs.readFileSync(path.join(__dirname, 'capture.js'), 'utf8');
  const system = { userId: 'secret', iM: 1, makeRequest() {} };
  const context = {
    window: { edu: { system } },
    performance: { now: () => 100 },
    setInterval: () => {},
    setTimeout: fn => { timeout = fn; return 1; },
    clearTimeout: () => {},
    Date, Promise, Object, JSON, String,
  };
  vm.runInNewContext(code, context);
  const diagnostic = context.window.__demoF3ScheduleDiagnostic;
  const pending = diagnostic.probe();
  assert.equal(diagnostic.snapshot().scheduleCalls[0].phase, 'pending');
  timeout();
  assert.equal((await pending).phase, 'timeout');
});
