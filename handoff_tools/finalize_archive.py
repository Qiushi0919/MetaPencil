#!/usr/bin/env python3
"""Validate the handoff tree, write checksums, and build/test the final ZIP."""

from __future__ import annotations

import csv
import hashlib
import json
import os
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ZIP_PATH = ROOT.parent / "MetaPencil_Code_Handoff_20260824.zip"
CHECKSUM_FILE = ROOT / "CHECKSUMS_SHA256.txt"
VALIDATION_LOG = ROOT / "logs" / "archive_validation.log"

REQUIRED = [
    *(f"{index:02d}_{name}.md" for index, name in [
        (0, "README_FIRST"), (1, "AI_CONTEXT"), (2, "PROJECT_OVERVIEW"),
        (3, "CURRENT_PROGRESS"), (4, "CODE_MAP"), (5, "RUNBOOK"),
        (6, "FORMULA_CODE_MAPPING"), (7, "RESULTS_TRACEABILITY"),
        (8, "PARAMETERS_AND_CONVENTIONS"), (9, "KNOWN_ISSUES"),
        (10, "NEXT_STEPS"), (11, "REPRODUCTION_CHECKLIST"),
        (12, "TECHNICAL_DEBT"), (13, "REDACTION_REPORT"),
    ]),
    "project_state.json", "file_manifest.csv", "original_tree.txt",
    "docs/PPT_NOTES_EXTRACTED.md", "docs/PPT_SLIDE_CODE_MAPPING.md",
    "docs/source_materials/0818.pptx", "docs/source_materials/0818.pdf",
    "logs/smoke_test.log", "handoff_tools/run_smoke_test.m",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_tree() -> tuple[int, int, int]:
    missing = [item for item in REQUIRED if not (ROOT / item).is_file()]
    if missing:
        raise SystemExit("Missing required files: " + ", ".join(missing))
    json.loads((ROOT / "project_state.json").read_text(encoding="utf-8"))
    smoke = (ROOT / "logs" / "smoke_test.log").read_text(encoding="utf-8")
    if "RETURN_CODE=0" not in smoke or "SMOKE_TEST_STATUS=PASS" not in smoke:
        raise SystemExit("Smoke-test log does not show PASS.")
    with (ROOT / "file_manifest.csv").open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    included = sum(row["included_in_zip"] == "true" for row in rows)
    excluded_large = sum(
        row["included_in_zip"] == "false" and int(row["size_bytes"]) > 10 * 1024 * 1024
        for row in rows
    )
    code_count = sum(
        1 for path in (ROOT / "source").rglob("*")
        if path.is_file() and path.suffix.lower() in {".m", ".py", ".mjs", ".js"}
    )
    if code_count < 68:
        raise SystemExit(f"Source-code count unexpectedly low: {code_count}")
    return len(rows), included, excluded_large


def write_checksums() -> int:
    files = sorted(
        path for path in ROOT.rglob("*")
        if path.is_file() and path != CHECKSUM_FILE
    )
    lines = [f"{sha256(path)}  {path.relative_to(ROOT).as_posix()}" for path in files]
    CHECKSUM_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(files)


def build_zip() -> None:
    if ZIP_PATH.exists():
        ZIP_PATH.unlink()
    with zipfile.ZipFile(
        ZIP_PATH, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6,
        allowZip64=True,
    ) as archive:
        for path in sorted(ROOT.rglob("*"), key=lambda item: item.as_posix()):
            if path.is_file():
                archive.write(path, path.relative_to(ROOT.parent).as_posix())
    with zipfile.ZipFile(ZIP_PATH) as archive:
        bad = archive.testzip()
        if bad is not None:
            raise SystemExit(f"ZIP CRC test failed at {bad}")


def main() -> None:
    manifest_count, included_count, excluded_large = validate_tree()
    VALIDATION_LOG.write_text(
        "MetaPencil archive preflight — PASS\n"
        f"Manifest original files: {manifest_count}\n"
        f"Original files selected: {included_count}\n"
        f"Excluded original files >10 MiB: {excluded_large}\n"
        "Required root documents: PASS\n"
        "project_state.json parse: PASS\n"
        "Smoke-test log: PASS\n"
        "Source-code completeness threshold: PASS\n"
        "Finalization policy: the script exits successfully only after ZIP CRC testzip PASS.\n",
        encoding="utf-8",
    )
    checksum_count = write_checksums()
    build_zip()
    print("ARCHIVE_STATUS=PASS")
    print(f"CHECKSUMMED_INTERNAL_FILES={checksum_count}")
    print(f"ZIP_PATH={ZIP_PATH}")
    print(f"ZIP_SIZE_BYTES={ZIP_PATH.stat().st_size}")
    print(f"ZIP_SHA256={sha256(ZIP_PATH)}")


if __name__ == "__main__":
    main()
