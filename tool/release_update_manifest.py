"""Emit canonical, signed-update JSON for any cooc release.

Usage: release_update_manifest.py APK URL OUTPUT VERSION_NAME VERSION_CODE MIN_CODE NOTES
The resulting bytes, including the final newline, are the exact Ed25519 input.
"""
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

if len(sys.argv) != 8:
    raise SystemExit("Expected APK URL OUTPUT VERSION_NAME VERSION_CODE MIN_CODE NOTES")
apk = Path(sys.argv[1])
url, destination = sys.argv[2], Path(sys.argv[3])
name, version_text, minimum_text, notes = sys.argv[4:]
if not re.fullmatch(r"cooc\.\d+\.\d+", name):
    raise SystemExit("Invalid cooc versionName")
version = int(version_text)
minimum = int(minimum_text)
if minimum < 1 or version <= minimum:
    raise SystemExit("versionCode must exceed minimumVersionCode")
if len(notes) > 500:
    raise SystemExit("Release notes too long")
if not url.startswith("https://github.com/LonelyChromosome/DemoF3/releases/download/"):
    raise SystemExit("Untrusted release download URL")
data = {
    "schema": 1,
    "packageName": "vn.edu.phenikaa.better_phenikaa_schedule",
    "versionCode": version,
    "versionName": name,
    "minimumVersionCode": minimum,
    "apkUrl": url,
    "apkSha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    "apkSize": apk.stat().st_size,
    "publishedAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "notes": notes,
}
destination.write_bytes(
    (json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")
)
