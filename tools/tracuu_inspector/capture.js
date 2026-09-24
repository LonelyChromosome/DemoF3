(() => {
  if (window.__demoF3TraCuuInspector) return;

  const records = [];
  const aliases = new Map();
  const sensitive = /pass(word)?|cookie|auth|token|secret|email|phone|sdt|mssv|ma.?sv|nguoi.?hoc|tai.?khoan|account|user|ho.?ten|full.?name|address|dia.?chi|cmnd|cccd|birth|ngay.?sinh/i;
  const academic = /hoc.?ky|semester|ke.?hoach|plan|nam.?hoc|year/i;
  const subject = /mon.?hoc|hoc.?phan|subject|course/i;
  const section = /lop.?hoc.?phan|section|class/i;
  const date = /ngay|date|start|end|bat.?dau|ket.?thuc/i;
  const safeLiteral = /^(?:\d{4}_\d{4}_\d+|\d{1,2}\/\d{1,2}\/\d{4}|\d{4}-\d{2}-\d{2}|\d{1,2}:\d{2})$/;

  function alias(kind, value) {
    const key = `${kind}:${value}`;
    if (!aliases.has(key)) aliases.set(key, `${kind}_${aliases.size + 1}`);
    return aliases.get(key);
  }

  function clean(value, key = '', depth = 0, seen = new WeakSet()) {
    if (depth > 7) return '<depth-limit>';
    if (value == null || typeof value === 'boolean' || typeof value === 'number') return value;
    if (typeof value === 'string') {
      if (sensitive.test(key)) return '<redacted>';
      if (/^(?:func|action|type)$/i.test(key) && /^[\w./-]{1,180}$/.test(value)) return value;
      if (academic.test(key) && value.length < 100) return value.replace(/[^\w,._\s()-]/g, '');
      if (safeLiteral.test(value)) return value;
      if (section.test(key)) return alias('section', value);
      if (subject.test(key)) return alias('subject', value);
      if (date.test(key)) return `<date:${value.length}>`;
      if (key === 'B' || value.length > 180) return `<opaque:${value.length}>`;
      return `<text:${value.length}>`;
    }
    if (typeof value !== 'object') return `<${typeof value}>`;
    if (seen.has(value)) return '<cycle>';
    seen.add(value);
    if (Array.isArray(value)) {
      const result = value.slice(0, 8).map(item => clean(item, key, depth + 1, seen));
      if (value.length > 8) result.push(`<${value.length - 8} more>`);
      return result;
    }
    const result = {};
    for (const name of Object.keys(value).slice(0, 100)) {
      if (/^(?:headers?|authorization)$/i.test(name)) continue;
      try {
        result[name] = clean(value[name], name, depth + 1, seen);
      } catch (_) {
        result[name] = '<unavailable>';
      }
    }
    return result;
  }

  function record(options, kind, response, started) {
    try {
      if (records.length >= 120) return;
      const data = options.data || {};
      records.push({
        phase: kind,
        elapsedMs: Math.round(performance.now() - started),
        path: location.pathname,
        action: clean(options.action || data.action, 'action'),
        func: clean(data.func, 'func'),
        request: clean(data),
        response: kind === 'success' ? clean(response) : undefined,
      });
    } catch (_) {
      records.push({ phase: 'capture_error' });
    }
  }

  function install() {
    const system = window.edu && window.edu.system;
    if (!system || typeof system.makeRequest !== 'function') return;
    const original = system.makeRequest;
    if (original.__demoF3Wrapped) return;
    function wrapped(options, ...args) {
      if (!options || typeof options !== 'object') return original.apply(this, [options, ...args]);
      const started = performance.now();
      const success = options.success;
      const error = options.error;
      const wrappedOptions = {
        ...options,
        success: function (...values) {
          record(options, 'success', values[0], started);
          return typeof success === 'function' ? success.apply(this, values) : undefined;
        },
        error: function (...values) {
          record(options, 'error', undefined, started);
          return typeof error === 'function' ? error.apply(this, values) : undefined;
        },
      };
      try {
        return original.apply(this, [wrappedOptions, ...args]);
      } catch (failure) {
        record(options, 'thrown', undefined, started);
        throw failure;
      }
    }
    Object.defineProperty(wrapped, '__demoF3Wrapped', { value: true });
    system.makeRequest = wrapped;
  }

  function snapshot() {
    const select = id => {
      const element = document.getElementById(id);
      if (!element) return { found: false };
      return {
        found: true,
        selected: clean(element.value, id),
        options: [...element.options].slice(0, 20).map(option => ({
          value: clean(option.value, id),
          label: clean(option.textContent.trim(), id),
        })),
      };
    };
    return {
      framePath: location.pathname,
      hookReady: !!window.edu?.system?.makeRequest?.__demoF3Wrapped,
      semester: select('dropSearch_HocKy'),
      plan: select('dropSearch_KeHoach'),
      viewFound: !!document.getElementById('btnXemKetQuaDangKy'),
      subjectCount: document.querySelectorAll('#zoneKetQuaDangKy .subject-item').length,
      records: records.slice(),
      scripts: [...document.scripts].map(script => script.src)
        .filter(src => src && new URL(src).origin === location.origin)
        .map(src => new URL(src).pathname).slice(0, 100),
    };
  }

  Object.defineProperty(window, '__demoF3TraCuuInspector', {
    value: { snapshot },
    configurable: false,
  });
  install();
  setInterval(install, 100);
})();
