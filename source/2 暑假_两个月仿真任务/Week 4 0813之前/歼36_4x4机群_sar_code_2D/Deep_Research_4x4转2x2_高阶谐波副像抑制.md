# 从 4×4 到 2×2：SAR 高阶谐波副像抑制调研

## 1. 研究目标应当怎样表述

当前平衡 2-bit 四相位编码已经把零阶、镜像一阶和偶数阶大幅抑制，中央留下期望的 2×2 假目标；图像外侧的横向、纵向飞机并不是普通 SAR 点扩散函数的“旁瓣”，而是残余高阶时间谐波在距离—方位二维成像中的复制像。

建议采用以下名称：

- 总称：**高阶谐波假目标**或**高阶谐波副像**；
- 强调产生机制：**2-bit 相位量化杂散谐波副像**；
- 强调图像形态：**距离—方位高阶谐波十字栅**或**十字型杂散假目标**；
- 英文可写为 *higher-order harmonic ghost targets/replicas* 或 *quantization-spur harmonic replicas*。

因此，课题可以表述为：

> 面向二维 SAR 假目标阵列重构的时域编码超表面高阶谐波副像抑制。

英文题目可写为：

> Quantization-spur suppression for 2-D SAR false-target synthesis using space–time-coded metasurfaces.

## 2. 为什么中央是 2×2，外侧却形成十字

设距离向和方位向的一维调制傅里叶系数分别为 \(C_{n_r}^{(r)}\) 和 \(C_{n_a}^{(a)}\)，二维谐波像的复幅度为

\[
A_{n_r,n_a}=C_{n_r}^{(r)}C_{n_a}^{(a)}.
\]

理想平衡 2-bit 四相位阶梯码为

\[
1,\;j,\;-1,\;-j,
\]

每个状态保持四分之一周期。它只保留

\[
n=1+4k=\ldots,-7,-3,+1,+5,+9,\ldots
\]

这些谐波，并且

\[
|C_1|=\frac{2\sqrt 2}{\pi}=0.9003,
\qquad
\frac{|C_{1+4k}|}{|C_1|}=\frac{1}{|1+4k|}.
\]

中央 2×2 来自目标二维项 \((n_r,n_a)=(+1,+1)\)。它的幅度为

\[
|A_{1,1}|=0.9003^2=0.8106.
\]

最靠近、也最强的外侧副像通常来自 \((-3,+1)\)、\((+5,+1)\)、\((+1,-3)\)、\((+1,+5)\)。因为其中一个维度仍然乘着很强的 \(C_1\)，它们沿横轴或纵轴形成明显的十字：

\[
\frac{|A_{-3,1}|}{|A_{1,1}|}=\frac{1}{3}
\quad\Rightarrow\quad -9.54\ \mathrm{dBc},
\]

\[
\frac{|A_{+5,1}|}{|A_{1,1}|}=\frac{1}{5}
\quad\Rightarrow\quad -13.98\ \mathrm{dBc}.
\]

而斜对角远处的 \((-3,-3)\) 同时包含两个弱高阶项，相对目标项只有 \(1/9\) 的幅度，即约 \(-19.08\ \mathrm{dBc}\)，所以视觉上不如十字方向明显。

这也说明：**外侧十字不是成像分辨率不够，也不是普通旁瓣，而是有限相位量化的确定性频谱产物。**

## 3. 与这个问题最接近的研究

### 3.1 直接研究 SAR 假目标与高阶谐波

1. **Variable Frequency Phase Modulation on Time-Modulated Metasurface for SAR Feature Reconstruction**, *Remote Sensing*, 2026  
   链接：https://www.mdpi.com/2072-4292/18/7/1060  
   这是目前与本项目最直接的工作。论文明确指出，低比特相位量化产生的高阶谐波会在 SAR 图像中映射成非期望散射中心，并比较了 1-bit、2-bit 和连续相位调制。连续线性相位调制在理想条件下只产生指定一阶，3-bit 以上可更接近干净的连续相位结果。

2. **An Approach for SAR Feature Reconfiguring Based on Periodic Phase Modulation with Inter-Pulse Time Bias**, *Remote Sensing*, 2025  
   链接：https://www.mdpi.com/2072-4292/17/6/991  
   工作重点是按照位置和能量要求优化调制参数，重构多个 SAR 散射中心。它更接近“给定目标图案，反求调制参数”的图像域路线，可借鉴其位置—幅度联合优化框架。

3. **EM Scattering Center Model-Guided Passive SAR Deception Using Diverse Frequency Time-Modulation**, *IEEE TGRS*, 2024  
   DOI：https://doi.org/10.1109/TGRS.2024.3360531  
   用目标电磁散射中心模型指导多频时调制，属于从目标模板出发进行假目标合成的直接相关路线。

4. **Time-Modulated Metasurface-Assisted Moving Target Jamming for Synthetic Aperture Radar**, *IEEE TMTT*, 2025  
   DOI：https://doi.org/10.1109/TMTT.2024.3522571  
   将离散谐波映射成多个可调间距、幅度的 SAR 假目标。虽然面向运动目标，但其谐波—像位置映射与本项目相同。

