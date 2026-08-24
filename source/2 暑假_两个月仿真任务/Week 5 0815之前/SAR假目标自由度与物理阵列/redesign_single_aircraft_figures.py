from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
RESULT = ROOT / "results_full_array_exact"
TABLES = RESULT / "control_tables"
OUT = ROOT / "single_aircraft_redesign_figures"
OUT.mkdir(exist_ok=True)

FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"
W, H = 2560, 1440

NAVY = "#17324D"
TEXT = "#263F55"
MUTED = "#607789"
LINE = "#7890A2"
LIGHT_LINE = "#D5E0E7"
PALETTE = [
    "#DCEEFF", "#FFE3D5", "#DFF2E3", "#EBE2F6",
    "#FFF0C7", "#D8F1F0", "#F8DDEA", "#E0E6FA",
    "#E5F2D3", "#FCE7D4", "#D8EAF7", "#F3DDDB",
    "#DDEDD7", "#EEE1F3", "#F7EBCB", "#D9ECEE",
]
ACCENTS = [
    "#1769AA", "#C45122", "#247645", "#6B4BA1",
    "#9A6A00", "#087C78", "#A43A71", "#465EAA",
    "#5B7E23", "#B15C1E", "#2F7398", "#A34F48",
    "#4D7B42", "#78518F", "#987219", "#33777D",
]


def fnt(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT_PATH, size=size, index=1 if bold else 0)
    except OSError:
        return ImageFont.truetype(FONT_PATH, size=size)


def text_center(draw, xy, text, size, fill=NAVY, bold=False):
    draw.text(xy, text, font=fnt(size, bold), fill=fill, anchor="mm", align="center")


