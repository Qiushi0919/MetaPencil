# 0818 PPT 逐页代码与结果映射

来源：`docs/source_materials/0818.pptx`，共 26 页。逐页全部可见文字和备注见 `PPT_NOTES_EXTRACTED.md`。

| 页 | 展示内容/备注核心 | 对应代码 | 对应结果/材料 | 参数 | 验证状态 |
|---:|---|---|---|---|---|
| 1 | 8.18 汇报封面 | 无 | `0818.pptx/pdf` | — | Confirmed 文档 |
| 2 | 目录 | 无 | 同上 | — | Confirmed 文档 |
| 3 | 1-bit 机群，高次与对称谐波问题 | Week4 `SHIP_4x4.m` | `outputs/baseline_1bit/sar_4x4_deception_1bit_full_field.png` | 30/70、8m、-30dB | Confirmed |
| 4 | 使用2-bit，能量更集中但仍有外侧十字 | `SHIP_4x4_2bit_balanced_wide100.m`→公共核心 | baseline_2bit wide100 | 四态25% | Confirmed；本页版式存在较大留白 |
| 5 | 用 `(m,n)` 标出目标与高阶十字副像 | 彩色/标注后处理脚本；公共2bit系数 | baseline2bit `harmonic_ghost_annotations` 与 colored scatter | 主要阶 `-3,+1,+5` | Confirmed（标注图）；颜色是后处理 |
| 6 | 相关工作1：提高bit数、阶梯逼近连续相位、谐波谱 | 无项目算法调用 | `docs/references/相关工作1-提高bit数.pdf` | 1/2/3-bit对比 | Source confirmed；文献结论未在本次重新实验 |
| 7 | 同文献不同bit的SAR结果 | 无 | 同上 | — | Source confirmed |
| 8 | 相关工作2：时间延迟给k阶增加k倍相位 | `S_n`公式对应公共核心分区因子 | `相关工作2-时延控制.pdf`/`向量叠加.pdf` | `e^{-jnω_mt0}` | 理论映射 Confirmed |
| 9 | 真实结构/FPGA多路控制 | 项目尚无FPGA代码 | 相关工作PDF图 | 论文硬件 | 项目状态 Not started；仅文献依据 |
| 10 | 交织子序列的多谐波相量叠加 | 项目以四分区平均实现相近数学结构 | `相关工作2-向量叠加.pdf` | 多子序列 | 原理映射 Confirmed；项目硬件未实现 |
| 11 | 本项目4×4 H基元与四时延波形 | `plot_4x4_supercell_explanation.m`; `compilePhysicalResponse` | supercell示意/CSV | `[0,.1,5/6,14/15]T` | Confirmed |
| 12 | `+1,-3,+5` 相量多边形 | 同上相量绘图 | 相量图 | 四时延 | Confirmed |
| 13 | 只有 `(+1,+1)` 保留，二维能量矩阵 | 公共核心 `C_mS_m*C_nS_n` | partition harmonic matrix | 理想可分离 | Confirmed（理想模型） |
| 14 | 优化前/优化后SAR | 普通2bit wrapper vs 分区wrapper | baseline_2bit 与 harmonic_suppression | wide100、单机绝对参考 | Confirmed；不是同一次批处理差分 |
| 15 | Hk、目标偏移、调制频率、2-bit相位量化的计算摘要 | 主入口 `compilePhysicalResponse`、`fourPhaseRamp`；PPT构建脚本 | 公式/4×4示意 | 示例±8m；高精度可得53.33MHz | Partial：系统公式有代码；实体输出角/单元响应未全波验证 |
| 16 | 单机1→1，H1外层宏格和SAR | 主入口 `single_defs`/`compilePhysicalResponse` | `single_1to1_pair.png` | 4×4外层，-36dB | Confirmed |
| 17 | 单机1→2，H1/H2 | 主入口 `1to2` | `single_1to2_pair.png` | 4×4外层、8/8格 | Confirmed；备注“位置对称即可”比代码宽泛，当前是蛇形交织 |
| 18 | 单机1→3，H1/H2/H3 | 主入口 `1to3` | `single_1to3_pair.png` | 5×5外层、9/8/8格 | Confirmed；不是严格等幅 |
| 19 | 单机4/5目标，亮度随分流下降 | 主入口 `1to4/1to5` | 对应 pair/SAR | 4×4或5×5 | Confirmed |
| 20 | 双机共享、相干重叠、独立码本概念 | 主入口双机定义；旧快速脚本也有概念图 | PPT示意 | source±4m | 概念 Confirmed；实验严格相干 Partial |
| 21 | 双机共享与重叠SAR | 主入口 201–230行 | `two_aircraft_line_freedom.png` | -36dB绝对参考 | Confirmed（复原始数据） |
| 22 | 双机独立码本、非对称编队 | 主入口独立case；`run_two_aircraft_independent_special_shapes.m` | 双机独立PNG | 每机不同offsets | Confirmed（系统模型） |
| 23 | 四架飞机四象限、每架独立编码 | 主入口 248–265行；四机特殊脚本 | PPT概念图 | 四角±12m | Confirmed概念；图本身不是仿真 |
| 24 | 四机多目标/多形状结果 | `run_four_aircraft_ppt_style_shapes.m` 或主入口 | regular/star/pinwheel等 | 700点、-36dB | Confirmed |
| 25 | 四机进一步非对称/特殊形状 | 同上 | multi_uav/与archive | 各机独立K_i | Confirmed |
| 26 | 结束页 | 无 | PPT | — | Confirmed 文档 |

## PPT 与代码存在的三个重要差异

1. PPT 把 H1/H2 的排布描述为“尽量数量平均和位置对称”；当前代码实际采用确定性蛇形交织，保证数量尽量平衡，但没有一般性的几何对称约束或旁瓣优化。
2. PPT 中“相干重叠”是研究目标；当前主入口确实复数求和，但使用中心模板线性平移，没有独立本振/同步/姿态模型，所以只确认数值相干，不确认真实多机实验相干。
3. 相关工作页展示的是论文硬件；项目本身没有 FPGA 或实物超表面实现，不能把文献图片当作本项目实验结果。
