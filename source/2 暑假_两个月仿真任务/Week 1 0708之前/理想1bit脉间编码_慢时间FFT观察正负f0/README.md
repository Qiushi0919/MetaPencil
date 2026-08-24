# 理想 1-bit 脉间相位编码：慢时间 FFT 观察 ±f0

## 这一步在做什么

把周期性的理想 1-bit 相位编码放在连续雷达脉冲之间。

对某一个固定距离单元：

- 未编码静止目标的慢时间回波近似为常数；
- 编码后，每个脉冲的回波乘以 `Gamma[n]=+1/-1`；
- 对脉冲序列做慢时间 FFT；
- 可以看到能量从 `0 Hz` 转移到 `±f0、±3f0、±5f0...`。

## 主程序

`ideal_1bit_interpulse_slowtime_fft.m`

不需要任何额外 MATLAB 工具箱。

## 默认参数

- PRF：1000 Hz
- 脉冲数：800
- 每个编码周期：40 个脉冲
- 调制频率：

  `f0 = PRF / 40 = 25 Hz`

- 理想反射状态：

  `Gamma0 = 1∠0° = +1`

  `Gamma1 = 1∠180° = -1`

## 运行后输出

程序会自动建立 `output_figures` 文件夹，生成：

1. `01_pulse_train_and_interpulse_code.png`
2. `02_ideal_gamma_amplitude_phase.png`
3. `03_slowtime_echo_before_after_coding.png`
4. `04_slowtime_fft_observe_plus_minus_f0.png`
5. `slowtime_harmonic_results.csv`

## 预期结果

未编码时：

- 慢时间回波为常数；
- FFT 的能量集中在 `0 Hz`。

周期 1-bit 相位编码后：

- 零阶分量被抑制；
- 主要谱线位于 `+f0` 和 `-f0`；
- 还会出现 `±3f0、±5f0...`；
- 正负一阶合计功率接近 `8/pi^2 ≈ 81.06%`。

## 这一结果如何解释

入射回波在慢时间上原本位于零多普勒。乘以周期反射系数后：

`s_coded[n] = Gamma[n] s_original[n]`

时域相乘对应频域卷积，因此原来的零多普勒谱线被搬移到编码反射系数的各阶谐波处。

这说明理想 1-bit 脉间编码可以产生正、负等效多普勒分量。

## 当前阶段暂时不包含

- LFM 脉冲内部波形
- 距离向延时
- 距离压缩
- 完整 SAR 方位压缩
- 舰船多散射点

它只验证：

`连续脉冲 → 脉间周期编码 → 慢时间 FFT → ±f0`
