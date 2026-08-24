# 理想 1-bit 相位编码：谐波与等效多普勒

## 文件说明

- `ideal_1bit_phase_harmonic_demo.m`：主程序
- `汇报思路.txt`：可以直接用于阶段汇报的讲解顺序

## 运行方法

1. 解压压缩包。
2. 用 MATLAB 打开 `ideal_1bit_phase_harmonic_demo.m`。
3. 点击“运行”。
4. 程序会自动建立 `output_figures` 文件夹，并输出：
   - `01_ideal_1bit_states.png`
   - `02_time_domain_phase_code.png`
   - `03_harmonic_spectrum.png`
   - `04_frequency_shift_and_doppler.png`
   - `harmonic_results.csv`

## 默认参数

- 载频：`fc = 5.661 GHz`
- 时间调制频率：`f0 = 200 Hz`
- 调制周期：`T0 = 5 ms`
- 状态 0：`Gamma0 = 1∠0°`
- 状态 1：`Gamma1 = 1∠180°`

## 预期结论

- 零阶谐波被完全抑制。
- 偶数阶谐波为零。
- 能量只分布在奇数阶谐波。
- `+1` 阶和 `-1` 阶各占总功率约 `40.53%`。
- 正负一阶合计约占总功率 `81.06%`。
- `±f0` 可以解释为 `±200 Hz` 的等效多普勒。
- 在 `5.661 GHz` 下，对应等效径向速度约为 `±5.30 m/s`。

## 注意

该代码只验证：

`理想 1-bit 相位编码 → 谐波产生 → 频率搬移 → 等效多普勒`

暂时不包含 LFM、距离向延时、SAR 二维成像和舰船假目标。
