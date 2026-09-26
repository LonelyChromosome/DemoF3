const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

test('records decoded callback structure and redacts credentials', () => {
  const code = fs.readFileSync(path.join(__dirname, 'capture.js'), 'utf8');
  const system = { makeRequest(options) {
    options.success({ Success: true, Data: [{ TENHOCPHAN: 'Môn mẫu', TENLOPHOCPHAN: 'Lớp mẫu', strNguoiHoc_Id: 'private' }] });
  } };
  const context = {
    window: { edu: { system } },
    location: { pathname: '/congsinhvien/tracuu', origin: 'https://qldtbeta.phenikaa-uni.edu.vn' },
    performance: { now: () => 5 },
    setInterval: () => {},
    document: {
      getElementById: () => null,
      querySelectorAll: () => [],
      scripts: [],
    },
    WeakSet, Map, Object, URL,
  };
  vm.runInNewContext(code, context);
  let called = false;
  system.makeRequest({
    action: 'DKH_Chung_MH/verified',
    data: { func: 'pkg_dangkyhoc.TraCuu', strNguoiHoc_Id: 'secret', strHocKy: '2026_2027_1' },
    success() { called = true; },
  });
  const result = context.window.__demoF3TraCuuInspector.snapshot();
  assert.equal(called, true);
  assert.equal(result.records[0].func, 'pkg_dangkyhoc.TraCuu');
  assert.equal(result.records[0].request.strNguoiHoc_Id, '<redacted>');
  assert.equal(result.records[0].request.strHocKy, '2026_2027_1');
  assert.equal(result.records[0].response.Data[0].TENHOCPHAN, 'subject_1');
  assert.equal(result.records[0].response.Data[0].TENLOPHOCPHAN, 'section_2');
  assert.equal(JSON.stringify(result).includes('private'), false);
  assert.equal(JSON.stringify(result).includes('secret'), false);
});
