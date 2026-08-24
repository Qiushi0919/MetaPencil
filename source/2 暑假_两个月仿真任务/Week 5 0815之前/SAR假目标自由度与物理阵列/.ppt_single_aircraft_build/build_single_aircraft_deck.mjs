import fs from "node:fs/promises";
import path from "node:path";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const ROOT = "<REDACTED_WORKSPACE_ROOT>/2 暑假_两个月仿真任务/Week 5 0815之前/SAR假目标自由度与物理阵列";
const IMAGE_DIR = path.join(ROOT, "single_aircraft_redesign_figures");
const RESULT_DIR = path.join(ROOT, "results_full_array_exact");
const BUILD_DIR = path.join(ROOT, ".ppt_single_aircraft_build");
const CROP_DIR = path.join(BUILD_DIR, "crops");
const PREVIEW_DIR = path.join(BUILD_DIR, "rendered");
const OUTPUT = path.join(ROOT, "单架_双机_四机_假目标自由度与2bit计算.pptx");

const C = {
  navy: "#17324D",
  text: "#29445C",
  muted: "#667E91",
  blue: "#1769AA",
  blueBg: "#DCEEFF",
  orange: "#C45122",
  orangeBg: "#FFE3D5",
  green: "#247645",
  greenBg: "#DFF2E3",
  purple: "#6B4BA1",
  purpleBg: "#EBE2F6",
  cyan: "#087C78",
  cyanBg: "#D8F1F0",
  gold: "#9A6A00",
  goldBg: "#FFF0C7",
  red: "#B63E32",
  redBg: "#F9DFDC",
  line: "#B8CAD7",
  panel: "#F6F9FB",
  white: "#FFFFFF",
};

const palette = [C.blueBg, C.orangeBg, C.greenBg, C.purpleBg];
const accent = [C.blue, C.orange, C.green, C.purple];

async function readBytes(file) {
  const buffer = await fs.readFile(file);
  return new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.byteLength);
}

async function writeBlob(file, blob) {
  await fs.writeFile(file, new Uint8Array(await blob.arrayBuffer()));
}

function addBox(slide, x, y, w, h, fill, line = C.line, radius = 14) {
  return slide.shapes.add({
    geometry: radius > 0 ? "roundRect" : "rect",
    position: { left: x, top: y, width: w, height: h },
    fill,
    line: { style: "solid", fill: line, width: 1.3 },
    ...(radius > 0 ? { borderRadius: radius } : {}),
  });
}

function addText(slide, text, x, y, w, h, size = 22, color = C.text, bold = false, align = "left") {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position: { left: x, top: y, width: w, height: h },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontSize: size,
    color,
    bold,
    alignment: align,
    verticalAlignment: "middle",
    autoFit: "shrinkText",
    wrap: "square",
    insets: { left: 2, right: 2, top: 0, bottom: 0 },
  };
  return shape;
}

function esc(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function formulaSvg(parts, width, height, fontSize = 30, defaultColor = C.text, align = "left") {
  const anchor = align === "center" ? "middle" : "start";
  const x = align === "center" ? width / 2 : 5;
  const tspans = parts.map((part) => {
    const shift = part.sub ? ' baseline-shift="sub"' : part.sup ? ' baseline-shift="super"' : "";
    const size = part.sub || part.sup ? Math.round(fontSize * 0.64) : fontSize;
    const weight = part.bold ? "700" : "400";
    const style = part.italic ? "italic" : "normal";
    return `<tspan${shift} font-size="${size}" font-weight="${weight}" font-style="${style}" fill="${part.color || defaultColor}">${esc(part.text)}</tspan>`;
  }).join("");
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}"><rect width="100%" height="100%" fill="none"/><text x="${x}" y="${Math.round(height * 0.66)}" text-anchor="${anchor}" font-family="Cambria Math,Times New Roman,Arial,sans-serif">${tspans}</text></svg>`;
}

function addFormula(slide, parts, x, y, w, h, size = 30, color = C.text, align = "left", alt = "formula") {
  const svg = formulaSvg(parts, w * 2, h * 2, size * 2, color, align);
  return slide.images.add({
    blob: Buffer.from(svg),
    contentType: "image/svg+xml",
    alt,
    fit: "contain",
    position: { left: x, top: y, width: w, height: h },
  });
}

function addTitle(slide, title, subtitle = "") {
  slide.background.fill = C.white;
  slide.shapes.add({
    geometry: "rect",
    position: { left: 0, top: 0, width: 1280, height: 7 },
    fill: C.blue,
    line: { style: "solid", fill: C.blue, width: 0 },
  });
  addText(slide, title, 44, 18, 1192, 54, 45, C.navy, true);
  slide.shapes.add({
    geometry: "line",
    position: { left: 44, top: 77, width: 1192, height: 0 },
    fill: "none",
    line: { style: "solid", fill: C.line, width: 1.5 },
  });
  if (subtitle) addText(slide, subtitle, 44, 81, 1192, 34, 20, C.muted, false);
}

