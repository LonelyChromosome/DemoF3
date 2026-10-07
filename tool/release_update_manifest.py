"""Write the exact UTF-8 bytes subsequently signed with the separate Ed25519 key."""
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

apk = Path(sys.argv[1])
url = sys.argv[2]
destination = Path(sys.argv[3])
data = {
    "schema": 1,
    "packageName": "vn.edu.phenikaa.better_phenikaa_schedule",
    "versionCode": 29,
    "versionName": "cooc.1.2",
    "minimumVersionCode": 28,
    "apkUrl": url,
    "apkSha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    "apkSize": apk.stat().st_size,
    "publishedAt": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "notes": "Cập nhật Better Phenikaa cooc.1.2.",
}
destination.write_bytes((json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8"))
