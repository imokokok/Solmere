"""Verify the display cache and all recorded source hashes, without rewriting art."""
import hashlib
import json
from pathlib import Path

def source_digest(path):
    data = path.read_bytes()
    # Git converts authored JSON line endings between Windows and Linux.
    # Normalize only text manifests; every original raster stays byte-exact.
    if path.suffix == '.json':
        data = data.replace(b'\r\n', b'\n')
    return hashlib.sha256(data).hexdigest()


def main():
    root = Path(__file__).resolve().parents[1]
    manifest = root / 'modules/restaurant/assets/prepared_food_manifest.json'
    data = json.loads(manifest.read_text(encoding='utf-8'))
    errors = []
    for name, expected in data['inputs'].items():
        path = root / name.removeprefix('res://')
        if source_digest(path) != expected:
            errors.append('source changed: ' + name)
    for name, entry in data['foods'].items():
        path = root / entry['path'].removeprefix('res://')
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
            errors.append('display changed: ' + name)
    print(json.dumps({'status': 'FAIL' if errors else 'PASS', 'textures': len(data['foods']), 'errors': errors}))
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
