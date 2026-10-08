# cooc.1.3 — PRIVATE DEVICE TEST (NOT PUBLISHED)

Base: `feature/1.2-card-update`, keeping the existing signed updater.
Working branch: `feature/1.3-attendance-refresh`.
Version: `cooc.1.3`, `versionCode 33` (higher than 1.1 bootstrap 30
and the 1.2 test APK 32). Package ID unchanged.

## Scope

- Submit attendance code to the captured `CC_ThongTin/Them_QLSV_NguoiHoc_TuGhiNhan`
  endpoint using the logged-in user's own QLDT native session.
- A successful API submission means `Chờ xác thực` (UI text only).
  Only explicit QLDT review information after a manual refresh can show
  `Có mặt` or `Vắng mặt`. Do not poll, infer, or attempt lecturer approval.
- The code can be sent again by explicit user action. This is a NEW request,
  not a guaranteed server-side edit of an existing row.
- Drag down: refresh icon moves and rotates with distance. Reaching the
  threshold starts the same in-app verified semester synchronization using the
  existing session. The icon spins during synchronization and updated content
  fades in. No intermediate screen or WebView is opened for pull-refresh.
- Keep the current date and tab, and retain old data on network/validation error.

## Important limits

The supplied attendance logs capture the submission endpoint but **not**
the discovery endpoint for the per-lesson `strDiem_DanhSach_Id`, nor a
confirmed attendance-review read endpoint. We use an identifier only when
it is present in the verified QLDT schedule row; no captured learner ID,
IP address, or course ID is hard-coded. If QLDT does not provide that
field in the schedule payload, submission safely fails rather than writing
attendance against an unrelated course. A real-device test of that mapping
and of review status is still required.

## Isolation / signing rules

- NO changes to `updates/latest.json`, `updates/latest.json.sig`, GitHub
  Pages, any public update manifest, or any existing release asset.
- No merge to main/newupdate/1.2. No GitHub Release or tag for 1.3.
- `.github/workflows/build-1-3-test.yml` builds a **private Actions artifact
  only**, using the existing `cooc-release` signing environment; it does
  not publish an APK or update metadata.
- The installer can upgrade in place from bootstrap 1.1 to private 1.3
  only when both APKs have the exact same signing certificate. Android
  cannot upgrade the older debug-signed 1.1 to the release-signed 1.3.
- Before giving APK to testers, verify package ID, versionCode 33,
  signer SHA-256, and real-device behavior.

## Device checks

1. Use a 1.1 bootstrap signed with the same fixed cooc-release certificate.
2. Install 1.3 test APK manually. Confirm NFC bind, app data and account UI
   survive, and manual updater does not silently publish 1.3.
3. Open day and week schedules, enter a code, confirm UI remains
   `Chờ xác thực` even if the API reports `Success: true`.
4. Close/reopen app and verify local pending state persists.
5. Pull below threshold: no sync. Pull to threshold: icon spins,
   no new page/WebView, schedule retained while data loads.
6. Verify a real server-reviewed `Có mặt` / `Vắng mặt` changes only
   after manual pull and a QLDT response explicitly containing the result.
7. Failed refresh keeps old data and current date/tab.