function setNotes(slide, localSources) {
  slide.speakerNotes.textFrame.setText(`[Sources]\n${localSources.map((s) => `- ${s}`).join("\n")}`);
}

function addHkStructureSlide(pres) {
  const slide = pres.slides.add();
  addTitle(slide, "Hk是一条完整的假目标通道", "所有Hk共用同一套4×4内部延迟模板；目标位置由时间调制频率和方向决定");

  // Connectors first so they stay behind the panels.
  addText(slide, "→", 322, 350, 35, 35, 30, C.muted, true, "center");
  addText(slide, "→", 826, 350, 35, 35, 30, C.muted, true, "center");

  addBox(slide, 42, 128, 280, 492, C.panel);
  addText(slide, "1  定义通道Hk", 66, 145, 232, 36, 25, C.navy, true, "center");
  addFormula(slide, [
    { text: "H", italic: true, color: C.blue }, { text: "k", sub: true, italic: true, color: C.blue },
    { text: "  =  (" }, { text: "Δr", italic: true }, { text: "k", sub: true, italic: true },
    { text: ", " }, { text: "Δa", italic: true }, { text: "k", sub: true, italic: true }, { text: ")" },
  ], 70, 194, 225, 48, 29, C.text, "center", "Hk maps to target range and azimuth offsets");
  addText(slide, "指定SAR中的假目标中心", 68, 241, 224, 30, 19, C.muted, false, "center");

  addBox(slide, 70, 292, 224, 128, C.blueBg, C.blue, 12);
  addText(slide, "H1", 82, 301, 200, 34, 27, C.blue, true, "center");
  addText(slide, "目标 (-8, +8) m", 82, 337, 200, 27, 19, C.text, true, "center");
  addFormula(slide, [
    { text: "f", italic: true }, { text: "r,1", sub: true, italic: true }, { text: " = +32 MHz" },
  ], 90, 363, 185, 26, 21, C.text, "center", "range modulation frequency plus 32 megahertz");
  addFormula(slide, [
    { text: "f", italic: true }, { text: "a,1", sub: true, italic: true }, { text: " = +42.67 Hz" },
  ], 90, 389, 185, 26, 21, C.text, "center", "azimuth modulation frequency plus 42.67 hertz");

  addBox(slide, 70, 445, 224, 128, C.orangeBg, C.orange, 12);
  addText(slide, "H2", 82, 454, 200, 34, 27, C.orange, true, "center");
  addText(slide, "目标 (+8, +8) m", 82, 490, 200, 27, 19, C.text, true, "center");
  addFormula(slide, [
    { text: "f", italic: true }, { text: "r,2", sub: true, italic: true }, { text: " = -32 MHz" },
  ], 90, 516, 185, 26, 21, C.text, "center", "range modulation frequency minus 32 megahertz");
  addFormula(slide, [
    { text: "f", italic: true }, { text: "a,2", sub: true, italic: true }, { text: " = +42.67 Hz" },
  ], 90, 542, 185, 26, 21, C.text, "center", "azimuth modulation frequency plus 42.67 hertz");
  addText(slide, "H1与H2的内部结构相同", 65, 582, 235, 24, 18, C.red, true, "center");

  addBox(slide, 346, 128, 480, 492, "#FBFCFD");
  addText(slide, "2  Hk内部：4×4延迟子单元", 370, 145, 432, 36, 25, C.navy, true, "center");
  addText(slide, "行：距离延迟    列：方位延迟", 370, 180, 432, 29, 19, C.muted, false, "center");
  const delays = ["0", "1/10", "5/6", "14/15"];
  const gx = 431, gy = 250, cell = 78;
  for (let c = 0; c < 4; c++) {
    addText(slide, `A${c + 1}`, gx + c * cell, 216, cell, 24, 18, C.navy, true, "center");
    addFormula(slide, [
      { text: "d", italic: true }, { text: "a", sub: true, italic: true }, { text: `=${delays[c]}T` },
    ], gx + c * cell, 235, cell, 22, 15, C.muted, "center", "azimuth delay fraction");
  }
  for (let r = 0; r < 4; r++) {
    addText(slide, `R${r + 1}`, 370, gy + r * cell + 16, 54, 24, 18, C.navy, true, "center");
    addFormula(slide, [
      { text: "d", italic: true }, { text: "r", sub: true, italic: true }, { text: `=${delays[r]}T` },
    ], 366, gy + r * cell + 39, 62, 22, 14, C.muted, "center", "range delay fraction");
    for (let c = 0; c < 4; c++) {
      addBox(slide, gx + c * cell, gy + r * cell, cell, cell, palette[(r + c) % 4], "#7890A2", 0);
      addText(slide, `P${r + 1}${c + 1}`, gx + c * cell, gy + r * cell + 5, cell, 22, 16, accent[(r + c) % 4], true, "center");
      addText(slide, `(${delays[r]},`, gx + c * cell, gy + r * cell + 28, cell, 21, 15, C.text, false, "center");
      addText(slide, `${delays[c]})T`, gx + c * cell, gy + r * cell + 49, cell, 21, 15, C.text, false, "center");
    }
  }
  addText(slide, "同一内部矩阵重复用于H1、H2、...", 390, 573, 390, 26, 19, C.green, true, "center");

  addBox(slide, 850, 128, 388, 492, C.panel);
  addText(slide, "3  形成2-bit时变反射", 875, 145, 338, 36, 25, C.navy, true, "center");
  addText(slide, "每个子单元只有四种反射相位", 875, 181, 338, 28, 19, C.muted, false, "center");
  const phaseLabels = ["0°", "90°", "180°", "270°"];
  const phaseFills = [C.blueBg, C.greenBg, C.orangeBg, C.purpleBg];
  const phaseLines = [C.blue, C.green, C.orange, C.purple];
  for (let i = 0; i < 4; i++) {
    addBox(slide, 876 + i * 84, 229, 70, 54, phaseFills[i], phaseLines[i], 9);
    addText(slide, phaseLabels[i], 876 + i * 84, 237, 70, 38, 20, phaseLines[i], true, "center");
  }
  addText(slide, "延迟改变序列起点", 878, 314, 330, 28, 21, C.green, true, "center");
  addText(slide, "Hk改变两个调制频率", 878, 350, 330, 26, 20, C.red, true, "center");
  addFormula(slide, [
    { text: "f", italic: true, color: C.blue }, { text: "r,k", sub: true, italic: true, color: C.blue },
    { text: "    ,    " }, { text: "f", italic: true, color: C.orange }, { text: "a,k", sub: true, italic: true, color: C.orange },
  ], 900, 377, 285, 32, 24, C.text, "center", "range and azimuth modulation frequencies");
  addText(slide, "从而决定回波搬移到哪里", 878, 410, 330, 29, 20, C.muted, false, "center");
  addBox(slide, 894, 459, 298, 105, "#EAF5FC", "#65A9D3", 12);
  addText(slide, "原始飞机回波", 914, 469, 258, 27, 20, C.navy, true, "center");
  addText(slide, "×  Hk的2-bit反射系数", 914, 497, 258, 27, 19, C.text, false, "center");
  addText(slide, "产生SAR假目标", 930, 523, 150, 30, 18, C.blue, true, "center");
  addFormula(slide, [
    { text: "(" }, { text: "Δr", italic: true }, { text: "k", sub: true, italic: true },
    { text: ", " }, { text: "Δa", italic: true }, { text: "k", sub: true, italic: true }, { text: ")" },
  ], 1075, 525, 100, 28, 18, C.blue, "center", "target range and azimuth offset");

  addBox(slide, 42, 642, 1196, 55, "#EEF6FB", "#9FC1D7", 10);
  addText(slide, "空间编码：哪个宏格分配哪个Hk    |    时间编码：Hk采用什么调制频率、方向和2-bit相位序列", 70, 649, 1140, 38, 21, C.navy, true, "center");
  setNotes(slide, [
    "Local MATLAB model: run_full_array_freedom_study.m",
    "Local control tables: results_full_array_exact/control_tables/single_1to2_channels.csv",
  ]);
}

