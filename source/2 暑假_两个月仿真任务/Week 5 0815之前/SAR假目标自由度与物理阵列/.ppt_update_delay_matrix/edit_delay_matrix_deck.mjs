import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, PresentationFile } from "@oai/artifact-tool";

const ROOT = "<REDACTED_WORKSPACE_ROOT>/2 暑假_两个月仿真任务/Week 5 0815之前/SAR假目标自由度与物理阵列";
const TMP = path.join(ROOT, ".ppt_update_delay_matrix");
const STARTER = path.join(TMP, "template-starter.pptx");
const FINAL = path.join(ROOT, "时变2-bit超表面_SAR假目标自由度与物理阵列_时延矩阵版.pptx");
const RESULTS = path.join(ROOT, "results_full_array_exact");
const CONTROLS = path.join(RESULTS, "control_tables");
const PREVIEW = path.join(TMP, "final-preview");
const LAYOUT = path.join(TMP, "final-layout");
const SAR_CROPS = path.join(TMP, "sar-crops");

const FONT = "PingFang SC";
const C = {
  white: "#FFFFFF", ink: "#17212B", muted: "#52606D", navy: "#102A43",
  blue: "#2563EB", cyan: "#31B7E8", pale: "#EAF5FB", ice: "#F5FAFD",
  line: "#AAB7C4", green: "#159A69", orange: "#F59E0B", purple: "#7C5CE0",
};
const DELAY_TEXT = ["0", "1/10", "5/6", "14/15"];
const DELAY_ROW_COLORS = ["#DCEEFF", "#FBE4D5", "#FFF0C7", "#EADCF8"];

async function bytes(file) {
  const b = await fs.readFile(file);
  return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength);
}

async function writeBlob(file, blob) {
  await fs.writeFile(file, new Uint8Array(await blob.arrayBuffer()));
}

function addShape(slide, geometry, x, y, w, h, fill, line = C.line, radius = false, name = "") {
  return slide.shapes.add({
    geometry: radius ? "roundRect" : geometry,
    name,
    position: { left: x, top: y, width: w, height: h },
    fill,
    line: { style: "solid", fill: line, width: 1 },
  });
}

function addText(slide, text, x, y, w, h, opts = {}) {
  const t = slide.shapes.add({
    geometry: "textbox",
    name: opts.name ?? "",
    position: { left: x, top: y, width: w, height: h },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  t.text = text;
  t.text.style = {
    typeface: FONT,
    fontSize: opts.size ?? 14,
    bold: opts.bold ?? false,
    color: opts.color ?? C.ink,
    alignment: opts.align ?? "center",
    verticalAlignment: opts.valign ?? "middle",
    autoFit: opts.autoFit ?? "shrinkText",
  };
  return t;
}

function pastel(channel, count) {
  if (count <= 1) return "#DCEEFF";
  const h = ((channel - 1) * 360 / count + 205) % 360;
  const s = 56;
  const l = 84;
  const c = (1 - Math.abs(2 * l / 100 - 1)) * s / 100;
  const hp = h / 60;
  const x = c * (1 - Math.abs(hp % 2 - 1));
  let [r, g, b] = hp < 1 ? [c, x, 0] : hp < 2 ? [x, c, 0] : hp < 3 ? [0, c, x]
    : hp < 4 ? [0, x, c] : hp < 5 ? [x, 0, c] : [c, 0, x];
  const m = l / 100 - c / 2;
  const hex = (v) => Math.round((v + m) * 255).toString(16).padStart(2, "0");
  return `#${hex(r)}${hex(g)}${hex(b)}`;
}

function balancedTileMap(n, k) {
  const ids = [];
  while (ids.length < n * n) for (let v = 1; v <= k && ids.length < n * n; v++) ids.push(v);
  const map = [];
  for (let r = 0; r < n; r++) {
    const row = ids.slice(r * n, (r + 1) * n);
    if (r % 2 === 1) row.reverse();
    map.push(row);
  }
  return map;
}

async function tileMapFromCsv(file, n) {
  const lines = (await fs.readFile(file, "utf8")).trim().split(/\r?\n/).slice(1);
  const map = Array.from({ length: n }, () => Array(n).fill(1));
  for (const line of lines) {
    const [row, col, channel] = line.split(",").slice(0, 3).map(Number);
    map[row - 1][col - 1] = channel;
  }
  return map;
}

function deleteShape(slide, id) {
  const item = slide.shapes.items.find((x) => String(x.id) === String(id));
  if (item) item.delete();
}

function deleteImage(slide, id) {
  const item = slide.images.items.find((x) => String(x.id) === String(id));
  if (item) item.delete();
}

function addOuterMatrix(slide, tileMap, frame, opts = {}) {
  const n = tileMap.length;
  const k = Math.max(...tileMap.flat());
  addShape(slide, "rect", frame.x, frame.y, frame.w, frame.h, "none", "#D6DEE6", true, opts.name ?? "outer-array-panel");
  addText(slide, `① 外层 ${n}×${n} 宏格：Pᵣ꜀ → Hₖ`, frame.x + 12, frame.y + 8, frame.w - 24, 28,
    { size: 16, bold: true, color: C.navy, name: "outer-array-title" });

  const leftPad = 31;
  const topPad = 58;
  const bottomPad = 50;
  const gridSize = Math.min(frame.w - leftPad - 14, frame.h - topPad - bottomPad);
  const cell = gridSize / n;
  const gx = frame.x + leftPad;
  const gy = frame.y + topPad;
  const cellFont = n <= 4 ? 13 : n === 5 ? 11.5 : 9.2;

  for (let c = 0; c < n; c++) addText(slide, `A${c + 1}`, gx + c * cell, gy - 24, cell, 20,
    { size: n === 7 ? 10 : 12, bold: true, color: C.muted, name: `outer-col-${c + 1}` });
  for (let r = 0; r < n; r++) addText(slide, `R${r + 1}`, gx - 29, gy + r * cell, 26, cell,
    { size: n === 7 ? 10 : 12, bold: true, color: C.muted, name: `outer-row-${r + 1}` });

  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      const ch = tileMap[r][c];
      addShape(slide, "rect", gx + c * cell, gy + r * cell, cell, cell, pastel(ch, k), "#64748B", false,
        `outer-P${r + 1}${c + 1}`);
      addText(slide, `P${r + 1}${c + 1}\nH${ch}`, gx + c * cell + 2, gy + r * cell + 2, cell - 4, cell - 4,
        { size: cellFont, bold: true, color: C.ink, name: `outer-label-P${r + 1}${c + 1}` });
    }
  }
  addText(slide, "Hₖ决定该宏格使用的距离/方位调制频率", frame.x + 18, frame.y + frame.h - 38, frame.w - 36, 24,
    { size: 11.5, color: C.muted, name: "outer-frequency-note" });
}

