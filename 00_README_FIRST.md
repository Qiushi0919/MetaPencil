# MetaPencil 代码交接包

## 一句话说明

MetaPencil 用时变 1/2-bit 可编程反射超表面的快时间与慢时间编码，把真实飞机回波搬移到指定 SAR 距离—方位位置，并用 4×4 二维循环时延基元抑制 2-bit 量化产生的主要 `-3/+5` 阶外侧十字副像。

## 当前最主要成果

- 已有 1-bit、普通平衡 2-bit、2-bit+4 时延相消三条原始复回波/RD 基线。
- 当前推荐入口把“外层整数目标通道阵列”和“每个通道内部的 4×4 延迟基元”编译为单极化四态复反射时序，再作用于 LFM 原始回波。
- 已生成单机 `1→1/2/3/4/5/9/16`、双机共享/重叠/独立码本、四机 16 目标及心形/箭头/手机点阵等结果。
- 4 时延集合 `[0,1/10,5/6,14/15]T` 的复系数计算和 CSV 结果均确认：保留 `+1`，使 `-3/+5` 数值上接近零；没有在成像后人工置零谐波。

主要语言是 MATLAB；Python 仅用于交接检查、PPT 备注提取和启动烟雾测试。

## 推荐阅读顺序

1. `01_AI_CONTEXT.md`
2. `03_CURRENT_PROGRESS.md`
3. `06_FORMULA_CODE_MAPPING.md`
4. `07_RESULTS_TRACEABILITY.md`
5. `09_KNOWN_ISSUES.md`
6. `docs/PPT_SLIDE_CODE_MAPPING.md`

## 版本定位

- **当前主版本**：`source/2 暑假_两个月仿真任务/Week 5 0815之前/SAR假目标自由度与物理阵列/run_full_array_freedom_study.m`
- **当前四机特殊形状版本**：同目录 `run_four_aircraft_ppt_style_shapes.m`。
- **高精度 4机→16目标验证**：同目录 `SHIP_4x4_to_4x4_7x7_physical.m`，它调用 Week 4 公共 2-bit RD 核心。
- **仍用于基线**：Week 4 的 `SHIP_4x4.m`（30/70 1-bit）和 `SHIP_4x4_ssb_2bit.m`（通用 2-bit 核心）。
- **仅供构思/对照**：`run_target_freedom_study.m` 在图像幅度域平移叠加，不是严格复回波相干仿真。
- **仅供展示的变体**：`run_clear_low_channel_shapes.m` 每张图单独归一化，不应直接用于目标间绝对幅度比较。
- **历史 2D/2.5D 舰船和飞机脚本**：保留在 `source/`，用于追溯，不是当前论文主入口。

## 最小运行

在解压后的 `MetaPencil_Handoff` 根目录执行：

```bash
python3 handoff_tools/run_smoke_test.py
```

或 MATLAB：

```matlab
run('handoff_tools/run_smoke_test.m')
```

烟雾测试约 6 秒，输出到 `logs/` 与 `outputs/latest/`。它验证 2-bit 系数、4 时延零陷、二维系数、`1→2` 面积分配和 ±8 m 频率映射，不重算全部飞机 SAR 图。

## 完整运行

```matlab
cd('source/2 暑假_两个月仿真任务/Week 5 0815之前/SAR假目标自由度与物理阵列')
run_full_array_freedom_study
```

推荐至少 8 GB 可用内存。当前默认 `Na=288`、`Nr=2048`、最多 700 个散射点；完整批量预计是“数十分钟级”，具体时间依机器和 MATLAB 版本而变，本次打包未重新跑全套。高精度 0.15/0.075 m 版本会使用更大的慢时间矩阵，历史 MAT 单文件约 304 MB，耗时和内存明显更高。

最重要的已有输出：

- `outputs/latest/`：当前完整阵列结果与控制表；
- `outputs/harmonic_suppression/`：2-bit 时延相消的频谱、矩阵与 SAR；
- `outputs/single_uav/`、`outputs/multi_uav/`：单机和多机结果；
- `outputs/archive_png/`：保留下来的历史 PNG 结果树。

## 当前最大阻塞

当前代码在系统级仿真上成立，但尚未证明 2 m×2 m 共形实体在宽带、斜入射、单元互耦、状态幅相误差、时延抖动和真实控制带宽下仍能达到相同零陷；距离快时间与方位慢时间被代码按可分离二维响应独立实现，物理控制架构和同步条件仍需专门论证。

## 未收录的大文件

原始项目共审计 1056 个文件，交接包收录 566 个；其中大于 10 MiB 而被排除的文件有 **139 个**。主要是 50–304 MB 的 `.mat`/`.fig`、重复历史结果、`cst.zip` 和非核心大 PDF/PPT。完整路径、字节数、SHA256、用途和排除原因见 `file_manifest.csv`；便于快速浏览的清单见 `logs/excluded_large_files.txt`。源代码未因体积规则漏收。

## 交接包限制

- 原项目不是 Git 仓库；没有 commit 可追溯，改用 SHA256 清单。
- `CHECKSUMS_SHA256.txt` 校验 ZIP 内部文件；外层 ZIP 的 SHA256 由最终交付回复提供。
- 历史完整 MAT/FIG 未收录，但关键 PNG/CSV、当前小型 MAT、模型、PPT、备注和代码均已保留。
