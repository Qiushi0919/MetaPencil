# 主要结果追踪表

## 统一判断规则

- “绝对参考”指所有图均除以同一未调制中心单机峰值 `reference_peak`，可比较场幅损失。
- “逐图归一化”指每张图自己的峰值设为 0 dB，只能看形状，不能比较不同案例强弱。
- 所有 MATLAB `20log10(abs(img))` 都是场幅 dB；功率比例需对场幅平方或直接 `10log10(power)`。
- PNG 可能裁剪视场，但未发现外部图像编辑改变 SAR 像素；浅蓝框、目标散点和文字是代码绘图叠加，不是回波数据。

| 结果名称 | 生成脚本 | 核心输入/参数 | 交接包输出 | 归一化/色标 | 可复现 | 备注 |
|---|---|---|---|---|---|---|
| 1-bit 4×4机群 | Week4 `SHIP_4x4.m` | 30/70，8 m，0.15 m，3000点 | `outputs/baseline_1bit/sar_4x4_deception_1bit*.png` | 未调制单机绝对参考；主图门限 -25 dB，完整图 -30 dB | Confirmed | 复原始回波调制；无额外反射效率损失 |
| 1-bit 谐波幅度 | 同上 | `zero_state_fraction=.30` | `one_bit_harmonic_amplitudes.csv/png` | 理论场幅，0 dB=未调制幅度1 | Confirmed | 包含 ±阶与零阶 |
| 普通平衡2-bit外侧十字 | Week4 `SHIP_4x4_2bit_balanced_wide100.m`→公共核心 | 25%×4，±100 m，0.15/0.075 m | `outputs/baseline_2bit/sar_4x4_2bit_balanced_wide100*.png` | 单机绝对参考；完整 -30 dB；中央主阶图约 -20 dB | Confirmed | `-3/+5` 十字仍在；大 MAT 未入包 |
| 普通2-bit谐波阶次 | 公共核心 | orders -15:15 | `2bit_balanced_wide100_harmonic_amplitudes.csv/png` | 场幅 dB | Confirmed | `C+1=.9003`,`C-3=.3001`,`C+5=.1801` 等 |
| 主要高阶彩色散点 | 后处理脚本 `plot_colored_harmonic_scatter.m` 类 | 普通2-bit大MAT/谐波位置 | `outputs/baseline_2bit/harmonic_*/*.png` 在 archive 树 | 显示门限约 -30 dB | Partial | 颜色是按阶次给 SAR 散点着色；“浅色膜”来自同阶主瓣/旁瓣与门限点，不是实体膜 |
| +1/-3/+5 相量 | `plot_4x4_supercell_explanation.m` | 四时延 | archive/分区说明 PNG、CSV；PPT 12页 | 复相量直接绘制 | Confirmed | 纯理论/控制图，不是 SAR 图 |
| 二维谐波矩阵 | 公共核心 | `C_mC_n` 或含 `S_mS_n` | baseline2bit/ suppression 的 `harmonic_matrix.png` | 相对场幅 dB | Confirmed | 理想可分离外积 |
| 4时延相消 SAR | Week5 `SHIP_4x4_2bit_partition_cancel_wide100.m` | `[0,.1,5/6,14/15]T` | `outputs/harmonic_suppression/sar_4x4_2bit_partition_cancel*.png` | 单机绝对参考，-30 dB；中央约 -20 dB | Confirmed | 调制矩阵内相干平均，无人工置零 |
| 相消后谐波系数 | 同上 | orders -15:15 | suppression CSV/PNG | 场幅 dB | Confirmed | `C_n*S_n` 的复数实虚部均保存 |
| 优化前后对比 | 普通2bit结果 + 分区结果；PPT排版 | 同一平台/模型，参数近同 | 0818 PPT 14页；两个结果目录 | 各自以单机绝对参考；裁剪相同类型 | Confirmed/Partial | 原始运行目录不同时间戳，建议下一步同一次入口重跑差分 |
| 单机1→1/2/3/4/5/9/16 | `run_full_array_freedom_study.m` | 0.25 m，700点，8 m，外层4/5/7 | `outputs/single_uav/`、`latest/` | 同一单机绝对参考，-36 dB | Confirmed | 全部从原始回波乘响应后RD；pair图含控制阵列 |
| 4/5/7外层控制阵列 | 同上 | `balancedTileMap` | `physical_*_system_pair.png`, CSV | 右图绝对参考，-36 dB | Confirmed | 宏格数量决定通道面积，非任意连续权重 |
| 心形/箭头/手机点阵 | 同上 | 7×7 mask，7.5 m | `arbitrary_*_pair.png` | 单机绝对参考，-42 dB | Confirmed/Partial | heart/arrow内置；若无手机PNG，phone回退为Z形 |
| 双机共享/重叠/独立 | 同上 | source `[-4,0;4,0]` | `two_aircraft_line_freedom.png` | 单机绝对参考，-36 dB | Confirmed（数值） | 复原始数据层求和；实验严格相干仍未验证 |
| 双机独立特殊形状 | `run_two_aircraft_independent_special_shapes.m` | 420点，7×7外层 | archive 中 star/DNA/∞/smile | 单机绝对参考，-42 dB | Confirmed（现有代码/结果） | 完整结果MAT 35MB排除；PNG/CSV保留 |
| 四机→16目标主例 | `run_full_array_freedom_study.m` | 四角±12，每机4通道 | `four_aircraft_7x7_to16_pair.png` | 单机绝对参考，-36 dB | Confirmed | 文件名含7x7但代码中该案例的 `tile_map_four` 是4×4；命名遗留 |
| 四机4×4/星/风车/∞ | `run_four_aircraft_ppt_style_shapes.m` | 700点，各机独立4×4外层 | `outputs/multi_uav/*_sar.png` | 单机绝对参考，-36 dB | Confirmed | 四架均在复原始数据层独立编码 |
| 低通道清晰形状 | `run_clear_low_channel_shapes.m` | 2–3通道/机 | archive 中 grid/V/zigzag | **逐图峰值归一化**，-32 dB | 只适合视觉 | 不能与前述图做绝对幅度比较 |
| 旧快速自由度总览 | `run_target_freedom_study.m` | `abs(RD)`模板、理论面积权重 | `results_freedom_study` archive | 模板峰值=1，-30 dB | Partial | 图像幅度域叠加，非严格复回波 |
| 4机→16 DC/+1 特殊版本 | `SHIP_4x4_to_4x4_partition_cancel_wide100.m` | 42.5794%未调制+57.4206%调制 | archive 和0815材料 | 单机绝对参考，通常 -30 dB | Confirmed（理想） | 与纯H_k硬分组是两种架构；保留真实零阶位置 |