5. **Diverse Frequency Time-modulated Metasurface for False Target Jamming: Theory and Experiment**, TechRxiv  
   链接：https://doi.org/10.36227/techrxiv.21644972.v1  
   通过对超表面分区并使用不同时间调制频率产生多个假目标，包含单边带/双边带与实物实验。它对后续“分区后相干抵消指定高阶谐波”尤其有参考价值。

### 3.2 从源头提高单边带纯度、压制杂散谐波

1. **Single-Sideband Time-Modulated Phased Array With 2-bit Phased Shifters**, 2020  
   链接：https://arxiv.org/abs/2010.06504  
   采用 0°、90°、180°、270° 四状态顺序切换，把主要能量集中到指定一阶。这正是当前 MATLAB 平衡 2-bit 编码的理论原型。它能够抑制零阶、镜像和偶数阶，但不会消除 \(-3,+5,\ldots\) 这些量化谐波。

2. **High-Efficiency Synthesizer for Spatial Waves Based on Space-Time-Coding Digital Metasurface**, *Laser & Photonics Reviews*, 2020  
   链接：https://onlinelibrary.wiley.com/doi/abs/10.1002/lpor.201900133  
   目标就是产生高质量单音反射并抑制高阶谐波，通过空间—时间联合编码提高转换效率。它是“超表面层面消除外侧十字”最值得复现的工作之一。

3. **Independent control of harmonic amplitudes and phases via a time-domain digital coding metasurface**, *Light: Science & Applications*, 2018  
   链接：https://www.nature.com/articles/s41377-018-0092-z  
   说明时间延迟、数字序列和空间编码可以联合控制各阶谐波的幅度与相位，为多分区相消 \(C_{-3}\) 和 \(C_{+5}\) 提供基础。

4. **Space-time-coding digital metasurfaces**, *Nature Communications*, 2018  
   链接：https://www.nature.com/articles/s41467-018-06802-0  
   使用较长时间编码和二进制粒子群算法设计谐波分布，并结合空间编码改变不同谐波的散射方向。这为“用优化序列压低指定阶次”以及“把残余阶次引导出单站雷达接收方向”提供了两条路线。

5. **Single-Sideband Time-Modulated Phased Array With S-Step Waveform**, *IEEE AWPL*, 2020  
   DOI：https://doi.org/10.1109/LAWP.2020.2989477  
   用更多阶梯逼近连续相位斜坡，降低非期望边带。其本质对应从 2-bit 升到更高相位分辨率。

6. **A synthetic moving-envelope metasurface antenna for independent control of arbitrary harmonic orders**, *Nature Communications*, 2024  
   链接：https://www.nature.com/articles/s41467-024-51587-0  
   通过合成运动包络实现单向频率转换和任意谐波控制，说明提高每周期帧数可以显著减少非期望边带。该系统是天线而非当前的反射式共形超表面，但思想可以移植。

7. **Pure and Linear Frequency-Conversion Temporal Metasurface**, *Physical Review Applied*, 2021  
   链接：https://journals.aps.org/prapplied/abstract/10.1103/PhysRevApplied.15.064011  
   通过时间调制超单元与频率选择结构结合，实现无杂散频率转换。这是更偏硬件的长期路线，但对几十 MHz 间隔且承载宽带 SAR 信号的系统，滤波器带宽和角度稳定性要求很高。

## 4. 各条技术路线的实际效果

### 路线 A：提高相位比特数——最直接、最可靠

对于每周期含 \(M=2^b\) 个等时长相位台阶的线性相位斜坡：

\[
|C_1|=\frac{\sin(\pi/M)}{\pi/M},
\]

最强量化杂散位于 \(n=1-M\)，相对目标一阶为

\[
20\log_{10}\frac{1}{M-1}.
\]

| 编码 | 单维目标一阶功率 | 二维 \((1,1)\) 目标功率 | 最强十字副像/目标 |
|---|---:|---:|---:|
| 2-bit，4 相位 | 81.06% | 65.70% | −9.54 dBc |
| 3-bit，8 相位 | 94.96% | 90.18% | −16.90 dBc |
| 4-bit，16 相位 | 98.72% | 97.45% | −23.52 dBc |
| 5-bit，32 相位 | 约 99.68% | 约 99.36% | −29.83 dBc |
| 连续相位斜坡 | 100% | 100% | 理想情况下不存在 |

结论：3-bit 能明显改善能量利用率和图像，但若目标是让外侧十字在 −30 dB 动态范围内基本消失，仅靠等间隔相位台阶通常需要接近 5-bit，或者采用下述定向相消/优化方法。

### 路线 B：仍用四种物理相位，但优化长序列

将一个周期划分为 \(L\) 个小时间槽，每个槽仍只能从 \(\{1,j,-1,-j\}\) 中选择。利用 BPSO、遗传算法、差分进化或混合整数优化，求解

