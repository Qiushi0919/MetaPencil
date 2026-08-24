# 当前进度矩阵

状态定义：**Confirmed**＝代码与结果/本次测试共同支持；**Partial**＝有实现但验证或物理闭环不完整；**Inferred**＝仅由结构推断；**Unknown**＝材料不足；**Not started**＝未发现实现。

| 模块 | 状态 | 代码证据 | 结果证据 | 可复现性 | 当前问题 | 下一步 |
|---|---|---|---|---|---|---|
| 1-bit 基线 | Confirmed | Week 4 `SHIP_4x4.m:194–235` | `outputs/baseline_1bit/` | 完整脚本+小输入齐全；高精度耗时 | 使用 30/70 非平衡码，正负与高阶较强 | 统一输出指标和绝对参考 |
| 2-bit 基线 | Confirmed | Week 4 `SHIP_4x4_ssb_2bit.m:339–398` | `outputs/baseline_2bit/` | 脚本/PNG/CSV齐全 | 理想等幅四态；仍有 -3/+5 | 加入硬件幅相误差 |
| 谐波频谱计算 | Confirmed | `steppedPhaseFourierCoefficient`；主入口 `twoBitCoefficient` | 1/2-bit harmonic CSV/PNG | 烟雾测试已通过 | 不同脚本阶次范围不同 | 统一一个谐波库函数 |
| -3/+5 阶分析 | Confirmed | `SHIP_4x4_ssb_2bit.m:415–429` | wide100 CSV；PPT 第5页 | 可复现 | 图像 ROI 指标和理论系数尚未统一 | 自动生成抑制比表 |
| 4×4 延迟基元 | Confirmed（理想模型） | `inner_delay_fraction`; `compilePhysicalResponse:439–448` | `physical_supercell_4x4.png` 等 | 烟雾测试确认延迟集合 | 代码用可分离平均等效 16 子单元 | 增加显式16单元非理想模式 |
| 二维可分离编码 | Partial | `azimuth_average.*range_average` | 二维谐波矩阵和 SAR | 数值可复现 | 物理共享时钟、互耦、斜入射未证明 | 推导充分条件并与非可分离模型对比 |
| 矢量闭合验证 | Confirmed | `plot_4x4_supercell_explanation.m`; 分区因子公式 | 复系数 CSV、PPT 12–13页 | 烟雾测试 `S_-3,S_+5≈0` | 仅理想四态 | Monte Carlo 幅相/时延误差 |
| 优化前后对比 | Confirmed | 普通 2-bit 与分区 wrapper 调同一核心 | PPT 14页、两个 wide100 结果集 | 历史输出可追溯 | 不同历史显示裁剪需谨慎 | 用同一参数一键重跑并导出差分 |
| 单机单目标 | Confirmed | 主入口 `single_defs` + 回波乘响应 | `single_1to1_*` | 现有结果+完整脚本 | 目标损耗未形成统一统计 | 增加峰值/积分能量 |
| 单机双目标 | Confirmed | 主入口 129–152 行 | `single_1to2_*` | 烟雾测试验证面积分配 | 两通道各约一半口径 | 验证位置间距与旁瓣耦合 |
| 单机三目标 | Confirmed | 主入口 `1to3` | `single_1to3_*` | 现有结果+完整脚本 | 5×5 不能严格等面积：9/8/8 | 输出不平衡度 |
| 单机四、五目标 | Confirmed | 主入口 `1to4/1to5` | 对应 pair/SAR PNG | 现有结果+完整脚本 | 目标数增加时单像幅度下降 | 完成能量守恒表 |
| 单机 9/16 与任意形状 | Confirmed（仿真） | 主入口 134–136、310–369 行 | 3×3/4×4/心形/箭头/手机 PNG | 现有结果 | 高通道数单像弱；手机入口只到7×7点阵 | 加权/稀疏编译优化 |
| 双机共享码本 | Confirmed | 主入口 201–228 行 | `two_aircraft_line_freedom.png` | 复原始回波实现 | 同步与真实路径相位简化 | 加入相干/非相干模式开关 |
| 双机重叠增强 | Partial | 主入口在复原始数据层求和；旧脚本仅幅度累加 | PPT 20–21页 | 数值结果存在 | 没有独立时钟/姿态；不能外推为实验严格相干 | 显式相位差扫描 |
| 双机独立码本 | Confirmed（系统模型） | 主入口 209–230；`run_two_aircraft_independent_special_shapes.m` | `multi_uav/` 与 archive | 复原始数据结果存在 | 每机码本物理隔离/同步未设计 | 给每架独立控制时钟模型 |
| 四机独立编码 | Confirmed（系统模型） | 主入口 248–265；`run_four_aircraft_ppt_style_shapes.m` | regular/star/pinwheel/infinity PNG | 完整代码和结果存在 | 完整结果 MAT 35 MB 未入包；CSV/PNG保留 | 加入幅相误差与口径约束 |
| 多目标能量统计 | Partial | 面积权重、理论 `eta_2d`、部分 CSV | 目标幅度可算 | 无统一自动报表 | 混用场幅、峰值功率、积分功率 | 统一 5 类能量定义 |
| SAR 图像质量指标 | Not started | 未找到 PSLR/ISLR/分辨率自动函数 | 无标准指标表 | 不可复现 | 目前主要靠图像观察 | 新建 `evaluate_sar_metrics.m` |
| 硬件非理想模型 | Partial | 普通 2-bit 核心有 `state_amplitude/phase_error`; 分区模式拒绝非理想 | 无系统 Monte Carlo 图 | 局部可修改但未验证 | 时延抖动、互耦、带宽/角度均缺失 | 显式16子单元+误差扫描 |
| 全波电磁模型 | Not started（当前系统） | 仅历史 CST 相位导出/模型转换脚本 | 无当前 H/H_k 全波结果 | 不可复现 | 没有当前2-bit宽带斜入射联合工程 | 先做单元周期边界 S 参数 |
| 共形无人机模型 | Not started（当前歼-36系统） | 历史有普通飞机2.5D脚本 | 无 H 基元共形铺设 | 不可复现 | 当前主结果纯2D点散射 | 构建曲面分区和局部坐标系 |
| FPGA 控制设计 | Not started | 未找到 HDL/时序生成器 | 无 | 不可复现 | 快时间状态刷新可能达128–213 MHz | 建立控制字/时钟预算 |
| 真实实验 | Not started | 无采集/标定/实测脚本 | 无 | 不可复现 | 缺硬件、暗室/雷达数据与标定 | 先做单元与小阵列台架实验 |

## 里程碑判断

当前里程碑是“**理想单极化 2-bit、2D 点散射、复原始回波/RD 下的 H primitive + H_k 自由度验证**”。它已经足以形成方法论文的仿真主线，但不足以声称真实共形系统可用。
