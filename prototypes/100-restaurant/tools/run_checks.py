"""The full, shared local/CI checks. Uses only Python 3's standard library."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
ERROR = re.compile(r"^\s*(?:SCRIPT ERROR:|ERROR:|FAIL\b)", re.MULTILINE)
SUCCESS = re.compile(
    r"^(?:PASS\b.*|[A-Z_]+_PASSED\b.*|Asset alpha audit: .*\b0 errors)\s*$",
    re.MULTILINE,
)


def run_step(name, command, output_dir, *, success=None, timeout=120):
    """A zero exit alone is insufficient: retain logs and check engine errors."""
    try:
        process = subprocess.run(
            command, cwd=PROJECT, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding="utf-8",
            errors="replace", timeout=timeout,
        )
        output = process.stdout
        code = process.returncode
        reason = "" if code == 0 else f"exit {code}"
    except subprocess.TimeoutExpired as exc:
        partial = exc.stdout or b""
        output = partial.decode("utf-8", "replace") if isinstance(partial, bytes) else partial
        code = None
        reason = f"timed out after {timeout}s"
    except OSError as exc:
        output, code, reason = str(exc), None, "could not start command"
    clean = ANSI.sub("", output)
    if not reason and ERROR.search(clean):
        reason = "engine reported an error"
    if not reason and success is not None and not success.search(clean):
        reason = "missing completion marker"
    log = output_dir / (name.replace("/", "_").replace(".", "_") + ".log")
    log.write_text(output.rstrip() + "\n", encoding="utf-8")
    result = {"name": name, "passed": not reason, "exit_code": code,
              "reason": reason, "log": log.name}
    print(f"{'PASS' if result['passed'] else 'FAIL'} {name}" +
          (f": {reason}" if reason else ""), flush=True)
    if reason:
        print("\n".join(clean.splitlines()[-35:]), flush=True)
    return result


def run_suite(godot, scripts, output_dir):
    # Gather every failure; one stale assertion must not hide later failures.
    return [run_step(script, [godot, "--headless", "--path", str(PROJECT),
                             "--script", script, "--quit-after", "18000"],
                     output_dir, success=SUCCESS) for script in scripts]


def load_suite():
    suite = json.loads((PROJECT / "tools/regression_suite.json").read_text(encoding="utf-8"))
    scripts = suite["scripts"]
    if not scripts or len(scripts) != len(set(scripts)):
        raise ValueError("regression manifest is empty or contains duplicates")
    for script in scripts:
        path = (PROJECT / script).resolve()
        if PROJECT not in path.parents or not path.is_file() or path.suffix != ".gd":
            raise ValueError(f"invalid regression script: {script}")
    return suite


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.7.2 executable")
    parser.add_argument("--output-dir", type=Path, default=PROJECT / ".runtime/checks")
    args = parser.parse_args(argv)
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    suite = load_suite()
    results = []
    version_pattern = re.compile(r"^" + re.escape(suite["godot_version"]) + r"\.", re.MULTILINE)
    results.append(run_step("engine-version", [args.godot, "--version"], output_dir,
                            success=version_pattern))
    if results[-1]["passed"]:
        results.append(run_step("project-import", [args.godot, "--headless", "--editor",
                                                  "--path", str(PROJECT), "--import"],
                                output_dir, timeout=300))
        if results[-1]["passed"]:
            results.append(run_step("startup-120-frames", [args.godot, "--headless",
                                                           "--path", str(PROJECT),
                                                           "--quit-after", "120"], output_dir))
            results.extend(run_suite(args.godot, suite["scripts"], output_dir))
            results.append(run_step("recorded-audio-audit", [sys.executable,
                                      str(PROJECT / "tools/audit_recorded_audio.py")],
                                    output_dir, success=re.compile(r'"status":\s*"PASS"')))
            results.append(run_step("prepared-food-audit", [sys.executable,
                                      str(PROJECT / "tools/audit_prepared_food.py")],
                                    output_dir, success=re.compile(r'"status":\s*"PASS"')))
    ran = sum(result["name"] in suite["scripts"] for result in results)
    failed = [result["name"] for result in results if not result["passed"]]
    passed = not failed and ran == len(suite["scripts"])
    report = {"status": "PASS" if passed else "FAIL", "godot_version": suite["godot_version"],
              "scripts_expected": len(suite["scripts"]), "scripts_run": ran,
              "failed": failed, "results": results}
    (output_dir / "summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{report['status']}: full checks, {ran}/{len(suite['scripts'])} Godot scripts; "
          f"{len(failed)} failed steps. Logs: {output_dir}", flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
