"""Cold-import resources before loading Solmere's texture-dependent autoloads.

Run only in a checkout with no editor open. The original project.godot bytes are
restored even when import fails. Both passes must exit cleanly without errors.
"""
from pathlib import Path
import argparse
import os
import re
import subprocess
import sys

BOOTSTRAP = b'''config_version=5
[application]
config/name="Solmere resource import"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
'''
ERROR = re.compile(r"^(?:SCRIPT ERROR:|ERROR:)", re.MULTILINE)


def run_pass(godot: str, root: Path, log: Path, timeout: int) -> None:
    # Windows' *_console.exe is a launcher; terminate the actual engine on timeout.
    binary = Path(godot)
    direct = binary.with_name(binary.name.replace("_console.exe", ".exe"))
    if os.name == "nt" and direct != binary and direct.is_file():
        godot = str(direct)
    with log.open("wb") as output:
        result = subprocess.run(
            [godot, "--headless", "--editor", "--path", str(root), "--import"],
            stdout=output, stderr=subprocess.STDOUT, timeout=timeout,
        )
    content = log.read_text(encoding="utf-8", errors="replace")
    if result.returncode != 0 or ERROR.search(content):
        print(content, file=sys.stderr)
        raise RuntimeError(f"{log.name}: exit {result.returncode} or engine errors")
    print(f"PASS {log.name}", flush=True)


def import_project(godot: str, root: Path, logs: Path, timeout: int = 300) -> None:
    project = root / "project.godot"
    original = project.read_bytes()
    logs.mkdir(parents=True, exist_ok=True)
    backup = logs / "project.godot.before-import"
    if backup.exists():
        raise RuntimeError(f"Unfinished import backup exists: {backup}; inspect before retrying")
    backup.write_bytes(original)
    try:
        project.write_bytes(BOOTSTRAP)
        run_pass(godot, root, logs / "main-bootstrap.log", timeout)
    finally:
        project.write_bytes(original)
        backup.unlink()
    run_pass(godot, root, logs / "main-import.log", timeout)
    assert project.read_bytes() == original


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--logs", type=Path, default=Path(".runtime/main-import"))
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    import_project(args.godot, args.project.resolve(), args.logs.resolve(), args.timeout)


if __name__ == "__main__":
    main()
