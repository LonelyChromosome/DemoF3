const button = document.getElementById('export');
const status = document.getElementById('status');
const host = 'qldtbeta.phenikaa-uni.edu.vn';

button.addEventListener('click', async () => {
  button.disabled = true;
  status.textContent = 'Đang đọc kết quả trên tab QLĐT...';
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id || new URL(tab.url).hostname !== host) {
      throw Error('Hãy mở tab QLĐT rồi thử lại.');
    }
    const frames = await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      world: 'MAIN',
      func: () => window.__demoF3TraCuuInspector?.snapshot() || null,
    });
    const snapshots = frames.map(frame => frame.result).filter(Boolean);
    if (!snapshots.length) throw Error('Extension chưa chạy; hãy tải lại trang TraCuu.');
    const sources = await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      world: 'MAIN',
      func: async () => {
        const script = [...document.scripts].find(node => {
          if (!node.src) return false;
          const url = new URL(node.src);
          return url.origin === location.origin &&
            /\/modules\/dangkyhoc\/script\/tracuu\.js$/i.test(url.pathname);
        });
        if (!script) return { found: false };
        try {
          const response = await fetch(script.src, { credentials: 'same-origin' });
          if (!response.ok) return { found: true, status: response.status };
          const source = await response.text();
          return {
            found: true,
            status: response.status,
            source: source.length <= 300000 ? source : '<script exceeds 300000 characters>',
          };
        } catch (_) {
          return { found: true, status: 'fetch_failed' };
        }
      },
    });
    const capture = {
      format: 'demoF3-tracuu-decoded-v1',
      capturedAt: new Date().toISOString(),
      frames: snapshots,
      tracuuScript: sources.map(frame => frame.result).find(item => item?.found) || { found: false },
    };
    const content = JSON.stringify(capture, null, 2);
    const url = URL.createObjectURL(new Blob([content], { type: 'application/json' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = `DemoF3_TraCuu_Decoded_${Date.now()}.json`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    const count = snapshots.reduce((total, frame) => total + frame.records.length, 0);
    status.textContent = `Đã tải file: ${count} lời gọi, ${snapshots.length} frame. Kiểm tra file trước khi gửi.`;
  } catch (error) {
    status.textContent = error.message || 'Không đọc được TraCuu.';
  } finally {
    button.disabled = false;
  }
});
