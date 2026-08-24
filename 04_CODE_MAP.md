# 代码地图

完整 1056 文件级信息见 `file_manifest.csv`。本文件集中说明仍有研究价值的 61 个 MATLAB、4 个 Python 和 3 个 MJS/JS 类文件及其目录角色。

## 目录演化

| 原目录 | 阶段 | 主要内容 | 当前定位 |
|---|---|---|---|
| `Week 1 0708之前/` | 原理自学 | 1-bit 相位/脉间编码、单点 SAR、CST 相位表 | 历史理论和小例子 |
| `Week 2 0715之前/` | 舰船阶段 | 舰船散射点、单/多超表面、2D 编码 | 历史原型；大量重复脚本 |
| `Week 3-1 0719之前/` | 普通飞机 | 2D/2.5D 飞机 SAR，CST 数据处理 | 模型与成像链演化证据 |
| `Week 3-2 0811之前/` | 歼-36 | FBX/STL 转换、歼-36 单机 2D | 当前散射模型来源 |
| `Week 4 0813之前/` | 4×4 机群 | 1-bit、平衡/30-70 2-bit、宽视场谐波 | 当前基线公共核心 |
| `Week 5 0815之前/歼36_4x4机群_2bit分区相消/` | 高阶抑制 | 4 时延分区 wrapper、相量/ROI 分析 | 当前 H primitive 核心证据 |
| `Week 5 0815之前/歼36_4x4机群_2bit_4x4目标群_谐波相消/` | 4→16 | DC/+1 支路面积设计 | 特殊 4×4 目标群验证 |
| `Week 5 0815之前/SAR假目标自由度与物理阵列/` | 自由度总成 | 完整入口、H_k、单/双/四机、形状与 PPT | **当前主目录** |
| `Week 5 0826之前/` | 最新汇报 | `0818.pptx/pdf` | **最新叙事材料** |

## 当前关键文件

| 文件 | 类型/角色 | 输入 | 输出 | 调用/依赖 | 使用状态 |
|---|---|---|---|---|---|
| `.../SAR假目标自由度与物理阵列/run_full_array_freedom_study.m` | 主程序，611行 | Week4 `airplane_scatter_points.mat`; 可选 `phone_sketch.png` | `results_full_array_exact` PNG/CSV/MAT | 自包含局部函数 | 当前推荐 |
| 同目录 `run_four_aircraft_ppt_style_shapes.m` | 四机特殊形状完整回波 | 同一散射点；700点 | regular/star/pinwheel/infinity PNG、CSV、MAT | 自包含 RD/编码函数 | 当前补充 |
| 同目录 `run_two_aircraft_independent_special_shapes.m` | 双机独立特殊形状 | 散射点；420点 | DNA/∞/星/笑脸 | 自包含 | 当前补充，显示 -42 dB |
| 同目录 `SHIP_4x4_to_4x4_7x7_physical.m` | 高精度 wrapper | 7×7 DC/延迟分配参数 | 4机→16目标高精度结果 | 调 Week4 `SHIP_4x4_ssb_2bit.m` | 当前高精度验证 |
| 同目录 `plot_4x4_supercell_explanation.m` | 理论/控制图 | 四时延集合 | 相量图、16组合CSV | 无大数据 | 当前解释工具 |
| 同目录 `analyze_partition_cancel_result.m` | ROI 后分析 | 历史分区结果 MAT | ROI 峰值 CSV/图 | 依赖被排除的大 MAT | Partial，需原大文件 |
| 同目录 `run_target_freedom_study.m` | 快速图像域扫参 | 历史完整 RD MAT | 自由度 PNG/CSV/MAT | `abs(img)`模板 | 旧版，仅构思 |
| 同目录 `run_clear_low_channel_shapes.m` | 展示变体 | 中心回波缓存 | 低通道图形 | 逐图归一化 | 仅展示，禁止幅度横比 |
| 同目录 `build_freedom_presentation.mjs` | PPT 构建脚本 | 本地 artifact-tool 与绝对 ROOT | PPTX | 本地运行时路径 | 遗留；ZIP 中路径已脱敏，需重配 |
| Week4 `SHIP_4x4.m` | 1-bit 基线主程序 | 3000点歼-36 | 1-bit 4×4 SAR、谐波表 | 自包含 RD | 活跃基线 |
| Week4 `SHIP_4x4_balanced.m` | 1-bit 平衡变体 | 同上 | 平衡码结果 | 重复 Week4 核心 | 对照 |
| Week4 `SHIP_4x4_ssb_2bit.m` | 通用2-bit公共主程序，888行 | 外部配置变量+散射点 | 普通/分区/DC支路 2-bit 结果 | 多个 wrapper 调用 | 活跃公共核心 |
| Week4 `SHIP_4x4_2bit_30_70.m` | 2-bit驻留比 wrapper | `[0.3,...]`类比例 | 30/70结果 | 调公共核心 | 对照 |
| Week4 `SHIP_4x4_2bit_balanced_wide100.m` | 平衡2-bit宽视场 wrapper | 视场/分辨率参数 | 外侧十字图 | 调公共核心 | 活跃基线 |
| Week5 分区目录 `SHIP_4x4_2bit_partition_cancel_wide100.m` | H primitive wrapper | `[0,1/10,5/6,14/15]` | 抑制结果 | 调公共核心 | 活跃 |
| Week5 4×4目标群目录 `SHIP_4x4_to_4x4_partition_cancel_wide100.m` | DC/+1双支路 wrapper | 自动面积比例 | 4→16结果 | 调公共核心 | 活跃特殊案例 |
| 各阶段 `ship_trans.m` | 数据生成 | STL/FBX | `airplane_scatter_points.mat/txt` | `stlread`等 | 模型预处理 |

## 主程序关键行范围

以原文件行号为准：

- `run_full_array_freedom_study.m:27–72`：雷达/采样参数。
- `:74–114`：散射点和中心原始回波。
- `:116–125`：2-bit 四态与时延。
- `:127–178`：单机 1→N。
- `:201–246`：双机共享、重叠、独立。
- `:248–272`：四机复回波。
- `:310–369`：手机/任意 7×7 点阵。
- `:371–390`：谐波检查。
- `:409–464`：外层通道和 H primitive 编译。
- `:564–570`：原始回波平移相位。
- `:572–593`：RD 成像。
- `:595–607`：理论 2-bit 傅里叶系数。

## 调用关系

当前主入口使用局部函数，不依赖外部 `.m` 函数；唯一必要外部输入是 Week4 的散射点 MAT。高精度 wrapper 依赖 Week4 公共 `SHIP_4x4_ssb_2bit.m`。历史分析/绘图脚本常直接读取特定时间戳 MAT，因此不是全部可移植。

## 重复和旧版本

- `ship/` 与 `ship原版代码/`、Week3-1 与 Week3-2 的若干脚本高度重复。
- 多个大脚本都复制 `shiftEcho`、`rdFocus`、`fourPhaseRamp`、绘图函数，尚未抽成库。
- 同一结果存在多个时间戳目录和 `.fig/.png/.mat` 三份；ZIP 保留 PNG/CSV，排除大 FIG/MAT。
- `.ppt_*` 隐藏目录是 PPT 生成中间物，未收录；最终 PPT 已收录。
- `build_freedom_presentation.mjs` 的绝对路径在原项目中可运行性依赖个人环境；交接副本已脱敏，不是主研究入口。
