#!/usr/bin/env python3
"""Grade all completed runs in iteration-7.

Usage: python3 grade_all.py [--no-exec]

Skips runs with no .tftest.hcl files (not yet generated). Runs serially
to avoid terraform plugin-cache lock contention.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WS = REPO / "terraform-test-generator-workspace" / "iteration-7"
GRADER = Path(__file__).parent / "grade_run.py"


def main():
    no_exec = "--no-exec" in sys.argv
    runs = []
    for eid in range(1, 6):
        for cfg in ("with_skill", "without_skill"):
            for r in (1, 2, 3):
                run_dir = WS / f"eval-{eid}" / cfg / f"run-{r}"
                outputs = run_dir / "outputs"
                tf_files = list(outputs.rglob("*.tftest.hcl")) if outputs.exists() else []
                if tf_files:
                    runs.append(run_dir)

    print(f"Grading {len(runs)} completed runs (no-exec={no_exec})...")
    passed = failed = 0
    t0 = time.time()
    for i, run_dir in enumerate(runs, 1):
        cmd = [sys.executable, str(GRADER), str(run_dir)]
        if no_exec:
            cmd.append("--no-exec")
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        line = r.stdout.strip().split("\n")[-1] if r.stdout else "(no output)"
        if r.returncode != 0:
            failed += 1
            print(f"  [{i}/{len(runs)}] ERROR {run_dir.parent.name}/{run_dir.name}: {line}")
            if r.stderr:
                print(f"         stderr: {r.stderr[-200:]}")
        else:
            passed += 1
            print(f"  [{i}/{len(runs)}] {line}")
    elapsed = time.time() - t0
    print(f"\nDone: {passed} graded, {failed} errors, {elapsed:.0f}s total")


if __name__ == "__main__":
    main()
