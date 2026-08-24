#!/usr/bin/env python3
"""Fail on high-confidence credential patterns in readable repository files."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKIP_PARTS = {".git", "__pycache__"}
SKIP_SUFFIXES = {
    ".pdf", ".pptx", ".docx", ".png", ".jpg", ".jpeg", ".mat", ".fig", ".stl", ".fbx", ".zip"
}
PATTERNS = {
    "private key": re.compile(r"-----BEGIN (?:RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----"),
    "AWS access key": re.compile(r"AKIA[0-9A-Z]{16}"),
    "GitHub fine-grained token": re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    "GitHub token": re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    "OpenAI-style key": re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
}


def main() -> int:
    findings: list[str] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or any(part in SKIP_PARTS for part in path.parts):
            continue
        if path.suffix.lower() in SKIP_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for label, pattern in PATTERNS.items():
            if pattern.search(text):
                findings.append(f"{label}: {path.relative_to(ROOT)}")
    if findings:
        print("SENSITIVE_SCAN=FAIL")
        print("\n".join(findings))
        return 1
    print("SENSITIVE_SCAN=PASS high_confidence_findings=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