def rounded(draw, box, fill, outline=None, width=2, radius=18):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def paste_contain(canvas: Image.Image, image: Image.Image, box):
    x0, y0, x1, y1 = box
    scale = min((x1 - x0) / image.width, (y1 - y0) / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    x = round(x0 + (x1 - x0 - resized.width) / 2)
    y = round(y0 + (y1 - y0 - resized.height) / 2)
    canvas.paste(resized, (x, y))


def read_rows(path: Path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def format_offset(value: float):
    if abs(value - round(value)) < 1e-9:
        return f"{value:+.0f}"
    return f"{value:+.1f}"


def draw_slide_header(draw, title, subtitle=None):
    draw.rectangle((0, 0, W, 14), fill="#166AA5")
    draw.text((90, 52), title, font=fnt(42, True), fill=NAVY, anchor="la")
    draw.line((90, 112, W - 90, 112), fill="#BFD0DC", width=3)
    if subtitle:
        draw.text((90, 128), subtitle, font=fnt(23), fill=MUTED, anchor="la")


def draw_outer_grid(draw, tile_rows, channel_rows, box):
    x0, y0, x1, y1 = box
    n = max(int(r["outer_row"]) for r in tile_rows)
    channels = {int(r["channel_id"]): r for r in channel_rows}
    tiles = {(int(r["outer_row"]), int(r["outer_col"])): int(r["channel_id"]) for r in tile_rows}

    available = min(x1 - x0 - 70, y1 - y0 - 70)
    cell = int(available / n)
    grid = cell * n
    gx = x0 + 58 + max(0, (x1 - x0 - 70 - grid) // 2)
    gy = y0 + 58

    for col in range(1, n + 1):
        text_center(draw, (gx + (col - 0.5) * cell, gy - 27), f"A{col}", 20, TEXT, True)
    for row in range(1, n + 1):
        text_center(draw, (gx - 31, gy + (row - 0.5) * cell), f"R{row}", 20, TEXT, True)

    show_offset = n <= 5
    for row in range(1, n + 1):
        for col in range(1, n + 1):
            k = tiles[(row, col)]
            cx0 = gx + (col - 1) * cell
            cy0 = gy + (row - 1) * cell
            draw.rectangle(
                (cx0, cy0, cx0 + cell, cy0 + cell),
                fill=PALETTE[k - 1], outline=LINE, width=2,
            )
            text_center(draw, (cx0 + cell / 2, cy0 + cell * (0.40 if show_offset else 0.50)),
                        f"H{k}", 25 if n <= 5 else 19, ACCENTS[k - 1], True)
            if show_offset:
                info = channels[k]
                dr = format_offset(float(info["range_offset_m"]))
                da = format_offset(float(info["azimuth_offset_m"]))
                text_center(draw, (cx0 + cell / 2, cy0 + cell * 0.67),
                            f"({dr}, {da}) m", 17 if n == 5 else 20, TEXT)
    return channels, (gx, gy, grid, n)


def draw_channel_legend(draw, channels, y, max_width=920):
    ids = sorted(channels)
    cols = 4 if len(ids) > 6 else min(3, len(ids))
    rows = (len(ids) + cols - 1) // cols
    entry_w = max_width / cols
    row_h = 52
    x0 = 95
    for idx, k in enumerate(ids):
        r, c = divmod(idx, cols)
        x = x0 + c * entry_w
        yy = y + r * row_h
        draw.rounded_rectangle((x, yy + 7, x + 28, yy + 35), radius=6, fill=PALETTE[k - 1], outline=ACCENTS[k - 1], width=2)
        info = channels[k]
        dr = format_offset(float(info["range_offset_m"]))
        da = format_offset(float(info["azimuth_offset_m"]))
        count = int(float(info["outer_tile_count"]))
        draw.text((x + 40, yy + 22), f"H{k}: ({dr},{da}) m  ×{count}",
                  font=fnt(18), fill=TEXT, anchor="lm")
    return y + rows * row_h


def build_hk_structure():
    canvas = Image.new("RGB", (W, H), "white")
    draw = ImageDraw.Draw(canvas)
    draw_slide_header(
        draw,
        "Hk 的结构：一条假目标通道，而不是一个单独的延迟值",
        "所有Hk共用同一套4×4内部延迟模板；Hk之间由时间调制频率和方向区分",
    )

    # Left: channel definition and two concrete examples.
    rounded(draw, (90, 205, 690, 1110), "#F5F9FC", "#B9CAD6", 3, 24)
    text_center(draw, (390, 260), "1  定义第k条通道", 30, NAVY, True)
    text_center(draw, (390, 330), "Hk  <-->  (Δr_k, Δa_k)", 33, "#166AA5", True)
    text_center(draw, (390, 390), "指定SAR中的目标中心坐标", 22, MUTED)

    rounded(draw, (145, 470, 635, 690), PALETTE[0], ACCENTS[0], 3, 18)
    text_center(draw, (390, 515), "H1", 34, ACCENTS[0], True)
    text_center(draw, (390, 570), "目标位置 (-8, +8) m", 24, TEXT, True)
    text_center(draw, (390, 620), "f_r = +32 MHz", 23, TEXT)
    text_center(draw, (390, 660), "f_a = +42.67 Hz", 23, TEXT)

    rounded(draw, (145, 735, 635, 955), PALETTE[1], ACCENTS[1], 3, 18)
    text_center(draw, (390, 780), "H2", 34, ACCENTS[1], True)
    text_center(draw, (390, 835), "目标位置 (+8, +8) m", 24, TEXT, True)
    text_center(draw, (390, 885), "f_r = -32 MHz", 23, TEXT)
    text_center(draw, (390, 925), "f_a = +42.67 Hz", 23, TEXT)

    text_center(draw, (390, 1030), "区别在时间编码的频率/方向", 23, "#B4481D", True)

    # Middle: shared 4x4 delay template.
    rounded(draw, (745, 205, 1670, 1110), "#FBFCFD", "#B9CAD6", 3, 24)
    text_center(draw, (1208, 260), "2  Hk内部的4×4延迟子单元", 30, NAVY, True)
    text_center(draw, (1208, 305), "行控制距离向延迟 d_r，列控制方位向延迟 d_a", 21, MUTED)
    delays = ["0", "1/10", "5/6", "14/15"]
    gx, gy, cell = 875, 420, 155
    for c, value in enumerate(delays):
        text_center(draw, (gx + (c + 0.5) * cell, gy - 55), f"A{c+1}", 21, NAVY, True)
        text_center(draw, (gx + (c + 0.5) * cell, gy - 22), f"d_a={value}T", 17, MUTED)
    for r, value in enumerate(delays):
        text_center(draw, (gx - 58, gy + (r + 0.5) * cell - 13), f"R{r+1}", 21, NAVY, True)
        text_center(draw, (gx - 58, gy + (r + 0.5) * cell + 18), f"d_r={value}T", 16, MUTED)
        for c, value_a in enumerate(delays):
            x = gx + c * cell
            y = gy + r * cell
            draw.rectangle((x, y, x + cell, y + cell), fill=PALETTE[(r + c) % 4], outline=LINE, width=2)
            text_center(draw, (x + cell / 2, y + 35), f"P{r+1}{c+1}", 17, ACCENTS[(r + c) % 4], True)
            text_center(draw, (x + cell / 2, y + 80), f"({value},", 17, TEXT)
            text_center(draw, (x + cell / 2, y + 108), f" {value_a})T", 17, TEXT)
    text_center(draw, (1208, 1070), "这一内部矩阵对H1、H2、...完全相同", 22, "#247645", True)

    # Right: time coding and output.
    rounded(draw, (1725, 205, 2470, 1110), "#F5F9FC", "#B9CAD6", 3, 24)
    text_center(draw, (2098, 260), "3  生成2-bit时间编码", 30, NAVY, True)
    text_center(draw, (2098, 322), "每个子单元只有四种反射相位", 21, MUTED)
    phase_labels = ["0°", "90°", "180°", "270°"]
    phase_colors = ["#DCEEFF", "#DFF2E3", "#FFE3D5", "#EBE2F6"]
    phase_edges = ["#1769AA", "#247645", "#C45122", "#6B4BA1"]
    for i, label in enumerate(phase_labels):
        x = 1800 + i * 160
        rounded(draw, (x, 390, x + 128, 485), phase_colors[i], phase_edges[i], 3, 15)
        text_center(draw, (x + 64, 437), label, 25, phase_edges[i], True)
    draw.line((1810, 560, 2380, 560), fill=LINE, width=4)
    sequence = [0, 1, 2, 3, 0, 1, 2, 3]
    for i, state in enumerate(sequence):
        x = 1810 + i * 70
        y = 560 - state * 36
        draw.line((x, 560, x, y), fill=phase_edges[state], width=9)
        draw.ellipse((x - 8, y - 8, x + 8, y + 8), fill=phase_edges[state])
    text_center(draw, (2098, 610), "延迟子单元只改变序列的起始时刻", 22, TEXT, True)
    text_center(draw, (2098, 670), "Hk改变 f_r,k 与 f_a,k", 26, "#B4481D", True)
    text_center(draw, (2098, 720), "从而决定回波搬移到哪里", 22, MUTED)

    rounded(draw, (1805, 805, 2390, 990), "#EAF5FC", "#66A9D2", 3, 18)
    text_center(draw, (2098, 850), "原始飞机回波", 24, NAVY, True)
    text_center(draw, (2098, 900), "×  Hk的2-bit时变反射系数", 23, TEXT)
    text_center(draw, (2098, 950), "→  SAR假目标 (Δr_k, Δa_k)", 25, "#166AA5", True)

    # Bottom summary strip.
    rounded(draw, (90, 1165, 2470, 1350), "#EEF6FB", "#9FC1D7", 3, 22)
    text_center(draw, (1280, 1210), "外层宏格选择Hk  →  Hk内部16个延迟子单元并行工作  →  回波相干叠加", 29, NAVY, True)
    text_center(draw, (1280, 1270), "空间编码 = 哪个宏格分配哪个Hk；时间编码 = 每个Hk采用什么 f_r、f_a 和2-bit相位序列", 24, TEXT)
    text_center(draw, (1280, 1315), "H1与H2内部结构相同，目标位置不同", 23, "#B4481D", True)

    canvas.save(OUT / "00_Hk_structure.png", dpi=(220, 220))


CASES = [
    ("1to1", "单架飞机 1→1：一个指定假目标", "全部16个宏格选择H1；归一化后等价于同一通道相干叠加"),
    ("1to2", "单架飞机 1→2：两个等强假目标", "H1/H2各占8格，并在整个口径上交错分布"),
    ("1to3", "单架飞机 1→3：三点线目标", "25个宏格近似均分为9/8/8格"),
    ("1to4", "单架飞机 1→4：2×2二维目标", "H1-H4各占4格，每条通道对应一个目标坐标"),
    ("1to5", "单架飞机 1→5：十字五点目标", "H1-H5各占5格，中央与四个方向独立控制"),
    ("1to9", "单架飞机 1→9：3×3二维目标", "49个宏格在9条通道之间近似均分"),
    ("1to16", "单架飞机 1→16：4×4二维目标", "16个宏格分别选择H1-H16，每格负责一个目标坐标"),
]


def build_case(tag, title, subtitle):
    canvas = Image.new("RGB", (W, H), "white")
    draw = ImageDraw.Draw(canvas)
    draw_slide_header(draw, title, subtitle)

    tile_path = next(TABLES.glob(f"single_{tag}_outer_*_tiles.csv"))
    channel_path = TABLES / f"single_{tag}_channels.csv"
    tile_rows = read_rows(tile_path)
    channel_rows = read_rows(channel_path)

    text_center(draw, (525, 195), "最终外层宏格分配", 29, NAVY, True)
    text_center(draw, (525, 232), "颜色表示Hk通道，不表示回波强弱", 20, MUTED)
    channels, grid_info = draw_outer_grid(draw, tile_rows, channel_rows, (65, 230, 1010, 1040))

    _, gy, grid_size, n = grid_info
    legend_y = min(1080, gy + grid_size + 30)
    legend_bottom = draw_channel_legend(draw, channels, legend_y, 900)
    if legend_bottom < 1340:
        total = sum(int(float(v["outer_tile_count"])) for v in channels.values())
        rounded(draw, (95, legend_bottom + 8, 955, min(1360, legend_bottom + 82)),
                "#F4F8FB", "#C3D1DB", 2, 14)
        text_center(draw, (525, min(1337, legend_bottom + 45)),
                    f"共{total}个宏格；每个Hk内部都使用同一套4×4延迟模板", 19, TEXT)

    draw.line((1038, 170, 1038, 1370), fill=LIGHT_LINE, width=3)
    text_center(draw, (1790, 186), "同一控制配置产生的完整RD成像", 29, NAVY, True)
    draw.text((1190, 225), "□ 浅蓝框：原始飞机位置", font=fnt(19), fill="#2D91BB", anchor="lm")
    draw.text((1690, 225), "○ 橙色点：期望假目标中心", font=fnt(19), fill="#B47600", anchor="lm")

    sar = Image.open(RESULT / f"single_{tag}_sar.png").convert("RGB")
    # Remove the old top title only; the plotted RD values and annotations remain unchanged.
    sar = sar.crop((0, 45, sar.width, sar.height))
    paste_contain(canvas, sar, (1070, 250, 2505, 1390))

    canvas.save(OUT / f"{tag}_high_contrast.png", dpi=(220, 220))


if __name__ == "__main__":
    build_hk_structure()
    for case in CASES:
        build_case(*case)
    print(OUT)