\[
\min \left[
w_{-3}|C_{-3}|^2+w_5|C_5|^2+
\sum_{n\in\Omega_{\rm other}}w_n|C_n|^2
\right]
-\lambda |C_1|^2.
\]

同时加入状态数、最大开关次数、相位误差和器件响应约束。该方法可以针对性压低最显眼的 \(-3\) 与 \(+5\)，但只有四个相位状态时，不可能在保留强 \(+1\) 的同时把无限多个非期望谐波全部严格清零；通常是把能量重新分配到更高阶或噪声底。

### 路线 C：超表面分区，令指定高阶在雷达方向相干抵消

把超表面分为 \(P\) 个子区，各区使用不同初始时延、编码序列或空间相位。单站雷达方向的第 \(n\) 阶合成系数可写为

\[
\widetilde C_n(\theta)=C_n
\sum_{p=1}^{P}w_p
e^{-j2\pi n\tau_p/T}
e^{j\psi_{n,p}(\theta)}.
\]

优化目标是让 \(\widetilde C_1\) 同相叠加，同时让 \(\widetilde C_{-3}\) 与 \(\widetilde C_5\) 在雷达方向形成零陷。注意：只给所有分区增加简单时间平移，未必能独立区分模 4 同余的谐波；实际需要组合使用分区独立序列、空间相位或幅度权重。

这条路线很适合“器件只能做 2-bit，但阵面可独立寻址”的条件，而且无需消灭全空间的高阶功率，只要使其不返回单站 SAR 接收方向即可。

### 路线 D：连续/准连续相位斜坡，即 serrodyne 频移

理想反射系数

\[
\Gamma(t)=e^{j2\pi f_m t}
\]

只含一个目标谐波，是从数学上真正把 4×4 收敛成纯 2×2 的方案。硬件上可用多比特 PIN/数字移相、变容二极管连续调相或更高帧率控制逼近。困难在于快速刷新、相位线性、幅度一致性、宽带入射和共形角度稳定性。

### 路线 E：把杂散变成噪声或引导到别的角度

- 非周期抖动可把离散飞机副像摊成背景，但会抬高噪声底，不是“干净 2×2”的首选；
- 空—时梯度可以把高阶能量偏转到其他角度，在单站 SAR 图像中消失，但多站或不同视角仍可能看到；
- 时间超单元结合频率选择滤波可以在硬件层面去除杂散，但对当前紧邻载频的低频偏移与宽带 SAR 回波实现难度最高。

## 5. 推荐的研究路线

### 第一阶段：建立可验证的理想基线

在同一套完整 SAR 回波和 RD 成像代码中依次运行：

1. 2-bit 四相位；
2. 3-bit 八相位；
3. 4-bit 十六相位；
4. 连续相位斜坡。

所有结果统一使用 ±100 m 坐标和 30 dB 动态范围。这样可以证明外侧十字随量化位数提高而按理论衰减，而不是模型或绘图偶然产生。

### 第二阶段：在 2-bit 硬件限制下做定向抑制

优先研究“多分区独立长序列 + 空间相位”的联合优化，重点消除 \((-3,1)\)、\((5,1)\)、\((1,-3)\)、\((1,5)\) 四组十字副像。优化直接在二维 SAR 像域评价，不只看一维频谱。

### 第三阶段：加入真实器件约束

至少加入：

- 四状态实际反射幅度和相位，不再假设完全等幅、严格相差 90°；
- 状态转换时间与最高刷新率；
- SAR 信号带宽内的频散；
- 入射角、极化和飞机曲面的空间变化；
- 分区间时钟误差和相位误差。

## 6. 建议统一使用的指标

1. 目标一阶转换效率：

\[
\eta_1=\frac{|C_1|^2}{\sum_n|C_n|^2}.
\]

2. 最坏杂散抑制度：

\[
\mathrm{HSSR}=20\log_{10}
\frac{|C_1|}{\max_{n\ne1}|C_n|}.
\]

3. 总杂散功率比：

\[
\mathrm{TSP}=10\log_{10}
\frac{\sum_{n\ne1}|C_n|^2}{|C_1|^2}.
\]

4. 二维图像指标：中央四个目标窗内积分能量、外侧十字窗内积分能量、最强外侧副像相对中央目标的 dBc、2×2 模板与生成图的结构相似度。

## 7. 最终判断

如果坚持“整块超表面统一使用理想平衡 2-bit 四相位阶梯码”，外侧十字是该波形傅里叶级数的必然结果，不能仅靠改显示阈值真正消除。最有价值的两个研究方向是：

1. **多比特/连续相位斜坡**：从源头提高频谱纯度，理论最清楚；
2. **受限 2-bit 条件下的空—时分区联合优化**：针对单站 SAR 接收方向相干抵消 \(-3\)、\(+5\) 等主要量化杂散，更有工程和论文创新空间。

从现有文献分布看，SAR 论文大多关注如何生成或重构指定散射中心，底层时域超表面论文则关注单音转换效率和谐波纯度。把两者结合成“在完整二维 SAR 像域内，受 2-bit 共形超表面约束的十字型高阶谐波副像抑制”，具有比较明确的研究切口。
