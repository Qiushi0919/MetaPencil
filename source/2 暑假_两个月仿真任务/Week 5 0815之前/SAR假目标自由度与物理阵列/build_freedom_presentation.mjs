import fs from "node:fs/promises";
import path from "node:path";
import { Presentation, PresentationFile } from "<REDACTED_USER_CACHE>/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";

const ROOT = "<REDACTED_WORKSPACE_ROOT>/2 暑假_两个月仿真任务/Week 5 0815之前/SAR假目标自由度与物理阵列";
const IMG = path.join(ROOT, "results_full_array_exact");
const OUT = path.join(ROOT, "presentation_output");
const PPTX = path.join(ROOT, "时变2-bit超表面_SAR假目标自由度与物理阵列.pptx");

const W = 1280;
const H = 720;
const C = {
  navy: "#102A43",
  blue: "#2563EB",
  cyan: "#31B7E8",
  pale: "#EAF5FB",
  ice: "#F5FAFD",
  ink: "#17212B",
  muted: "#52606D",
  line: "#D6DEE6",
  green: "#159A69",
  orange: "#F59E0B",
  red: "#D64545",
  purple: "#7C5CE0",
  white: "#FFFFFF",
  soft: "#F2F4F7",
};
const FONT = "PingFang SC";
const PAPER_TIME = "https://www.nature.com/articles/s41377-018-0092-z";
const PAPER_MULTI = "https://www.nature.com/articles/s41467-023-41031-0";
const PAPER_PIN = "https://www.nature.com/articles/s41377-019-0205-3";
const PAPER_SAR = "https://www.mdpi.com/2072-4292/18/7/1060";

async function readImageBlob(imagePath) {
  const bytes = await fs.readFile(imagePath);
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}

async function writeBlob(filePath, blob) {
  await fs.writeFile(filePath, new Uint8Array(await blob.arrayBuffer()));
}

function addRect(slide, x, y, w, h, fill = C.white, line = C.line, radius = true) {
  return slide.shapes.add({
    geometry: radius ? "roundRect" : "rect",
    position: { left: x, top: y, width: w, height: h },
    fill,
    line: { style: "solid", fill: line, width: 1 },
  });
}

