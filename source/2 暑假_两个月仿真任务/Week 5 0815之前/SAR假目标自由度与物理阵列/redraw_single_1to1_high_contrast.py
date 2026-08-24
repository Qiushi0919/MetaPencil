from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "results_full_array_exact" / "single_1to1_pair.png"
OUTPUT = ROOT / "results_full_array_exact" / "single_1to1_high_contrast.png"
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    # TTC index 1 is the heavier face on macOS; fall back to the regular face.
    try:
        return ImageFont.truetype(FONT, size=size, index=1 if bold else 0)
    except OSError:
        return ImageFont.truetype(FONT, size=size)


def centered(draw: ImageDraw.ImageDraw, xy, text, text_font, fill):
    draw.text(xy, text, font=text_font, fill=fill, anchor="mm", align="center")


source = Image.open(SOURCE).convert("RGB")

# Keep the original full-chain SAR result unchanged.  This crop removes only
# the old global heading and the unreadable left control-grid panel.
sar = source.crop((1925, 110, 3986, 2059))

canvas = Image.new("RGB", (2600, 1250), "white")
draw = ImageDraw.Draw(canvas)

navy = "#15324A"
muted = "#526777"
grid_line = "#5C7080"
header_fill = "#D9ECFF"
cell_a = "#E8F4FF"
cell_b = "#DCEEFF"
accent = "#1570A6"

# Overall title.
centered(
    draw,
    (1300, 48),
    "1→1：4×4实际控制阵列与完整RD成像",
    font(38, True),
    navy,
)

# Left panel title and explanatory line.
centered(draw, (545, 112), "最终外层4×4控制阵列", font(32, True), navy)
centered(
    draw,
    (545, 153),
    "16个宏格均选择 H1：目标偏移 (+8 m, +8 m)",
    font(22),
    muted,
)

# Outer 4x4 macro-cell grid.
grid_x, grid_y = 120, 230
cell = 205
grid_size = 4 * cell

for col in range(4):
    x0 = grid_x + col * cell
    draw.rounded_rectangle(
        (x0 + 8, grid_y - 58, x0 + cell - 8, grid_y - 12),
        radius=12,
        fill=header_fill,
    )
    centered(draw, (x0 + cell / 2, grid_y - 35), f"A{col + 1}", font(22, True), navy)

for row in range(4):
    y0 = grid_y + row * cell
    draw.rounded_rectangle(
        (grid_x - 70, y0 + 14, grid_x - 18, y0 + cell - 14),
        radius=12,
        fill=header_fill,
    )
    centered(draw, (grid_x - 44, y0 + cell / 2), f"R{row + 1}", font(22, True), navy)

for row in range(4):
    for col in range(4):
        x0 = grid_x + col * cell
        y0 = grid_y + row * cell
        fill = cell_a if (row + col) % 2 == 0 else cell_b
        draw.rectangle((x0, y0, x0 + cell, y0 + cell), fill=fill, outline=grid_line, width=3)
        centered(draw, (x0 + cell / 2, y0 + 45), f"P{row + 1}{col + 1}", font(20, True), accent)
        centered(draw, (x0 + cell / 2, y0 + 101), "H1", font(34, True), navy)
        centered(draw, (x0 + cell / 2, y0 + 148), "(+8, +8) m", font(23, True), navy)

draw.rounded_rectangle(
    (95, 1080, 955, 1190), radius=18, fill="#F4F8FB", outline="#B8C7D1", width=2
)
centered(
    draw,
    (525, 1115),
    "每个 H1 内部均含 4×4 延迟子单元",
    font(23, True),
    navy,
)
centered(
    draw,
    (525, 1158),
    "d_r = d_a = [0, 0.10, 0.83, 0.93]T",
    font(23),
    muted,
)

# Thin visual separator between the control configuration and SAR image.
draw.line((1035, 112, 1035, 1200), fill="#D4DEE5", width=3)

# Right panel: paste the original RD image without altering its data values.
max_w, max_h = 1510, 1065
scale = min(max_w / sar.width, max_h / sar.height)
sar = sar.resize((round(sar.width * scale), round(sar.height * scale)), Image.Resampling.LANCZOS)
sar_x = 1070 + (max_w - sar.width) // 2
sar_y = 110 + (max_h - sar.height) // 2
canvas.paste(sar, (sar_x, sar_y))

canvas.save(OUTPUT, quality=96, dpi=(220, 220))
print(OUTPUT)
