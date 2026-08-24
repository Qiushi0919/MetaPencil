#!/usr/bin/env python3
"""Build the non-destructive MetaPencil handoff snapshot from the original tree.

This helper only reads the original project and writes under MetaPencil_Handoff.
It deliberately excludes large MATLAB/FIG intermediates while retaining all source
text, compact input data, models, control tables, PNG results, selected reports,
and the three references used by the 0818 presentation.
"""

from __future__ import annotations

import csv
import hashlib
import os
import re
import shutil
from pathlib import Path


HANDOFF = Path(__file__).resolve().parents[1]
WORKSPACE = HANDOFF.parent
ORIGINAL = WORKSPACE / "2 暑假_两个月仿真任务"
ORIGINAL_PREFIX = ORIGINAL.name

TEXT_SOURCE_EXT = {".m", ".py", ".mjs", ".js", ".md", ".txt", ".csv", ".json", ".yaml", ".yml"}
MODEL_EXT = {".stl", ".fbx", ".max", ".hdr"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp"}
CONFIG_EXT = {".csv", ".json", ".yaml", ".yml"}
ENTRYPOINTS = {
    "Week 5 0815之前/SAR假目标自由度与物理阵列/run_full_array_freedom_study.m",
    "Week 5 0815之前/SAR假目标自由度与物理阵列/SHIP_4x4_to_4x4_7x7_physical.m",
    "Week 5 0815之前/SAR假目标自由度与物理阵列/run_four_aircraft_ppt_style_shapes.m",
    "Week 5 0815之前/歼36_4x4机群_2bit分区相消/SHIP_4x4_2bit_partition_cancel_wide100.m",
    "Week 4 0813之前/歼36_4x4机群_sar_code_2D/SHIP_4x4.m",
    "Week 4 0813之前/歼36_4x4机群_sar_code_2D/SHIP_4x4_ssb_2bit.m",
}

SELECTED_MATERIALS = {
    "Week 5 0826之前/0818.pptx": "source_materials",
    "Week 5 0826之前/0818.pdf": "source_materials",
    "Week 5 0815之前/0815.pptx": "source_materials",
    "Week 5 0815之前/0815.pdf": "source_materials",
    "Week 5 0815之前/2026基于分布式时间调制超表面的复杂目标电磁拟像方法研究.docx": "source_materials",
    "Week 5 0815之前/SAR假目标自由度与物理阵列/时变2-bit超表面_SAR假目标自由度与物理阵列_时延矩阵版.pptx": "source_materials",
    "Week 5 0815之前/SAR假目标自由度与物理阵列/单架飞机_1到N_Hk结构与2bit计算.pptx": "source_materials",
    "Week 5 0815之前/SAR假目标自由度与物理阵列/单架_双机_四机_假目标自由度与2bit计算.pptx": "source_materials",
    "Week 5 0815之前/相关工作1-提高bit数.pdf": "references",
    "Week 5 0815之前/相关工作2-时延控制.pdf": "references",
    "Week 5 0815之前/相关工作2-向量叠加.pdf": "references",
}

LATEST_ROOT = Path("Week 5 0815之前/SAR假目标自由度与物理阵列/results_full_array_exact")
LATEST_EXTRA = {
    Path("Week 5 0815之前/SAR假目标自由度与物理阵列/results_four_aircraft_ppt_style_shapes/regular_4x4_sar.png"),
    Path("Week 5 0815之前/SAR假目标自由度与物理阵列/results_four_aircraft_ppt_style_shapes/star_16_sar.png"),
    Path("Week 5 0815之前/SAR假目标自由度与物理阵列/results_four_aircraft_ppt_style_shapes/pinwheel_16_sar.png"),
    Path("Week 5 0815之前/SAR假目标自由度与物理阵列/results_four_aircraft_ppt_style_shapes/infinity_16_sar.png"),
}

BASELINE_1BIT = Path("Week 4 0813之前/歼36_4x4机群_sar_code_2D/results_4x4/20260812_133301_uav")
BASELINE_2BIT = Path("Week 4 0813之前/歼36_4x4机群_sar_code_2D/results_4x4_2bit_balanced_wide100/20260813_212143_uav")
SUPPRESSION = Path("Week 5 0815之前/歼36_4x4机群_2bit分区相消/results_4x4_2bit_partition_cancel_wide100/20260814_212232_uav")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def has_hidden_component(rel: Path) -> bool:
    return any(part.startswith(".") for part in rel.parts)


def redact_text(text: str) -> str:
    text = re.sub(
        r"/Users/[^/]+/Library/CloudStorage/OneDrive-个人/[^\n\r\"']*?Meta浙江大学",
        "<REDACTED_WORKSPACE_ROOT>",
        text,
    )
    text = re.sub(r"/Users/[^/]+/\.cache", "<REDACTED_USER_CACHE>", text)
    text = re.sub(r"/Users/[^/]+", "<REDACTED_USER_HOME>", text)
    return text


def copy_original(src: Path, dst: Path, redact: bool = False) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        dst.chmod(0o644)
    if redact:
        text = src.read_text(encoding="utf-8", errors="replace")
        dst.write_text(redact_text(text), encoding="utf-8")
        shutil.copystat(src, dst)
    else:
        shutil.copy2(src, dst)


def classify(rel: Path, size: int) -> tuple[bool, str, str, str]:
    """Return included, category, purpose, exclusion_reason."""
    ext = rel.suffix.lower()
    rel_s = rel.as_posix()
    hidden = has_hidden_component(rel)

    if rel_s in SELECTED_MATERIALS:
        category = SELECTED_MATERIALS[rel_s]
        return True, category, "selected report/reference used by current research", ""
    # Source-code completeness takes priority over the default hidden-cache rule.
    # Two PPT build helpers live under hidden build directories and are still code.
    if ext in {".m", ".py", ".mjs", ".js"}:
        return True, "source", "MATLAB/source text", ""
    if hidden:
        return False, "temporary", "presentation/cache intermediate", "hidden temporary/cache directory"
    if rel.name == ".DS_Store":
        return False, "system", "macOS metadata", "system metadata"
    if ext in TEXT_SOURCE_EXT:
        purpose = "MATLAB/source text" if ext in {".m", ".py", ".mjs", ".js"} else "documentation or compact configuration/result table"
        return True, "source" if ext not in CONFIG_EXT else "configuration", purpose, ""
    if ext in MODEL_EXT:
        return True, "sample_data", "aircraft/CAD model source", ""
    if ext in IMAGE_EXT:
        return True, "result_image", "rendered simulation/result/reference image", ""
    if ext == ".mat" and size <= 2 * 1024 * 1024 and "/cache/" not in f"/{rel_s}":
        return True, "sample_data", "compact MATLAB input or result snapshot", ""
    if ext == ".docx":
        return False, "document", "non-selected project document", "non-selected source material"
    if ext in {".pptx", ".pdf"}:
        return False, "document", "historical report/reference", "non-selected or superseded report/reference"
    if ext == ".fig":
        return False, "generated_large", "MATLAB editable figure", "large reproducible FIG intermediate; PNG retained when available"
    if ext == ".mat":
        return False, "generated_large", "MATLAB raw/result matrix", "large raw/result MAT excluded; compact data and PNG/CSV retained"
    if ext in {".zip", ".html"}:
        return False, "archive_or_generated", "archive/generated tutorial", "large archive or generated HTML excluded"
    return False, "other", "unclassified project artifact", "nonessential or unsupported artifact type"


def output_category(rel: Path) -> str | None:
    if rel.is_relative_to(LATEST_ROOT):
        name = rel.name.lower()
        if name.endswith((".png", ".csv", ".mat")):
            if name.startswith("single_"):
                return "single_uav"
            if "two_aircraft" in name or "four_aircraft" in name:
                return "multi_uav"
            if "harmonic" in name:
                return "harmonic_suppression"
            return "latest"
    if rel in LATEST_EXTRA:
        return "multi_uav"
    if rel.is_relative_to(BASELINE_1BIT) and rel.suffix.lower() in {".png", ".csv"}:
        return "baseline_1bit"
    if rel.is_relative_to(BASELINE_2BIT) and rel.suffix.lower() in {".png", ".csv"}:
        return "baseline_2bit"
    if rel.is_relative_to(SUPPRESSION) and rel.suffix.lower() in {".png", ".csv"}:
        return "harmonic_suppression"
    return None


def status_for(rel: Path) -> str:
    s = rel.as_posix()
    if s.startswith("Week 5 0826之前") or "SAR假目标自由度与物理阵列" in s:
        return "current"
    if s.startswith("Week 5 0815之前") or s.startswith("Week 4 0813之前"):
        return "active_baseline"
    if "/results" in f"/{s}" or "/output" in f"/{s}":
        return "historical_generated"
    return "legacy_or_reference"


def main() -> None:
    if not ORIGINAL.is_dir():
        raise SystemExit(f"Original project not found: {ORIGINAL}")

    included_paths: set[str] = set()
    rows: list[dict[str, object]] = []
    tree_lines: list[str] = [ORIGINAL_PREFIX + "/"]
    excluded_large: list[tuple[int, str, str]] = []

    files = sorted((p for p in ORIGINAL.rglob("*") if p.is_file()), key=lambda p: p.as_posix())
    for src in files:
        rel = src.relative_to(ORIGINAL)
        package_rel = Path(ORIGINAL_PREFIX) / rel
        size = src.stat().st_size
        include, category, purpose, reason = classify(rel, size)
        ext = src.suffix.lower()
        redact = ext in TEXT_SOURCE_EXT

        if include:
            if category in {"source", "configuration"}:
                copy_original(src, HANDOFF / "source" / package_rel, redact=redact)
            elif category == "sample_data":
                copy_original(src, HANDOFF / "source" / package_rel, redact=False)
                # Keep CAD/models once at their original source-relative path.
                # Duplicate only compact MAT inputs into the convenience sample_data tree.
                if ext == ".mat":
                    copy_original(src, HANDOFF / "sample_data" / package_rel, redact=False)
            elif category == "result_image":
                copy_original(src, HANDOFF / "outputs" / "archive_png" / package_rel, redact=False)
            elif category == "source_materials":
                copy_original(src, HANDOFF / "docs" / "source_materials" / src.name, redact=False)
            elif category == "references":
                copy_original(src, HANDOFF / "docs" / "references" / src.name, redact=False)

            if ext in CONFIG_EXT:
                copy_original(src, HANDOFF / "configs" / package_rel, redact=redact)

            out_cat = output_category(rel)
            if out_cat:
                copy_original(src, HANDOFF / "outputs" / out_cat / rel.name, redact=False)
            included_paths.add(package_rel.as_posix())
        elif size > 10 * 1024 * 1024:
            excluded_large.append((size, package_rel.as_posix(), reason))

        rows.append({
            "relative_path": package_rel.as_posix(),
            "file_name": src.name,
            "extension": ext,
            "size_bytes": size,
            "sha256": sha256(src),
            "category": category,
            "purpose": purpose,
            "status": status_for(rel),
            "is_entrypoint": str(rel.as_posix() in ENTRYPOINTS).lower(),
            "is_generated": str(("/results" in f"/{rel.as_posix()}" or "/output" in f"/{rel.as_posix()}" or ext in {".fig", ".png"})).lower(),
            "included_in_zip": str(include).lower(),
            "exclusion_reason": reason,
        })

    # Create a compact tree without importing external `tree` formatting quirks.
    for path in sorted(ORIGINAL.rglob("*"), key=lambda p: p.as_posix()):
        rel = path.relative_to(ORIGINAL)
        suffix = "/" if path.is_dir() else ""
        tree_lines.append("  " * len(rel.parts) + rel.name + suffix)
    (HANDOFF / "original_tree.txt").write_text("\n".join(tree_lines) + "\n", encoding="utf-8")

    fields = [
        "relative_path", "file_name", "extension", "size_bytes", "sha256",
        "category", "purpose", "status", "is_entrypoint", "is_generated",
        "included_in_zip", "exclusion_reason",
    ]
    with (HANDOFF / "file_manifest.csv").open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    excluded_large.sort(reverse=True)
    lines = [
        "Excluded original files larger than 10 MiB",
        f"Count: {len(excluded_large)}",
        "size_bytes|relative_path|reason",
    ]
    lines.extend(f"{size}|{path}|{reason}" for size, path, reason in excluded_large)
    (HANDOFF / "logs" / "excluded_large_files.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Original files inventoried: {len(rows)}")
    print(f"Original files included: {sum(r['included_in_zip'] == 'true' for r in rows)}")
    print(f"Excluded files >10 MiB: {len(excluded_large)}")


if __name__ == "__main__":
    main()