async function addImageSlide(pres, filename, alt, sourceLabel) {
  const slide = pres.slides.add();
  slide.background.fill = C.white;
  const bytes = await readBytes(path.join(IMAGE_DIR, filename));
  slide.images.add({
    blob: bytes,
    contentType: "image/png",
    alt,
    fit: "contain",
    position: { left: 0, top: 0, width: 1280, height: 720 },
  });
  setNotes(slide, [sourceLabel, "Local MATLAB model: run_full_array_freedom_study.m"]);
}

async function addResultImageSlide(pres, filename, alt, sourceLabel) {
  const slide = pres.slides.add();
  slide.background.fill = C.white;
  const bytes = await readBytes(path.join(RESULT_DIR, filename));
  slide.images.add({
    blob: bytes,
    contentType: "image/png",
    alt,
    fit: "contain",
    position: { left: 0, top: 0, width: 1280, height: 720 },
  });
  setNotes(slide, [sourceLabel, "Local MATLAB model: run_full_array_freedom_study.m"]);
}

async function addTwoAircraftCaseSlide(pres, title, subtitle, cropFile, accentColor, sourceLabel) {
  const slide = pres.slides.add();
  addTitle(slide, title, subtitle);
  const bytes = await readBytes(path.join(CROP_DIR, cropFile));
  addBox(slide, 44, 121, 760, 558, "#071018", accentColor, 12);
  slide.images.add({
    blob: bytes,
    contentType: "image/png",
    alt: title,
    fit: "contain",
    position: { left: 54, top: 131, width: 740, height: 538 },
  });
  addBox(slide, 830, 136, 406, 515, C.panel, accentColor, 14);
  addText(slide, "读图要点", 854, 159, 358, 38, 27, accentColor, true, "center");
  addFormula(slide, [
    { text: "T = (S" }, { text: "1", sub: true }, { text: " + K" }, { text: "1", sub: true },
    { text: ")  U  (S" }, { text: "2", sub: true }, { text: " + K" }, { text: "2", sub: true }, { text: ")" },
  ], 864, 210, 338, 42, 25, C.navy, "center", "two-aircraft target union equation");
  addBox(slide, 866, 279, 334, 184, "#FFFFFF", accentColor, 10);
  addText(slide, sourceLabel, 887, 297, 292, 146, 22, C.text, true, "center");
  addBox(slide, 866, 491, 334, 121, "#EAF5FC", "#8FBAD5", 10);
  addText(slide, "蓝框：两架真实飞机\n橙色圆点：编译后的目标中心\n灰白飞机像：完整RD成像结果", 884, 505, 298, 92, 19, C.navy, false, "center");
  setNotes(slide, ["Local figure: results_full_array_exact/two_aircraft_line_freedom.png", "Local MATLAB model: run_full_array_freedom_study.m"]);
}