function addInnerDelayMatrix(slide, frame, compact = false) {
  addShape(slide, "rect", frame.x, frame.y, frame.w, frame.h, "none", "#D6DEE6", true, "inner-delay-panel");
  addText(slide, "② 任取一个Pᵣ꜀：内部4×4时延", frame.x + 8, frame.y + 8, frame.w - 16, 28,
    { size: compact ? 13 : 15, bold: true, color: C.navy, name: "inner-delay-title" });

  const leftPad = compact ? 28 : 34;
  const topPad = compact ? 52 : 58;
  const bottomPad = compact ? 42 : 56;
  const gridSize = Math.min(frame.w - leftPad - 12, frame.h - topPad - bottomPad);
  const cell = gridSize / 4;
  const gx = frame.x + leftPad;
  const gy = frame.y + topPad;
  const font = compact ? 7.2 : 8.6;

  for (let c = 0; c < 4; c++) addText(slide, `A${c + 1}`, gx + c * cell, gy - 21, cell, 18,
    { size: compact ? 8.5 : 10, bold: true, color: C.muted, name: `inner-col-${c + 1}` });
  for (let r = 0; r < 4; r++) addText(slide, `R${r + 1}`, gx - leftPad + 2, gy + r * cell, leftPad - 5, cell,
    { size: compact ? 8.5 : 10, bold: true, color: C.muted, name: `inner-row-${r + 1}` });

  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      addShape(slide, "rect", gx + c * cell, gy + r * cell, cell, cell, DELAY_ROW_COLORS[r], "#64748B", false,
        `inner-P${r + 1}${c + 1}`);
      addText(slide, `P${r + 1}${c + 1}\ndᵣ=${DELAY_TEXT[r]}\ndₐ=${DELAY_TEXT[c]}`,
        gx + c * cell + 1, gy + r * cell + 1, cell - 2, cell - 2,
        { size: font, bold: r === 0 && c === 0, color: C.ink, name: `inner-label-P${r + 1}${c + 1}` });
    }
  }
  addText(slide, "实际时延：tᵣ=dᵣTᵣ，tₐ=dₐTₐ", frame.x + 10, frame.y + frame.h - 36, frame.w - 20, 22,
    { size: compact ? 9.5 : 11, bold: true, color: C.purple, name: "inner-delay-note" });
}

async function addCroppedSar(slide, imagePath, frame, title = "完整原始回波RD结果") {
  addShape(slide, "rect", frame.x, frame.y, frame.w, frame.h, "none", "#D6DEE6", true, "sar-panel");
  addText(slide, `③ ${title}`, frame.x + 10, frame.y + 8, frame.w - 20, 28,
    { size: 15, bold: true, color: C.navy, name: "sar-panel-title" });
  slide.images.add({
    blob: await bytes(imagePath), contentType: "image/png", alt: title,
    fit: "contain",
    position: { left: frame.x + 8, top: frame.y + 42, width: frame.w - 16, height: frame.h - 50 },
    name: "cropped-sar-result",
  });
}

