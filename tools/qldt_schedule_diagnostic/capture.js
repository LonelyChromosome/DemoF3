(() => {
  if (window.__demoF3ScheduleDiagnostic) return;

  const targetFunc = 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan';
  const targetAction = 'SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv';
  const events = [];
  const now = () => Math.round(performance.now());

  function summary(value, depth = 0) {
    if (depth > 4) return { type: 'depth-limit' };
    if (value == null) return { type: String(value) };
    if (typeof value === 'string') {
      // The portal can return JSON or an encoded payload. Never export its text.
      try {
        const parsed = JSON.parse(value);
        return { type: 'json-string', length: value.length, value: summary(parsed, depth + 1) };
      } catch (_) {
        return { type: 'string', length: value.length };
      }
    }
    if (Array.isArray(value)) return { type: 'array', count: value.length };
    if (typeof value !== 'object') return { type: typeof value, value: typeof value === 'boolean' ? value : undefined };
    const result = {
      type: 'object',
      keys: Object.keys(value).slice(0, 40),
    };
    for (const key of ['Success', 'success', 'IsSuccess']) {
      if (typeof value[key] === 'boolean') result.success = value[key];
    }
    for (const key of ['Data', 'data', 'B']) {
      if (key in value) result[key] = summary(value[key], depth + 1);
    }
    return result;
  }

  function add(event) {
    if (events.length >= 50) events.shift();
    events.push(event);
  }

  function install() {
    const system = window.edu?.system;
    if (typeof system?.makeRequest !== 'function') return;
    const original = system.makeRequest;
    if (original.__demoF3ScheduleWrapped) return;
    function wrapped(options, ...args) {
      if (options?.data?.func !== targetFunc) {
        return original.apply(this, [options, ...args]);
      }
      const started = now();
      const event = { phase: 'pending', elapsedMs: 0 };
      add(event);
      const success = options.success;
      const error = options.error;
      const wrappedOptions = {
        ...options,
        success: function (...values) {
          event.phase = 'success';
          event.elapsedMs = now() - started;
          event.response = summary(values[0]);
          return typeof success === 'function' ? success.apply(this, values) : undefined;
        },
        error: function (...values) {
          event.phase = 'error';
          event.elapsedMs = now() - started;
          event.errorArgTypes = values.slice(0, 4).map(value => typeof value);
          return typeof error === 'function' ? error.apply(this, values) : undefined;
        },
      };
      try {
        return original.apply(this, [wrappedOptions, ...args]);
      } catch (_) {
        event.phase = 'thrown';
        event.elapsedMs = now() - started;
        throw _;
      }
    }
    Object.defineProperty(wrapped, '__demoF3ScheduleWrapped', { value: true });
    system.makeRequest = wrapped;
  }

  async function probe() {
    install();
    const system = window.edu?.system;
    if (!system?.userId || system.iM == null || typeof system.makeRequest !== 'function') {
      return { phase: 'not_ready' };
    }
    const date = new Date();
    const startYear = date.getMonth() >= 7 ? date.getFullYear() : date.getFullYear() - 1;
    const format = (day, month, year) =>
      `${String(day).padStart(2, '0')}/${String(month).padStart(2, '0')}/${year}`;
    const started = now();
    let completed = false;
    return new Promise(resolve => {
      const finish = (phase, extra = {}) => {
        if (completed) return;
        completed = true;
        clearTimeout(timer);
        resolve({ phase, elapsedMs: now() - started, ...extra });
      };
      const timer = setTimeout(() => finish('timeout'), 25000);
      const data = {
        action: targetAction,
        func: targetFunc,
        iM: system.iM,
        strQLSV_NguoiHoc_Id: system.userId,
        strNgayBatDau: format(1, 8, startYear),
        strNgayKetThuc: format(31, 7, startYear + 1),
      };
      try {
        system.makeRequest({
          success: response => finish('success', { response: summary(response) }),
          error: (...values) => finish('error', {
            errorArgTypes: values.slice(0, 4).map(value => typeof value),
          }),
          type: 'POST',
          action: data.action,
          contentType: true,
          data,
          fakedb: [],
        }, false, false, false, null);
      } catch (_) {
        finish('thrown');
      }
    });
  }

  function snapshot() {
    return {
      portalReady: !!(window.edu?.system?.userId &&
        window.edu.system.iM != null &&
        typeof window.edu.system.makeRequest === 'function'),
      hookReady: !!window.edu?.system?.makeRequest?.__demoF3ScheduleWrapped,
      scheduleCalls: events.map(event => ({ ...event })),
    };
  }

  Object.defineProperty(window, '__demoF3ScheduleDiagnostic', {
    value: { probe, snapshot },
    configurable: false,
  });
  install();
  setInterval(install, 100);
})();