function addDot(slide, cx, cy, radius, fill, line = fill) {
  slide.shapes.add({
    geometry: "ellipse",
    position: { left: cx - radius, top: cy - radius, width: 2 * radius, height: 2 * radius },
    fill,
    line: { style: "solid", fill: line, width: 1.2 },
  });
}

function addPlaneMarker(slide, x, y, color, label = "") {
  addDot(slide, x, y, 9, color, color);
  slide.shapes.add({
    geometry: "line",
    position: { left: x - 15, top: y, width: 30, height: 0 },
    fill: "none",
    line: { style: "solid", fill: color, width: 2.3 },
  });
  slide.shapes.add({
    geometry: "line",
    position: { left: x, top: y - 15, width: 0, height: 30 },
    fill: "none",
    line: { style: "solid", fill: color, width: 2.3 },
  });
  if (label) addText(slide, label, x - 35, y + 18, 70, 24, 16, color, true, "center");
}

function addTwoAircraftPrincipleSlide(pres) {
  const slide = pres.slides.add();
  addTitle(slide, "两架真实飞机：自由度来自每架飞机的通道核Ki", "同一真实编队可以选择共享码本、相干重叠或独立码本；所有目标都由原始回波乘时变反射系数得到");

  addBox(slide, 42, 126, 1196, 89, "#EEF6FB", "#8FBAD5", 12);
  addFormula(slide, [
    { text: "S = {S" }, { text: "1", sub: true }, { text: ", S" }, { text: "2", sub: true },
    { text: "}       T = " }, { text: "∪", color: C.blue, bold: true }, { text: "  (S" },
    { text: "i", sub: true, italic: true }, { text: " + K" }, { text: "i", sub: true, italic: true }, { text: ")" },
  ], 75, 143, 470, 45, 28, C.navy, "center", "target set is the union of each source aircraft plus its coding kernel");
  addText(slide, "S：真实飞机位置    K：该飞机的假目标偏移集合    T：最终SAR目标集合", 550, 142, 650, 46, 21, C.text, true, "center");

  const cards = [
    { x: 42, color: C.blue, bg: C.blueBg, title: "共享码本", sub: "K1 = K2", desc: "同一个核平移到两架飞机处\n规则重复、结构最清楚", mode: 0 },
    { x: 448, color: C.orange, bg: C.orangeBg, title: "相干重叠", sub: "S1+K1 与 S2+K2 重合", desc: "同一像素接收两路复回波\n可增强指定假目标", mode: 1 },
    { x: 854, color: C.purple, bg: C.purpleBg, title: "独立码本", sub: "K1 ≠ K2", desc: "每架飞机生成不同子编队\n可做非对称、折线、V形", mode: 2 },
  ];
  for (const card of cards) {
    addBox(slide, card.x, 238, 384, 414, card.bg, card.color, 14);
    addText(slide, card.title, card.x + 20, 253, 344, 34, 27, card.color, true, "center");
    addText(slide, card.sub, card.x + 20, 290, 344, 28, 20, C.navy, true, "center");
    const x0 = card.x + 192;
    addPlaneMarker(slide, x0 - 72, 414, C.cyan, "S1");
    addPlaneMarker(slide, x0 + 72, 414, C.cyan, "S2");
    if (card.mode === 0) {
      for (const x of [x0 - 120, x0 - 24, x0 + 24, x0 + 120]) addDot(slide, x, 349, 8, C.blue);
    } else if (card.mode === 1) {
      for (const x of [x0 - 120, x0 - 48, x0, x0 + 48, x0 + 120]) addDot(slide, x, 349, x === x0 ? 13 : 8, x === x0 ? C.red : C.orange);
      addText(slide, "重叠点幅度增强", x0 - 90, 318, 180, 24, 16, C.red, true, "center");
    } else {
      for (const [dx, dy] of [[-120,-50],[-72,-86],[-24,-50],[24,50],[72,86],[120,50]]) addDot(slide, x0 + dx, 370 + dy, 8, C.purple);
    }
    addText(slide, card.desc, card.x + 30, 508, 324, 75, 20, C.text, false, "center");
    addText(slide, "真实飞机", card.x + 112, 596, 160, 24, 16, C.cyan, true, "center");
  }
  setNotes(slide, ["Local MATLAB model: run_full_array_freedom_study.m, Section 5", "Local result: results_full_array_exact/two_aircraft_line_freedom.png"]);
}

