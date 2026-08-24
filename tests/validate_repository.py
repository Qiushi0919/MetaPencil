#!/usr/bin/env python3
"""Validate the Git-ready MetaPencil repository structure and optional baseline hashes."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "README.md",
    "AGENTS.md",
    "AI_CONTEXT.md",
    "AI_SYNC.md",
    "PROJECT_STATE.json",
    "CHANGELOG.md",
    "REPOSITORY_POLICY.md",
    "CHECKSUMS_SHA256.txt",
    "handoff_tools/run_smoke_test.m",
    "source/2 暑假_两个月仿真任务/Week 5 0815之前/SAR假目标自由度与物理阵列/run_full_array_freedom_study.m",
)


def verify_structure() -> None:
    missing = [item for item in REQUIRED if not (ROOT / item).exists()]
    if missing:
        raise SystemExit("Missing required paths:\n" + "\n".join(missing))
    with (ROOT / "PROJECT_STATE.json").open(encoding="utf-8") as handle:
        state = json.load(handle)
    if state.get("project_name") != "MetaPencil":
        raise SystemExit("PROJECT_STATE.json has an unexpected project_name")
    if state.get("repository", {}).get("default_branch") != "main":
        raise SystemExit("PROJECT_STATE.json must declare main as the default branch")


def verify_baseline_hashes() -> None:
    failures: list[str] = []
    checked = 0
    relocated = {
        # macOS cannot keep project_state.json and PROJECT_STATE.json side by side.
        "project_state.json": "docs/handoff/project_state.original.json",
    }
    with (ROOT / "CHECKSUMS_SHA256.txt").open(encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            if not line:
                continue
            expected, relative = line.split("  ", 1)
            path = ROOT / relocated.get(relative, relative)
            if not path.is_file():
                failures.append(f"missing: {relative}")
                continue
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            checked += 1
            if digest != expected:
                failures.append(f"hash mismatch: {relative}")
    if failures:
        raise SystemExit("Baseline checksum failure:\n" + "\n".join(failures[:20]))
    print(f"BASELINE_CHECKSUMS=PASS checked={checked}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--full", action="store_true", help="verify all imported SHA-256 entries")
    args = parser.parse_args()
    verify_structure()
    print("REPOSITORY_STRUCTURE=PASS")
    if args.full:
        verify_baseline_hashes()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
