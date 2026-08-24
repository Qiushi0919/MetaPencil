#!/usr/bin/env python3
"""Run the existing MATLAB smoke test and archive traceable artifacts."""

from __future__ import annotations

import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "outputs" / "smoke_test"


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def main() -> int:
    process = subprocess.run(
        ["python3", str(ROOT / "handoff_tools" / "run_smoke_test.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    DEST.mkdir(parents=True, exist_ok=True)
    combined = process.stdout + ("\nSTDERR\n" + process.stderr if process.stderr else "")
    (DEST / "matlab_smoke_test.log").write_text(combined, encoding="utf-8")
    for source, target in (
        (ROOT / "logs" / "smoke_harmonic_coefficients.csv", DEST / "harmonic_coefficients.csv"),
        (ROOT / "outputs" / "latest" / "smoke_harmonic_suppression.png", DEST / "harmonic_suppression.png"),
    ):
        if source.exists():
            shutil.copy2(source, target)
    manifest = {
        "status": "PASS" if process.returncode == 0 else "FAIL",
        "return_code": process.returncode,
        "source_commit": git("rev-parse", "HEAD"),
        "branch": git("branch", "--show-current"),
        "command": "python3 handoff_tools/run_smoke_test.py",
        "model_level": "L0 ideal harmonic coefficients and area/frequency mapping",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "core_algorithm_changed": False,
    }
    (DEST / "run_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(combined, end="")
    print(f"ARCHIVE={DEST}")
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())