function updateFooter(slide, text) {
  const footer = slide.shapes.items.find((s) => s.frame?.top >= 660 && s.frame?.left < 1000 && s.text?.toString?.().trim());
  if (footer) footer.text = text;
}

function replaceShapeText(slide, id, before, after) {
  const shape = slide.shapes.items.find((x) => String(x.id) === String(id));
  if (shape?.text?.replace) shape.text.replace(before, after);
}

async function editWideSlide(deck, slideNo, n, k, imageName, tileMap = null) {
  const slide = deck.slides.items[slideNo - 1];
  deleteShape(slide, "5");
  deleteImage(slide, "9");
  const map = tileMap ?? balancedTileMap(n, k);
  addOuterMatrix(slide, map, { x: 42, y: 140, w: 468, h: 476 });
  addInnerDelayMatrix(slide, { x: 522, y: 140, w: 300, h: 476 });
  const sarFile = path.join(SAR_CROPS, imageName.replace(/\.png$/i, "_sar.png"));
  await addCroppedSar(slide, sarFile, { x: 834, y: 140, w: 404, h: 476 });
  updateFooter(slide, `外层${n}×${n}宏格逐格给出Pᵣ꜀与Hₖ；每个Pᵣ꜀内部都严格重复中间4×4的(dᵣ,dₐ)时延矩阵。`);
}

async function main() {
  await fs.mkdir(PREVIEW, { recursive: true });
  await fs.mkdir(LAYOUT, { recursive: true });
  const deck = await PresentationFile.importPptx(await FileBlob.load(STARTER));

  await editWideSlide(deck, 13, 4, 4, "physical_4x4_system_pair.png");
  await editWideSlide(deck, 14, 5, 5, "physical_5x5_system_pair.png");
  replaceShapeText(deck.slides.items[13], "2",
    "5×5外层控制阵列：25个宏格恰好均分给5个目标通道",
    "5×5外层阵列：25个宏格均分给5个目标通道");

  {
    const slide = deck.slides.items[14];
    deleteShape(slide, "5");
    deleteImage(slide, "17");
    addOuterMatrix(slide, balancedTileMap(7, 9), { x: 42, y: 142, w: 390, h: 454 });
    addInnerDelayMatrix(slide, { x: 444, y: 142, w: 238, h: 454 }, true);
    replaceShapeText(slide, "15",
      "右图保留3000散射点的高分辨率完整RD结果，作为精度交叉验证。",
      "右图为3000散射点高分辨率完整RD结果，用于精度交叉验证");
  }

  const heartMap = await tileMapFromCsv(path.join(CONTROLS, "shape_heart_7x7_tiles.csv"), 7);
  const arrowMap = await tileMapFromCsv(path.join(CONTROLS, "shape_arrow_7x7_tiles.csv"), 7);
  await editWideSlide(deck, 16, 7, 28, "arbitrary_heart_pair.png", heartMap);
  await editWideSlide(deck, 17, 7, 29, "arbitrary_arrow_pair.png", arrowMap);

  {
    const slide = deck.slides.items[17];
    deleteShape(slide, "5");
    deleteImage(slide, "12");
    const phoneMap = await tileMapFromCsv(path.join(CONTROLS, "shape_phone_7x7_tiles.csv"), 7);
    addOuterMatrix(slide, phoneMap, { x: 42, y: 150, w: 378, h: 448 });
    addInnerDelayMatrix(slide, { x: 432, y: 150, w: 292, h: 250 }, true);
    await addCroppedSar(slide, path.join(SAR_CROPS, "arbitrary_phone_pair_sar.png"), { x: 432, y: 412, w: 292, h: 186 }, "手机草图SAR结果");
    updateFooter(slide, "手机图片先编译成7×7的Pᵣ꜀→Hₖ表，再为每个宏格展开同一套4×4时延子矩阵并生成2-bit控制序列。即换图、不换硬件。 ");
  }

  for (let i = 0; i < deck.slides.items.length; i++) {
    const slide = deck.slides.items[i];
    const stem = `slide-${String(i + 1).padStart(2, "0")}`;
    await writeBlob(path.join(PREVIEW, `${stem}.png`), await deck.export({ slide, format: "png", scale: 1 }));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(LAYOUT, `${stem}.layout.json`), await layout.text());
  }
  const pptx = await PresentationFile.exportPptx(deck);
  await pptx.save(FINAL);
  console.log(`PPTX=${FINAL}`);
  console.log(`SLIDES=${deck.slides.items.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
