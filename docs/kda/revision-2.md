# K/DA FIRESTARTER — test 1.8.2

Changes requested after phone testing:

- Last hidden/shown card choice is persisted across app restarts and theme changes; only first use defaults to hidden. Restored cards wait for the first video frame.
- Spectrum has a single baseline at its bottom; all frequency bars extend upwards.
- Theme Settings shows a `Tùy chỉnh theme` button immediately below the custom theme creation button while KDA is selected. The compact control sheet removes technical/descriptive subtitles.
- First entry requests Android RECORD_AUDIO and enables music automatically. A persisted first-entry marker prevents repeat prompts and subsequent music choices are respected. This also initializes the first entry after upgrading from the previous test APK. Denying audio permission does not prevent media playback; a concise retry button remains in theme controls.
- KDA theme tile uses the supplied 2048×1152 JPEG unchanged, with caption `KDA, cinematic, Âm nhạc`. The four original widget images and portrait static background are retained.
- Widget 2 uses a full-resolution blurred cover of its selected photo behind the timetable and keeps the matching sharp photo on the right. Reload still changes its image independently and immediately.

Verification includes first-entry denial and persisted mute unit tests, native bitmap regression checks, and an Android integration flow accepting the actual OS permission dialog without pre-granting it. Emulator evidence records that dialog alongside the actual APK installation/launch and lifecycle checks.

APK uses a separate `.kdatest` package and debug signing, as before. A newly generated CI debug signer may require uninstalling the previous BPA KDA Test before installing this version. Production BPA is a separate package.
