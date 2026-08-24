#!/usr/bin/env python3
"""Extract visible text and speaker notes from the selected 0818 PPTX."""

from __future__ import annotations

import re
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
PPTX = ROOT / "docs" / "source_materials" / "0818.pptx"
OUTPUT = ROOT / "docs" / "PPT_NOTES_EXTRACTED.md"
NS = {"a": "http://schemas.openxmlformats.org/drawingml/2006/main"}


def paragraphs(blob: bytes) -> list[str]:
    root = ET.fromstring(blob)
    result: list[str] = []
    for paragraph in root.findall(".//a:p", NS):
        text = "".join(node.text or "" for node in paragraph.findall(".//a:t", NS)).strip()
        if text:
            result.append(text)
    return result


def main() -> None:
    if not PPTX.is_file():
        raise SystemExit(f"PPTX not found: {PPTX}")
    lines = [
        "# 0818 PPT 逐页文字与备注提取",
        "",
        f"- 来源：`docs/source_materials/{PPTX.name}`",
        "- 提取方式：将 PPTX 作为 ZIP，读取 `ppt/slides/` 与 `ppt/notesSlides/` XML。",
        "- 说明：‘页内文字’为可见文本框的阅读顺序近似；‘备注’保留备注页中的全部非空段落，页码占位符除外。",
        "",
    ]
    with ZipFile(PPTX) as archive:
        names = set(archive.namelist())
        slide_names = sorted(
            (name for name in names if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)),
            key=lambda name: int(re.search(r"slide(\d+)", name).group(1)),
        )
        for index, slide_name in enumerate(slide_names, 1):
            slide_paragraphs = paragraphs(archive.read(slide_name))
            note_name = f"ppt/notesSlides/notesSlide{index}.xml"
            note_paragraphs = paragraphs(archive.read(note_name)) if note_name in names else []
            note_paragraphs = [text for text in note_paragraphs if text != str(index)]
            title = slide_paragraphs[0] if slide_paragraphs else "（无标题）"
            lines.extend([
                f"## 第 {index:02d} 页：{title}",
                "",
                "### 页内文字",
                "",
            ])
            lines.extend(f"- {text}" for text in slide_paragraphs)
            if not slide_paragraphs:
                lines.append("- （无可提取文字）")
            lines.extend(["", "### 备注", ""])
            lines.extend(f"- {text}" for text in note_paragraphs)
            if not note_paragraphs:
                lines.append("- （无备注）")
            lines.append("")
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Extracted {len(slide_names)} slides to {OUTPUT}")


if __name__ == "__main__":
    main()
