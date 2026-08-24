#!/usr/bin/env python3
"""Run the MATLAB smoke test and preserve stdout/stderr in logs/."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = Path(__file__).with_name("run_smoke_test.m")
LOG = ROOT / "logs" / "smoke_test.log"
ERROR_LOG = ROOT / "logs" / "errors.log"


def find_matlab() -> str | None:
    candidates = [
        shutil.which("matlab"),
        "/Applications/MATLAB_R2025a.app/bin/matlab",
    ]
    return next((item for item in candidates if item and Path(item).exists()), None)


def main() -> int:
    matlab = find_matlab()
    if not matlab:
        message = "SMOKE_TEST_STATUS=FAIL\nMATLAB executable not found.\n"
        LOG.write_text(message, encoding="utf-8")
        ERROR_LOG.write_text(message, encoding="utf-8")
        print(message, end="")
        return 2

    command = [matlab, "-batch", f"run('{SCRIPT.as_posix()}')"]
    display_command = [matlab, "-batch", "run('<HANDOFF_ROOT>/handoff_tools/run_smoke_test.m')"]
    env = os.environ.copy()
    process = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True)
    combined = (
        "COMMAND=" + " ".join(display_command) + "\n"
        + f"RETURN_CODE={process.returncode}\n"
        + process.stdout
        + ("\nSTDERR\n" + process.stderr if process.stderr else "")
    )
    LOG.write_text(combined, encoding="utf-8")
    ERROR_LOG.write_text(process.stderr or "No stderr.\n", encoding="utf-8")
    print(combined, end="")
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
