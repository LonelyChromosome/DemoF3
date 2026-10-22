import hashlib,json
from pathlib import Path
r=Path(__file__).resolve().parents[1]
for x in json.loads((r/'docs/kda/assets.json').read_text()):
 p=r/x['path'];assert p.stat().st_size==x['bytes'];assert hashlib.sha256(p.read_bytes()).hexdigest()==x['sha256'];print('OK',x['path'])