function addFourAircraftPrincipleSlide(pres) {
  const slide = pres.slides.add();
  addTitle(slide, "四架真实飞机：每架使用四通道核，合成4×4共16架目标群", "四架飞机位于大方框四角；每架分别向内生成0阶、距离位移、方位位移和二维位移四个通道");
  addBox(slide, 42, 128, 486, 523, C.panel);
  addText(slide, "四架真实飞机 S", 65, 144, 440, 34, 26, C.navy, true, "center");
  const sx = [155, 415, 155, 415], sy = [260, 260, 525, 525];
  for (let i = 0; i < 4; i++) addPlaneMarker(slide, sx[i], sy[i], C.cyan, `S${i + 1}`);
  slide.shapes.add({ geometry: "rect", position: { left: 137, top: 242, width: 296, height: 301 }, fill: "none", line: { style: "dash", fill: C.cyan, width: 2 } });
  addText(slide, "四角实机间距可按实验场景设置", 90, 584, 390, 34, 19, C.muted, false, "center");

  addText(slide, "+  每架的四通道Ki", 548, 144, 270, 34, 26, C.navy, true, "center");
  addBox(slide, 575, 223, 220, 220, C.blueBg, C.blue, 12);
  for (const [dx, dy, lab] of [[-58,-58,"(0,0)"],[58,-58,"(±8,0)"],[-58,58,"(0,±8)"],[58,58,"(±8,±8)"]]) {
    addDot(slide, 685 + dx, 333 + dy, 10, C.blue);
    addText(slide, lab, 685 + dx - 46, 333 + dy + 16, 92, 23, 15, C.text, true, "center");
  }
  addText(slide, "每架根据所在象限\n选择“向内”的正负号", 566, 474, 238, 62, 20, C.orange, true, "center");

  addText(slide, "=  最终SAR目标 T", 837, 144, 360, 34, 26, C.navy, true, "center");
  addBox(slide, 864, 207, 320, 350, "#F7FBFD", C.green, 12);
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      addDot(slide, 920 + c * 70, 265 + r * 70, 10, C.green);
    }
  }
  addText(slide, "4×4 = 16个清晰目标中心", 874, 520, 300, 30, 21, C.green, true, "center");
  addBox(slide, 548, 575, 650, 67, "#FFF7E8", "#E0B45A", 10);
  addText(slide, "自由度：四架可以共用同一个核，也可以分别设置Ki；后者能把16个点重新编译成更一般的二维形状。", 566, 584, 614, 46, 20, C.text, true, "center");
  setNotes(slide, ["Local MATLAB model: run_full_array_freedom_study.m, Section 6", "Local result: results_full_array_exact/four_aircraft_7x7_to16_pair.png"]);
}