## 可追溯的关键数值

- 普通平衡2-bit：`|C+1|=0.900316`（-0.912 dB）。
- 四时延分区：`|S+1|=0.823639`，`|S-3|,|S+5|≈0`。
- 相消后单维主阶：`|C1S1|=0.741536`（-2.597 dB）。
- 二维主阶：`0.549875` 场幅（-5.195 dB），约 30.24% 功率。
- 主入口 `1→2` 两通道各占50%面积，单目标理论场幅约0.274938；`1→4`各占25%，约0.137469。

## 手工处理检查

- 0818 PPT 中的图片来自现有 MATLAB PNG 与代码生成的控制示意图；PPT 负责排版、裁剪和标注。
- 彩色谐波散点图是 MATLAB 后处理重新着色，不是原始灰度 SAR 直接输出；其颜色仅表示指定阶次。
- 当前主结果的浅蓝矩形是代码绘制的真实飞机位置框，橙色圆点是期望目标位置；二者不是检测结果。
- 未发现 Photoshop/手工像素修改证据，但历史 PPT 对图片缩放、裁剪和并排比较不保证像素级同尺度。

## 大文件依赖

若要运行 `analyze_partition_cancel_result.m` 或某些彩色后处理脚本，需要 `file_manifest.csv` 中被排除的 75–304 MB MAT。对应 PNG/CSV 已保留，完整重跑可由源脚本重新生成。
