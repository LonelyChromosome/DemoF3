const button = document.getElementById('probe');
const status = document.getElementById('status');

button.addEventListener('click', async () => {
  button.disabled = true;
  status.textContent = 'Đang chờ phản hồi lịch QLĐT (tối đa 25 giây)...';
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id || new URL(tab.url).hostname !== 'qldtbeta.phenikaa-uni.edu.vn') {
      throw Error('Hãy mở tab qldtbeta.phenikaa-uni.edu.vn đã đăng nhập.');
    }
    const snapshots = await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      world: 'MAIN',
      func: () => window.__demoF3ScheduleDiagnostic?.snapshot() || null,
    });
    const frames = snapshots.filter(item => item.result);
    if (!frames.length) throw Error('Extension chưa chạy; hãy tải lại tab QLĐT.');
    const readyFrame = frames.find(item => item.result.portalReady);
    let result = { phase: 'not_ready' };
    if (readyFrame) {
      const [probe] = await chrome.scripting.executeScript({
        target: { tabId: tab.id, frameIds: [readyFrame.frameId] },
        world: 'MAIN',
        func: () => window.__demoF3ScheduleDiagnostic.probe(),
      });
      result = probe.result;
    }
    const captureFrames = await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      world: 'MAIN',
      func: () => window.__demoF3ScheduleDiagnostic?.snapshot() || null,
    });
    const capture = {
      format: 'demoF3-qldt-schedule-diagnostic-v1',
      capturedAt: new Date().toISOString(),
      result,
      frames: captureFrames.map(item => ({
        frameId: item.frameId,
        before: frames.find(frame => frame.frameId === item.frameId)?.result || null,
        after: item.result,
      })),
    };
    const url = URL.createObjectURL(new Blob([JSON.stringify(capture, null, 2)], { type: 'application/json' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = `DemoF3_QLDT_Schedule_Diagnostic_${Date.now()}.json`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    status.textContent = 'Đã tải JSON. Kiểm tra file rồi gửi; file không chứa nội dung môn học hay thông tin đăng nhập.';
  } catch (error) {
    status.textContent = error.message || 'Không kiểm tra được QLĐT.';
  } finally {
    button.disabled = false;
  }
});
