"""Verify the display cache and all recorded source hashes, without rewriting art."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = ROOT / 'modules/restaurant/assets/prepared_food_manifest.json'
data = json.loads(manifest.read_text(encoding='utf-8'))
errors = []
for name, expected in data['inputs'].items():
    path = ROOT / name.removeprefix('res://')
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        errors.append('source changed: ' + name)
for name, entry in data['foods'].items():
    path = ROOT / entry['path'].removeprefix('res://')
    if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
        errors.append('display changed: ' + name)
print(json.dumps({'status': 'FAIL' if errors else 'PASS', 'textures': len(data['foods']), 'errors': errors}))
raise SystemExit(bool(errors))