function addText(slide, text, x, y, w, h, opts = {}) {
  const box = slide.shapes.add({
    geometry: "textbox",
    position: { left: x, top: y, width: w, height: h },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  box.text = text;
  box.text.style = {
    fontSize: opts.size ?? 20,
    typeface: FONT,
    color: opts.color ?? C.ink,
    bold: opts.bold ?? false,
    alignment: opts.align ?? "left",
    verticalAlignment: opts.valign ?? "top",
    autoFit: opts.autoFit ?? "shrinkText",
  };
  return box;
}

function addHeader(slide, title, section, page) {
  slide.background.fill = C.white;
  addText(slide, section.toUpperCase(), 42, 24, 310, 22, {
    size: 12, bold: true, color: C.blue,
  });
  addText(slide, title, 42, 50, 1120, 58, { size: 35, bold: true });
  slide.shapes.add({
    geometry: "rect",
    position: { left: 42, top: 116, width: 1196, height: 2 },
    fill: C.blue,
    line: { style: "solid", fill: C.blue, width: 0 },
  });
  addText(slide, String(page).padStart(2, "0"), 1172, 671, 66, 22, {
    size: 12, color: C.muted, align: "right",
  });
}

function addFooterCaption(slide, text) {
  addText(slide, text, 42, 666, 1090, 28, { size: 13, color: C.muted });
}

async function addImagePanel(slide, imagePath, x, y, w, h, alt, opts = {}) {
  addRect(slide, x, y, w, h, opts.fill ?? C.white, opts.line ?? C.line, true);
  const margin = opts.margin ?? 8;
  const blob = await readImageBlob(imagePath);
  slide.images.add({
    blob,
    contentType: "image/png",
    alt,
    fit: opts.fit ?? "contain",
    position: {
      left: x + margin,
      top: y + margin,
      width: w - 2 * margin,
      height: h - 2 * margin,
    },
  });
}

function addPill(slide, text, x, y, w, fill = C.pale, color = C.navy) {
  addRect(slide, x, y, w, 34, fill, fill, true);
  addText(slide, text, x + 8, y + 5, w - 16, 24, {
    size: 14, bold: true, color, align: "center", valign: "middle",
  });
}

function addMetricCard(slide, x, y, w, h, number, label, accent) {
  addRect(slide, x, y, w, h, C.ice, C.line, true);
  slide.shapes.add({
    geometry: "rect",
    position: { left: x, top: y, width: 7, height: h },
    fill: accent,
    line: { style: "solid", fill: accent, width: 0 },
  });
  addText(slide, number, x + 24, y + 18, w - 40, 48, {
    size: 30, bold: true, color: accent,
  });
  addText(slide, label, x + 24, y + 66, w - 40, h - 76, {
    size: 16, color: C.muted,
  });
}

function addBulletCard(slide, x, y, w, h, title, lines, accent = C.blue) {
  addRect(slide, x, y, w, h, C.soft, C.line, true);
  addText(slide, title, x + 22, y + 18, w - 44, 34, {
    size: 20, bold: true, color: accent,
  });
  addText(slide, lines.map((v) => `• ${v}`).join("\n"), x + 22, y + 61, w - 44, h - 76, {
    size: 16.5, color: C.ink,
  });
}

function setNotes(slide, presenterText, urls = []) {
  const sourceLines = urls.map((u) => `- ${u}`).join("\n");
  slide.speakerNotes.textFrame.setText(
    `${presenterText}\n\n[Sources]\n${sourceLines}\n[/Sources]`,
  );
  slide.speakerNotes.setVisible(false);
}

async function latestFullRdImage() {
  const base = path.join(ROOT, "results_full_rd_7x7_physical");
  try {
    const dirs = (await fs.readdir(base, { withFileTypes: true }))
      .filter((d) => d.isDirectory())
      .map((d) => d.name)
      .sort();
    for (const dir of dirs.reverse()) {
      const files = await fs.readdir(path.join(base, dir));
      const preferred = files.find((f) => f.includes("target_grid_4x4") && f.endsWith(".png"))
        ?? files.find((f) => f.includes("full_field") && f.endsWith(".png"))
        ?? files.find((f) => f.startsWith("sar_4x4") && f.endsWith(".png"));
      if (preferred) return path.join(base, dir, preferred);
    }
  } catch {}
  return path.join(IMG, "four_aircraft_7x7_to16_pair.png");
}

async function main() {
  await fs.mkdir(OUT, { recursive: true });
  const fullRd = await latestFullRdImage();

  const deck = Presentation.create({ slideSize: { width: W, height: H } });
  deck.theme.colorScheme = {
    name: "Codex Grid SAR",
    themeColors: {
      accent1: C.blue, accent2: C.cyan, accent3: C.orange,
      accent4: C.red, accent5: C.purple, accent6: C.green,
      bg1: C.white, bg2: C.soft, tx1: C.ink, tx2: C.muted,
      dk1: "#000000", dk2: C.navy, lt1: C.white, lt2: C.line,
      hlink: C.blue, folHlink: C.purple,
    },
  };

  // 01 Cover — Codex Grid slide-08 blueprint: text left, hero right.
  {
    const s = deck.slides.add();
    s.background.fill = C.white;
    addPill(s, "MATLAB · 完整RD + 系统级扫参", 52, 54, 292, C.pale, C.blue);
    addText(s, "时变2-bit超表面\nSAR假目标自由度", 52, 122, 520, 170, {
      size: 46, bold: true, color: C.navy,
    });
    addText(s, "从单机1→N、双机线目标到四机→16架；\n再扩展到手机手绘任意点阵的一键编译。", 52, 312, 520, 96, {
      size: 20, color: C.muted,
    });
    addMetricCard(s, 52, 458, 154, 126, "1→16", "单架可编程目标数示例", C.blue);
    addMetricCard(s, 222, 458, 154, 126, "4→16", "四角飞机群完整RD验证", C.green);
    addMetricCard(s, 392, 458, 154, 126, "7×7", "最多49个手绘目标通道", C.orange);
    await addImagePanel(s, path.join(IMG, "four_aircraft_7x7_to16_pair.png"), 616, 54, 612, 574,
      "7×7控制超单元与四架飞机生成16架SAR目标群", { margin: 6 });
    addText(s, "谢秋实｜阶段性方案总结", 52, 650, 470, 26, { size: 14, color: C.muted });
    addText(s, "2026.08", 1120, 650, 108, 26, { size: 14, color: C.muted, align: "right" });
    setNotes(s, "开场强调：本工作已经从单一4×4现象扩展成可配置的假目标生成框架。", [PAPER_SAR]);
  }

  // 02 Executive summary.
  {
    const s = deck.slides.add(); addHeader(s, "结论先行：目标数、位置、幅度与副谐波可分层设计", "核心结论", 2);
    addMetricCard(s, 42, 144, 276, 120, "K", "单架通过K个波形/空间通道生成K个目标", C.blue);
    addMetricCard(s, 332, 144, 276, 120, "2K", "两机共享码本时得到两份平移目标核", C.cyan);
    addMetricCard(s, 622, 144, 276, 120, "4×4", "每架4通道；四角4架最终得到16架", C.green);
    addMetricCard(s, 912, 144, 276, 120, "−3/+5", "四时延分区相干抵消主要十字副像", C.orange);
    await addImagePanel(s, path.join(IMG, "single_1toN_overview.png"), 42, 290, 730, 350,
      "单架飞机1到N自由度总览", { margin: 4 });
    addBulletCard(s, 796, 290, 392, 350, "设计自由度", [
      "位置：距离调制频率 + 方位调制频率",
      "数量：独立波形通道数K",
      "幅度：空间面积比例 / 驻留时间 / 反射幅度",
      "形状：真实飞机SAR模板随谐波整体平移",
      "纯净度：延迟分区形成高阶谐波零陷",
    ]);
    addFooterCaption(s, "浅蓝框统一表示真实飞机位置；黄色圆圈表示设定的目标中心。");
    setNotes(s, "本页建立四层自由度：位置、数量、幅度、副谐波。", [PAPER_TIME, PAPER_MULTI, PAPER_SAR]);
  }

  // 03 System mapping.
  {
    const s = deck.slides.add(); addHeader(s, "统一模型：SAR输出 = 真实目标分布 * 超表面谐波核", "原理", 3);
    const cols = [58, 458, 858];
    const titles = ["① 真实目标 O(x,y)", "② 编码核 H(nᵣ,nₐ)", "③ SAR结果 I=O*H"];
    const bodies = [
      "1架、2架线目标、4架角点目标\n决定“原始散射模板”与基准位置。",
      "每个非零二维傅里叶系数对应一个位移像；\n系数幅度/相位决定假目标复权重。",
      "每架真实飞机都生成一份平移核；\n相同位置的像会发生相干叠加。",
    ];
    const accents = [C.cyan, C.orange, C.green];
    for (let i = 0; i < 3; i++) {
      addRect(s, cols[i], 170, 330, 284, C.ice, C.line, true);
      addText(s, titles[i], cols[i] + 24, 196, 282, 42, { size: 21, bold: true, color: accents[i] });
      addText(s, bodies[i], cols[i] + 24, 258, 282, 128, { size: 17.5, color: C.ink });
      addPill(s, i === 0 ? "目标几何" : i === 1 ? "电磁自由度" : "完整RD结果",
        cols[i] + 74, 395, 182, accents[i], C.white);
      if (i < 2) {
        s.shapes.add({ geometry: "rightArrow", position: { left: cols[i] + 345, top: 275, width: 44, height: 54 }, fill: C.blue, line: { style: "solid", fill: C.blue, width: 0 } });
      }
    }
    addRect(s, 58, 492, 1130, 122, C.navy, C.navy, true);
    addText(s, "位置映射", 82, 514, 150, 26, { size: 16, bold: true, color: C.cyan });
    addText(s, "ΔR ∝ fₘ,ᵣ　　Δy ∝ fₘ,ₐ", 82, 546, 310, 38, { size: 25, bold: true, color: C.white });
    addText(s, "幅度预算", 456, 514, 150, 26, { size: 16, bold: true, color: C.orange });
    addText(s, "Aₚ,ᵩ = Cₚ Cᵩ Sₚ Sᵩ", 456, 546, 330, 38, { size: 25, bold: true, color: C.white });
    addText(s, "物理含义", 846, 514, 150, 26, { size: 16, bold: true, color: C.green });
    addText(s, "空间分区 × 时间序列 × 相干叠加", 846, 546, 310, 38, { size: 22, bold: true, color: C.white });
    addFooterCaption(s, "所有案例均由同一份整数阵列配置生成2-bit时序，再作用于原始LFM回波并执行RD成像；没有图像域复制或平移。");
    setNotes(s, "解释卷积/闵可夫斯基和：目标几何与编码核可以分开设计。", [PAPER_TIME, PAPER_MULTI, PAPER_SAR]);
  }

  const singleSlides = [
    ["1→1：把整架飞机搬到一个指定谐波位置", "single_1to1_pair.png", 4,
      "一个二维调制通道；四组循环时延保留(+1,+1)，并对−3/+5形成零陷。"],
    ["1→2：两个独立通道定义两处假目标", "single_1to2_pair.png", 5,
      "两个通道各占一半有效口径；位置可由两组(fₘ,ᵣ,fₘ,ₐ)独立给定。"],
    ["1→3：一维三点线目标是最小编队生成器", "single_1to3_pair.png", 6,
      "共享方位频率、设置三个距离频率，可得到等方位的三机线目标。"],
    ["1→4：四个二维通道直接合成2×2目标", "single_1to4_pair.png", 7,
      "外层4×4宏格可平均分给4个通道；每个宏格内部仍包含4×4循环时延子单元。"],
    ["1→5：目标位置不必是矩形，可形成十字或任意稀疏图形", "single_1to5_pair.png", 8,
      "五个通道的二维频率坐标可以自由选择；包含(0,0)时，目标与原机位置重合。"],
  ];
  for (const [title, file, page, insight] of singleSlides) {
    const s = deck.slides.add(); addHeader(s, title, "单架飞机 1→N", page);
    await addImagePanel(s, path.join(IMG, file), 42, 138, 1196, 474, title, { margin: 4 });
    addRect(s, 64, 578, 1152, 62, C.pale, C.pale, true);
    addText(s, insight, 86, 592, 1108, 36, { size: 17.5, bold: true, color: C.navy, valign: "middle" });
    addFooterCaption(s, "幅度均以未调制单架飞机峰值=1（0 dB）归一化；通道增加会带来口径分配损失。");
    setNotes(s, insight, [PAPER_TIME, PAPER_MULTI, PAPER_SAR]);
  }

  // 09 1→9 and 1→16.
  {
    const s = deck.slides.add(); addHeader(s, "1→9与1→16：二维阵列规模继续扩展，但单目标幅度下降", "单架飞机 1→N", 9);
    await addImagePanel(s, path.join(IMG, "single_1to9_sar.png"), 42, 145, 574, 426, "单架生成3×3九目标", { margin: 4 });
    await addImagePanel(s, path.join(IMG, "single_1to16_sar.png"), 664, 145, 574, 426, "单架生成4×4十六目标", { margin: 4 });
    addPill(s, "1→9：7×7宏格近等分", 140, 590, 330, C.pale, C.blue);
    addPill(s, "1→16：4×4宏格一格一通道", 786, 590, 330, "#FFF4DF", C.orange);
    addFooterCaption(s, "结论：目标数理论上可继续增加；工程上受有效口径、控制带宽和接收机动态范围限制。");
    setNotes(s, "强调数量自由度不是无损复制；这里按等面积分区做保守幅度预算。", [PAPER_MULTI, PAPER_SAR]);
  }

  // 10 amplitude budget.
  {
    const s = deck.slides.add(); addHeader(s, "数量自由度的代价：等面积分配时，单目标幅度约按1/K下降", "幅度预算", 10);
    s.charts.add("bar", {
      position: { left: 46, top: 150, width: 710, height: 438 },
      categories: ["1", "2", "3", "4", "5", "9", "16"],
      series: [{ name: "单目标相对幅度/dB", values: [-5.19, -11.21, -14.74, -17.23, -19.18, -24.28, -29.27], fill: C.blue }],
      hasLegend: false,
      dataLabels: { showValue: true, position: "outEnd" },
      chartFill: C.white,
      chartLine: { style: "solid", width: 0, fill: C.white },
      plotAreaFill: { type: "none" },
      yAxis: {
        visible: true, min: -32, max: 0, majorUnit: 5,
        majorGridlines: { style: "solid", width: 1, fill: C.line },
        textStyle: { typeface: FONT, fontSize: "12px", color: C.muted },
      },
      xAxis: { visible: true, textStyle: { typeface: FONT, fontSize: "12px", color: C.ink } },
      barOptions: { direction: "column", grouping: "clustered", gapWidth: 70 },
    });
    addBulletCard(s, 792, 150, 396, 194, "为什么会下降", [
      "同一物理口径被K个通道共享",
      "远场复幅度与分配面积近似成正比",
      "2-bit + 四时延分区本身先有−5.19 dB转换损失",
    ], C.orange);
    addBulletCard(s, 792, 366, 396, 222, "如何提升", [
      "允许目标幅度不等，集中面积给关键目标",
      "采用更高bit数或多子序列优化，提高目标谐波效率",
      "增大物理口径/单元数，而不是只调显示阈值",
    ], C.green);
    addFooterCaption(s, "本页是“等面积K通道”的保守预算；优化序列可改变能量分配，但不能违反总功率约束。");
    setNotes(s, "图中−5.19 dB来自当前平衡2-bit四相位序列与四分区相消的组合，不是PIN管反射损耗。", [PAPER_TIME, PAPER_MULTI]);
  }

  // 11 two aircraft.
  {
    const s = deck.slides.add(); addHeader(s, "两架飞机（线目标）：共享码本产生平移卷积，独立码本打破对称", "多源目标", 11);
    await addImagePanel(s, path.join(IMG, "two_aircraft_line_freedom.png"), 42, 140, 1196, 472,
      "两架飞机共享和独立编码的SAR结果", { margin: 4 });
    addPill(s, "共享码本：目标核相同", 72, 625, 320, C.pale, C.blue);
    addPill(s, "重叠位置：复幅度相干相加", 474, 625, 330, "#FFF4DF", C.orange);
    addPill(s, "独立码本：两架可生成不同编队", 884, 625, 330, "#EAF8F1", C.green);
    setNotes(s, "两机自由度的关键不是简单翻倍，而是是否共享控制器、是否发生目标位置重叠。", [PAPER_MULTI, PAPER_SAR]);
  }

  // 12 four aircraft.
  {
    const s = deck.slides.add(); addHeader(s, "四架角点飞机 × 每架4通道 = 4×4共16架目标群", "多源目标", 12);
    await addImagePanel(s, path.join(IMG, "four_aircraft_7x7_to16_pair.png"), 42, 138, 1196, 492,
      "4×4外层通道阵列生成4×4目标群", { margin: 4 });
    addFooterCaption(s, "每架飞机的4×4外层阵列把16个宏格等分给4个目标通道；每个通道内部再用4×4时延子单元压制−3/+5副谐波。");
    setNotes(s, "说明四架真实飞机位于四角浅蓝框；每架的四通道偏移方向根据所在角点自动指向阵列内部。", [PAPER_TIME, PAPER_MULTI, PAPER_SAR]);
  }

  // 13 4x4 physical.
  {
    const s = deck.slides.add(); addHeader(s, "4×4外层控制阵列：16个整数宏格可精确均分给4个目标通道", "物理超单元", 13);
    await addImagePanel(s, path.join(IMG, "physical_4x4_system_pair.png"), 42, 140, 1196, 476,
      "4乘4超单元与单目标SAR结果", { margin: 4 });
    addFooterCaption(s, "左图每个Hₖ就是一个实际宏格通道；Hₖ内部均含4×4子单元，dᵣ,dₐ取[0, 1/10, 5/6, 14/15]T。");
    setNotes(s, "两级结构必须区分：外层4×4负责目标数量和位置，内层4×4时延负责清理每个通道的量化副谐波。", [PAPER_TIME, PAPER_MULTI]);
  }

  // 14 5x5 physical.
  {
    const s = deck.slides.add(); addHeader(s, "5×5外层控制阵列：25个宏格恰好均分给5个目标通道", "物理超单元", 14);
    await addImagePanel(s, path.join(IMG, "physical_5x5_system_pair.png"), 42, 140, 1196, 476,
      "5乘5超单元与四目标SAR结果", { margin: 4 });
    addFooterCaption(s, "示例将25个宏格按5:5:5:5:5分配给十字五点；因此五个目标通道的物理面积完全相同。");
    setNotes(s, "5×5适合五点、字母笔画或五机线目标。每个目标位置仍由对应的距离/方位调制频率独立指定。", [PAPER_TIME, PAPER_MULTI]);
  }

  // 15 7x7 physical and full RD.
  {
    const s = deck.slides.add(); addHeader(s, "7×7外层控制阵列：49个宏格支持9个常规通道或最多49个手绘点", "物理超单元", 15);
    await addImagePanel(s, path.join(IMG, "physical_7x7_system_pair.png"), 42, 142, 640, 454,
      "7乘7外层阵列的完整回波仿真", { margin: 4 });
    await addImagePanel(s, fullRd, 710, 142, 528, 454,
      "7乘7物理整数分区完整原始回波RD成像", { margin: 4 });
    addPill(s, "49个外层宏格", 96, 616, 180, C.pale, C.blue);
    addPill(s, "每格内含16个时延子组", 292, 616, 220, "#EAF8F1", C.green);
    addPill(s, "总计784个逻辑子组", 528, 616, 210, "#FFF4DF", C.orange);
    addText(s, "右图保留3000散射点的高分辨率完整RD结果，作为精度交叉验证。", 748, 618, 456, 32, { size: 15, bold: true, color: C.navy, align: "center" });
    setNotes(s, "左图是700散射点、0.25 m分辨率的统一自由度仿真；右图是3000散射点的高分辨率独立验证。二者都从原始回波成像。", [PAPER_TIME, PAPER_SAR]);
  }

  // 16 arbitrary heart.
  {
    const s = deck.slides.add(); addHeader(s, "任意形状①：7×7手绘心形自动编译为28个目标通道", "手机手绘 → 超表面", 16);
    await addImagePanel(s, path.join(IMG, "arbitrary_heart_pair.png"), 42, 138, 1196, 492,
      "7乘7心形控制阵列与完整回波SAR结果", { margin: 4 });
    addFooterCaption(s, "左侧49个宏格被均衡分配给心形的有效像素；右侧每个飞机中心对应一个手绘亮点，浅蓝框仍为真实飞机位置。");
    setNotes(s, "强调这不是把飞机图片排成心形，而是每个手绘像素生成一组实际调制频率和整数宏格分配。", [PAPER_MULTI, PAPER_SAR]);
  }

  // 17 arbitrary arrow.
  {
    const s = deck.slides.add(); addHeader(s, "任意形状②：同一块7×7阵列重新编程即可切换为箭头", "手机手绘 → 超表面", 17);
    await addImagePanel(s, path.join(IMG, "arbitrary_arrow_pair.png"), 42, 138, 1196, 492,
      "7乘7箭头控制阵列与完整回波SAR结果", { margin: 4 });
    addFooterCaption(s, "硬件阵列不变，只替换宏格→通道映射和每个Hₖ的(fₘ,ᵣ,fₘ,ₐ)；因此目标形状可以软件重构。");
    setNotes(s, "这页体现用户所谓“随手一画”：改变的是控制表，而不是重新制作超表面。", [PAPER_MULTI, PAPER_SAR]);
  }

  // 18 phone compiler.
  {
    const s = deck.slides.add(); addHeader(s, "手机草图编译器：图片→7×7掩膜→整数通道表→2-bit时序→SAR", "手机手绘 → 超表面", 18);
    await addImagePanel(s, path.join(IMG, "arbitrary_phone_pair.png"), 42, 150, 682, 448,
      "手机草图默认Z形编译和完整回波结果", { margin: 4 });
    addBulletCard(s, 754, 150, 434, 448, "自动生成内容", [
      "读取phone_sketch.png并缩放/阈值化",
      "提取所有有效像素的目标坐标",
      "把4×4/5×5/7×7宏格均衡分配给各坐标",
      "计算每个通道的距离、方位调制频率",
      "附加内部4×4循环时延零陷",
      "导出逐宏格CSV并直接生成原始回波",
      "执行距离压缩、RCMC与方位压缩",
    ], C.purple);
    addFooterCaption(s, "代码入口：phone_sketch_input/phone_sketch.png；换图后重新运行即可得到完全对应的新控制表和SAR结果。");
    setNotes(s, "默认没有手机图片时用Z形掩膜演示；放入实际手绘PNG后代码会自动替换。", [PAPER_MULTI, PAPER_SAR]);
  }

  // 19 harmonic suppression and array comparison.
  {
    const s = deck.slides.add(); addHeader(s, "副像控制：每个手绘通道都用内部4×4时延把−3/+5/+9变成零陷", "纯净度", 19);
    await addImagePanel(s, path.join(IMG, "harmonic_suppression_compare.png"), 42, 142, 716, 446,
      "平衡2-bit编码与四时延分区的谐波对比", { margin: 4 });
    addBulletCard(s, 786, 142, 402, 204, "核心相量", [
      "第n阶获得相位因子 exp(−j2πndₚ)",
      "Sₙ=(1/4)Σₚ exp(−j2πndₚ)",
      "选择d=[0,1/10,5/6,14/15]T，使S₋₃=S₊₅=0",
    ], C.blue);
    addBulletCard(s, 786, 370, 402, 218, "结果含义", [
      "保留目标(+1,+1)的同时压制外侧十字像",
      "没有通过提高显示门限“藏掉”副像",
      "剩余更高阶可继续增加分区或优化时延",
    ], C.green);
    addFooterCaption(s, "外侧十字像的规范名称：高阶谐波副像 / 量化杂散谐波像（high-order harmonic replicas）。");
    setNotes(s, "讲清楚时间延迟不改变单分区谐波幅度，却按阶次旋转相位；多个空间分区再相干相消。", [PAPER_TIME, PAPER_MULTI]);
  }

  // 20 hardware and next steps.
  {
    const s = deck.slides.add(); addHeader(s, "投版建议：单极化2-bit PIN + 两级逻辑超单元 + 手机/FPGA控制链", "工程实现", 20);
    addBulletCard(s, 42, 148, 362, 222, "电磁单元", [
      "单极化即可满足当前单站SAR验证",
      "每单元2个PIN管形成00/01/10/11四相位",
      "四态需近似等幅、相差90°",
      "优先优化10 GHz附近斜入射与带宽",
    ], C.blue);
    addBulletCard(s, 426, 148, 362, 222, "控制与布线", [
      "外层宏格负责分配目标通道Hₖ",
      "每个宏格内部含4×4循环时延子组",
      "FPGA输出四态码与循环时延",
      "距离/方位码按快时间和慢时间两级调度",
    ], C.orange);
    addBulletCard(s, 810, 148, 378, 222, "实验判据", [
      "先测四态反射幅相，再回填MATLAB",
      "目标16点幅差<1 dB",
      "−3/+5十字副像低于目标20–30 dBc",
      "核对开关速率、驱动延迟与同步抖动",
    ], C.green);
    addRect(s, 42, 408, 1146, 174, C.navy, C.navy, true);
    addText(s, "下一步最小闭环实验", 70, 432, 270, 32, { size: 22, bold: true, color: C.cyan });
    addText(s, "① 单元CST/HFSS四态幅相 → ② 两级逻辑分区样板 → ③ 单频谐波谱 → ④ 手机掩膜编译与FPGA下载 → ⑤ LFM回波/SAR成像 → ⑥ 实测幅相回填MATLAB", 70, 477, 1082, 70, { size: 18.5, bold: true, color: C.white, valign: "middle" });
    addPill(s, "推荐首版：单极化", 92, 610, 220, C.pale, C.blue);
    addPill(s, "2-bit：四相位", 350, 610, 220, "#FFF4DF", C.orange);
    addPill(s, "PIN：高速开关", 608, 610, 220, "#EAF8F1", C.green);
    addPill(s, "7×7：最多49个绘制点", 866, 610, 270, "#F1ECFF", C.purple);
    setNotes(s, "这是一条从理想MATLAB到可投版样机的最短路径。9 GHz文献已给出2-bit PIN四态和幅度>0.8的实例，但本项目仍需在10 GHz、带宽和斜入射下重新优化。", [PAPER_PIN, PAPER_TIME, PAPER_MULTI, PAPER_SAR]);
  }

  for (let i = 0; i < deck.slides.items.length; i++) {
    const slide = deck.slides.items[i];
    const stem = `slide-${String(i + 1).padStart(2, "0")}`;
    await writeBlob(path.join(OUT, `${stem}.png`), await deck.export({ slide, format: "png", scale: 1 }));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(OUT, `${stem}.layout.json`), await layout.text());
  }
  await writeBlob(path.join(OUT, "deck-montage.webp"), await deck.export({
    format: "webp",
    montage: { format: "webp", width: 1600, slideWidth: 380, padding: 18, gap: 16, background: "#E8EDF2", columns: 3 },
    scale: 1,
  }));
  const pptx = await PresentationFile.exportPptx(deck);
  await pptx.save(PPTX);
  console.log(`PPTX=${PPTX}`);
  console.log(`SLIDES=${deck.slides.items.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