function addFreedomSummarySlide(pres) {
  const slide = pres.slides.add();
  addTitle(slide, "从“飞机数量”到“任意形状”的可编程自由度", "真实飞机只决定基底位置；外层宏格分配通道，Hk决定位置，宏格数量决定幅度，内部延迟组负责高阶谐波相消");
  const rows = [
    ["1架飞机", "单一或多个Hk", "1→1 / 2 / 3 / 4 / 5 / 9 / 16", "规则阵列、十字、局部编队"],
    ["2架飞机", "共享K", "复制同一核", "线阵、等间距编队、相干增强"],
    ["2架飞机", "独立K1、K2", "两个不同子图的并集", "非对称编队、V形、折线"],
    ["4架飞机", "共享或独立Ki", "四个子图并集", "4×4机群、环形、字母轮廓"],
    ["任意输入", "手机草图→7×7掩模", "每个亮点编译为一个Hk", "心形、箭头、Z及更一般点阵"],
  ];
  const x = [44, 252, 486, 796], w = [208, 234, 310, 440];
  const heads = ["真实载体", "码本关系", "可控目标集合", "已体现/可扩展形状"];
  for (let i = 0; i < 4; i++) {
    addBox(slide, x[i], 132, w[i], 52, C.navy, C.navy, 0);
    addText(slide, heads[i], x[i] + 6, 140, w[i] - 12, 34, 21, C.white, true, "center");
  }
  rows.forEach((row, r) => {
    const fill = r % 2 === 0 ? "#F4F8FB" : "#FFFFFF";
    for (let c = 0; c < 4; c++) {
      addBox(slide, x[c], 184 + r * 79, w[c], 79, fill, C.line, 0);
      addText(slide, row[c], x[c] + 10, 194 + r * 79, w[c] - 20, 57, c === 3 ? 19 : 20, c === 0 ? C.blue : C.text, c === 0, "center");
    }
  });
  addBox(slide, 44, 602, 1192, 78, "#EAF5FC", "#65A9D3", 12);
  addFormula(slide, [
    { text: "T = U" }, { text: "i", sub: true, italic: true }, { text: " (S" },
    { text: "i", sub: true, italic: true }, { text: " + K" },
    { text: "i", sub: true, italic: true }, { text: ")" },
  ], 92, 612, 300, 43, 29, C.navy, "center", "final target set is the union of source aircraft plus programmable coding kernels");
  addText(slide, "U表示对所有飞机结果取并集", 395, 615, 250, 38, 19, C.blue, true, "center");
  addText(slide, "位置自由度：fr、fa    |    幅度自由度：宏格占比    |    形状自由度：Hk集合    |    纯净度：延迟分区相消", 660, 614, 542, 48, 20, C.text, true, "center");
  setNotes(slide, ["Local MATLAB model: run_full_array_freedom_study.m", "Local results directory: results_full_array_exact"]);
}

