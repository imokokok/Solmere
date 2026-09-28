"""Mirror the independently runnable kitchen into Solmere's resource namespace.

Edit prototypes/100-restaurant/modules/restaurant, then run this script.
--check is read-only and fails on any missing, changed or stale runtime file.
"""
from pathlib import Path
import argparse
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'prototypes/100-restaurant/modules/restaurant'
TARGET = ROOT / 'modules/restaurant'

def files(base):
    return {p.relative_to(base): p for p in base.rglob('*')
            if p.is_file() and not p.name.endswith('.import')}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    source, target = files(SOURCE), files(TARGET)
    changed = [name for name, path in source.items()
               if name not in target or path.read_bytes() != target[name].read_bytes()]
    stale = set(target) - set(source)
    if args.check:
        if changed or stale:
            raise SystemExit(f'Kitchen mirror differs: {len(changed)} changed, {len(stale)} stale')
    else:
        # The destination is a generated mirror under this repository only.
        for name in changed:
            output = TARGET / name
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source[name], output)
        for name in stale:
            target[name].unlink()
    print(f'Kitchen mirror: {len(source)} files; {len(changed)} changed; {len(stale)} stale')

if __name__ == '__main__':
    main()
