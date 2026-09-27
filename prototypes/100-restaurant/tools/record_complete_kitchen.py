"""Record the complete player tutorial, restoring normal window settings.

Godot chooses its Movie Maker dimensions before SceneTree._initialize. Only
capture viewport overrides are temporarily changed; gameplay stays native.
"""
import argparse
import re
import subprocess
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', required=True)
parser.add_argument('--movie', required=True, type=Path)
parser.add_argument('--evidence', required=True, type=Path)
parser.add_argument('--log', required=True, type=Path)
parser.add_argument('--script', default='tests/capture_complete_kitchen.gd')
parser.add_argument('--mode', choices=['pilot', 'extras', 'probe', 'ending'])
args = parser.parse_args()
for path in (args.movie.parent, args.evidence, args.log.parent):
    path.mkdir(parents=True, exist_ok=True)
config = PROJECT / 'project.godot'
original = config.read_bytes()
recording = re.sub(rb'window_width_override=\d+', b'window_width_override=1352', original)
recording = re.sub(rb'window_height_override=\d+', b'window_height_override=852', recording)
command = [args.godot, '--path', str(PROJECT), '--write-movie', str(args.movie.resolve()),
           '--fixed-fps', '24', '--disable-vsync', '--script',
           args.script, '--quit-after', '43000', '--',
           str(args.evidence.resolve())]
if args.mode:
    command.append(args.mode)
process = None
try:
    config.write_bytes(recording)
    with args.log.open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 30
        while process.poll() is None and time.monotonic() < deadline:
            if 'recording movie in 1352×852 @ 24 FPS' in args.log.read_text(errors='replace'):
                if config.read_bytes() == recording:
                    config.write_bytes(original)
                print('Movie initialized at 1352×852; normal window configuration restored.', flush=True)
                break
            time.sleep(.1)
        code = process.wait()
    text = args.log.read_text(errors='replace')
    marker = 'PROBE_DONE ' if args.mode == 'probe' else 'PASS:'
    if code or re.search(r'^\s*(SCRIPT ERROR:|ERROR:|FAIL\b)', text, re.M) or marker not in text:
        raise SystemExit('Capture failed; inspect ' + str(args.log))
    print('PASS: completed native capture; ' + str(args.movie), flush=True)
finally:
    if config.read_bytes() == recording:
        config.write_bytes(original)
    if process is not None and process.poll() is None:
        process.terminate()