function addCalculationSlide(pres) {
  const slide = pres.slides.add();
  addTitle(slide, "一次完整计算：(+8 m, +8 m)如何变成2-bit状态11", "示例采用H1与内部子单元P23；代码先分别量化距离、方位相位，再把两个反射系数相乘");

  // Step 1: target displacement to modulation frequency.
  addBox(slide, 42, 128, 578, 178, "#F8FAFC");
  addText(slide, "1  目标偏移 → 调制频率", 62, 140, 538, 32, 25, C.navy, true);
  addFormula(slide, [
    { text: "Δr", italic: true, color: C.blue }, { text: "1", sub: true, italic: true, color: C.blue },
    { text: " = +8 m,    ΔR = Δr" }, { text: "1", sub: true, italic: true },
    { text: " sin 60° = 6.928 m" },
  ], 66, 181, 530, 36, 24, C.text, "left", "ground range offset and slant range offset");
  addFormula(slide, [
    { text: "f", italic: true, color: C.blue }, { text: "r,1", sub: true, italic: true, color: C.blue },
    { text: " = -2K" }, { text: "r", sub: true, italic: true }, { text: "ΔR/c = -32 MHz" },
  ], 66, 221, 530, 36, 25, C.text, "left", "range modulation frequency calculation");
  addFormula(slide, [
    { text: "Δa", italic: true, color: C.orange }, { text: "1", sub: true, italic: true, color: C.orange },
    { text: " = +8 m,    " }, { text: "f", italic: true, color: C.orange },
    { text: "a,1", sub: true, italic: true, color: C.orange }, { text: " = -K" },
    { text: "a", sub: true, italic: true }, { text: "Δa" }, { text: "1", sub: true, italic: true },
    { text: "/v = +42.67 Hz" },
  ], 66, 261, 530, 36, 24, C.text, "left", "azimuth modulation frequency calculation");

  // Step 2: periods and selected time delays.
  addBox(slide, 660, 128, 578, 178, "#F8FAFC");
  addText(slide, "2  选择P23的距离/方位时延", 680, 140, 538, 32, 25, C.navy, true);
  addFormula(slide, [
    { text: "T", italic: true, color: C.blue }, { text: "r", sub: true, italic: true, color: C.blue },
    { text: " = 1/|f" }, { text: "r,1", sub: true, italic: true }, { text: "| = 31.25 ns" },
  ], 684, 181, 520, 34, 23, C.text, "left", "range modulation period");
  addFormula(slide, [
    { text: "d", italic: true, color: C.green }, { text: "r", sub: true, italic: true, color: C.green },
    { text: " = 1/10  =>  t" }, { text: "delay,r", sub: true, italic: true }, { text: " = 3.125 ns" },
  ], 684, 219, 520, 34, 23, C.text, "left", "range delay for P23");
  addFormula(slide, [
    { text: "T", italic: true, color: C.orange }, { text: "a", sub: true, italic: true, color: C.orange },
    { text: " = 1/|f" }, { text: "a,1", sub: true, italic: true }, { text: "| = 23.438 ms" },
  ], 684, 257, 520, 34, 23, C.text, "left", "azimuth modulation period");
  addFormula(slide, [
    { text: "d", italic: true, color: C.purple }, { text: "a", sub: true, italic: true, color: C.purple },
    { text: " = 5/6  =>  t" }, { text: "delay,a", sub: true, italic: true }, { text: " = 19.531 ms" },
  ], 684, 281, 520, 26, 21, C.text, "left", "azimuth delay for P23");

  // Step 3: pick an instant and calculate the two continuous phases.
  addBox(slide, 42, 329, 1196, 184, "#FBFCFD");
  addText(slide, "3  选取一个快/慢时间采样点，分别计算连续相位", 62, 341, 1156, 34, 25, C.navy, true);
  addFormula(slide, [
    { text: "t", italic: true, color: C.cyan }, { text: "fast", sub: true, color: C.cyan },
    { text: " = 0.30T", color: C.cyan }, { text: "r", sub: true, color: C.cyan },
    { text: " = 9.375 ns", color: C.cyan },
    { text: "          t", italic: true, color: C.gold }, { text: "slow", sub: true, color: C.gold },
    { text: " = 0.20T", color: C.gold }, { text: "a", sub: true, color: C.gold },
    { text: " = 4.688 ms", color: C.gold },
  ], 72, 382, 1136, 38, 24, C.text, "center", "selected fast and slow time samples");
  addFormula(slide, [
    { text: "φ", italic: true, color: C.blue }, { text: "r", sub: true, italic: true, color: C.blue },
    { text: " = 360°[" }, { text: "-0.30", color: C.cyan, bold: true },
    { text: " - " }, { text: "0.10", color: C.green, bold: true },
    { text: "] = -144°" },
  ], 88, 424, 500, 34, 25, C.text, "left", "continuous range phase");
  addFormula(slide, [
    { text: "mod 360° = " }, { text: "216°", color: C.blue, bold: true },
  ], 88, 456, 500, 28, 22, C.text, "center", "range phase modulo 360 degrees");
  addFormula(slide, [
    { text: "φ", italic: true, color: C.orange }, { text: "a", sub: true, italic: true, color: C.orange },
    { text: " = 360°[" }, { text: "+0.20", color: C.gold, bold: true },
    { text: " - " }, { text: "5/6", color: C.purple, bold: true },
    { text: "] = -228°" },
  ], 674, 424, 500, 34, 25, C.text, "left", "continuous azimuth phase");
  addFormula(slide, [
    { text: "mod 360° = " }, { text: "132°", color: C.orange, bold: true },
  ], 674, 456, 500, 28, 22, C.text, "center", "azimuth phase modulo 360 degrees");
  addText(slide, "蓝/橙：目标偏移形成的调制项", 92, 486, 420, 21, 17, C.muted, false, "center");
  addText(slide, "绿/紫：P23引入的距离与方位延迟项", 716, 486, 440, 21, 17, C.muted, false, "center");

  // Step 4: 2-bit quantization and final output angle.
  addBox(slide, 42, 536, 1196, 160, "#EEF6FB", "#8FBAD5", 14);
  addText(slide, "4  量化为四种相位状态并相乘", 62, 547, 1156, 32, 25, C.navy, true);
  addFormula(slide, [
    { text: "Q", italic: true }, { text: "2", sub: true }, { text: "(216°) = " },
    { text: "180°  (10)", color: C.blue, bold: true },
    { text: "        Q" }, { text: "2", sub: true }, { text: "(132°) = " },
    { text: "90°  (01)", color: C.orange, bold: true },
  ], 76, 584, 1128, 38, 26, C.text, "center", "two bit quantization of range and azimuth phases");
  addFormula(slide, [
    { text: "φ", italic: true, color: C.red }, { text: "out", sub: true, italic: true, color: C.red },
    { text: " = (180° + 90°) mod 360° = " },
    { text: "270°", color: C.red, bold: true }, { text: "   =>   2-bit = " },
    { text: "11", color: C.red, bold: true },
  ], 76, 630, 1128, 44, 29, C.text, "center", "final metasurface output reflection phase 270 degrees state 11");
  setNotes(slide, [
    "Local MATLAB parameters and quantizer: run_full_array_freedom_study.m",
    "Local channel values: results_full_array_exact/control_tables/single_1to1_channels.csv",
    "Calculation uses P23 with d_r=1/10 and d_a=5/6 at tau=0.30T_r and eta=0.20T_a.",
  ]);
}

async function main() {
  await fs.mkdir(PREVIEW_DIR, { recursive: true });
  const pres = Presentation.create({ slideSize: { width: 1280, height: 720 } });

  addHkStructureSlide(pres);
  const cases = [
    ["1to1_high_contrast.png", "Single aircraft generates one false target", "Local figure: single_aircraft_redesign_figures/1to1_high_contrast.png"],
    ["1to2_high_contrast.png", "Single aircraft generates two false targets", "Local figure: single_aircraft_redesign_figures/1to2_high_contrast.png"],
    ["1to3_high_contrast.png", "Single aircraft generates three false targets", "Local figure: single_aircraft_redesign_figures/1to3_high_contrast.png"],
    ["1to4_high_contrast.png", "Single aircraft generates a two by two false-target group", "Local figure: single_aircraft_redesign_figures/1to4_high_contrast.png"],
    ["1to5_high_contrast.png", "Single aircraft generates a five-point cross false target", "Local figure: single_aircraft_redesign_figures/1to5_high_contrast.png"],
    ["1to9_high_contrast.png", "Single aircraft generates a three by three false-target group", "Local figure: single_aircraft_redesign_figures/1to9_high_contrast.png"],
    ["1to16_high_contrast.png", "Single aircraft generates a four by four false-target group", "Local figure: single_aircraft_redesign_figures/1to16_high_contrast.png"],
  ];
  for (const [file, alt, source] of cases) await addImageSlide(pres, file, alt, source);
  addCalculationSlide(pres);

  addTwoAircraftPrincipleSlide(pres);
  await addTwoAircraftCaseSlide(
    pres,
    "两架飞机①：共享二通道核，2架变4个规则目标",
    "两架真实飞机采用相同Ki；输出是同一双点核在两个实机位置的平移",
    "two_left.png",
    C.blue,
    "蓝框为两架真实飞机位置；上方四个清晰飞机像为共享码本生成的目标"
  );
  await addTwoAircraftCaseSlide(
    pres,
    "两架飞机②：共享三通道核，重叠位置相干增强",
    "两个通道落到同一SAR位置时，复回波相干相加；可用于选择性增强中心目标",
    "two_center.png",
    C.orange,
    "橙色圆点标出编译后的目标中心；中间重叠位置接收两架飞机的相干贡献"
  );
  await addTwoAircraftCaseSlide(
    pres,
    "两架飞机③：独立码本生成非对称二维编队",
    "K1与K2分别设计，一架向上生成子编队、另一架向下生成子编队",
    "two_right.png",
    C.purple,
    "同一对实机可以通过不同Ki生成上下分离的非对称目标；不仅限于线阵"
  );

  addFourAircraftPrincipleSlide(pres);
  await addResultImageSlide(pres, "four_aircraft_7x7_to16_pair.png", "Four real aircraft generate a four by four group of sixteen targets", "Local figure: results_full_array_exact/four_aircraft_7x7_to16_pair.png");
  await addResultImageSlide(pres, "physical_supercells_compare.png", "Comparison of physical 4 by 4, 5 by 5, and 7 by 7 outer control arrays", "Local figure: results_full_array_exact/physical_supercells_compare.png");
  await addResultImageSlide(pres, "arbitrary_heart_pair.png", "A seven by seven physical control array generates a heart-shaped target constellation", "Local figure: results_full_array_exact/arbitrary_heart_pair.png");
  await addResultImageSlide(pres, "arbitrary_arrow_pair.png", "A seven by seven physical control array generates an arrow-shaped target constellation", "Local figure: results_full_array_exact/arbitrary_arrow_pair.png");
  await addResultImageSlide(pres, "arbitrary_phone_pair.png", "A phone sketch is compiled into a seven by seven physical control array and SAR target constellation", "Local figure: results_full_array_exact/arbitrary_phone_pair.png");
  addFreedomSummarySlide(pres);

  for (const [index, slide] of pres.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    await writeBlob(path.join(PREVIEW_DIR, `${stem}.png`), await pres.export({ slide, format: "png", scale: 1 }));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(PREVIEW_DIR, `${stem}.layout.json`), await layout.text());
  }
  await writeBlob(path.join(BUILD_DIR, "montage.webp"), await pres.export({ format: "webp", montage: true, scale: 1 }));
  const pptx = await PresentationFile.exportPptx(pres);
  await pptx.save(OUTPUT);
  console.log(OUTPUT);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
