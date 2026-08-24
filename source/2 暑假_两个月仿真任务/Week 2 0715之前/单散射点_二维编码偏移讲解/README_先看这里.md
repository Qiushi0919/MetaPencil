# 单散射点二维编码偏移示例

这个文件夹是在 `ship原版代码/SHIP.m` 的基础上做的最小化教学版本。原程序同时包含大量散射点、四块超表面、覆盖区域判断和 RD 成像，不容易单独看清“编码为什么会让点移动或复制”。这里删去所有无关部分，只保留一个散射点。

## 运行方法

1. 用 MATLAB 打开本文件夹。
2. 运行 `main_single_scatterer_2d_encoding.m`。
3. 程序会依次生成三幅结果：未编码、编码 A（较小间距）、编码 B（较大间距）。
4. 图片会自动保存在本文件夹下的 `运行结果` 中。

代码不需要读取 `.mat` 或 `.txt` 数据文件，也不使用 `rectpuls`，因此不依赖原来的散射点数据和 `rectpuls` 函数。

## 每个文件负责什么

- `main_single_scatterer_2d_encoding.m`：唯一入口；参数、两组编码间距和运行流程都在这里。
- `generate_single_point_echo.m`：生成一个散射点的未编码 SAR 原始回波。
- `apply_2d_1bit_code.m`：施加快时间与慢时间的 0/π 二维相位码；这是本例最关键的文件。
- `design_code_for_spacing.m`：输入希望得到的两个间距，反算最接近的整数码参数。
- `rd_focus_single_point.m`：距离压缩、RCMC、方位压缩。
- `analyze_and_plot_result.m`：绘制二维点阵以及距离向、方位向最大投影。
- `原理推导.md`：解释码周期如何换算为图像中的间距。

## 怎样改变间距

只需要改主脚本中的两个量：

```matlab
fast_cycles = 4;           % 越大，距离向间距越大
slow_period_samples = 32;  % 越小，方位向间距越大
```

本示例的两组默认配置为：

| 情况 | `fast_cycles` | 理论距离间距 | `slow_period_samples` | 理论方位间距（约） |
|---|---:|---:|---:|---:|
| 编码 A | 4 | 2 m | 32 | 16.4 m |
| 编码 B | 10 | 5 m | 16 | 32.9 m |

如果希望直接按物理间距反算参数，可在主脚本已经建立 `cfg` 后运行：

```matlab
[fast_cycles, slow_period_samples, actual] = ...
    design_code_for_spacing(5, 30, cfg);
```

这表示希望距离向约 5 m、方位向约 30 m。由于两个码参数必须取整数，函数还会打印真正能够得到的 `actual` 间距。

实际峰值会受到有限孔径、采样栅格、1-bit 方波的谐波幅度和 RCMC 插值误差影响，因此测得位置与公式可能相差一个采样单元，这是正常现象。

## 与 SHIP.m 的对应关系

原代码中：

```matlab
mod_templates{g, 1} = exp(1j * repmat(base_f, 1, n_rep));
mod_templates{g, 2} = s_temp;
```

- `n_rep` 决定快时间码在一个脉冲内的重复速度，对应本例的 `fast_cycles`。
- `length(s_temp)` 决定慢时间码的重复周期，对应本例的 `slow_period_samples`。
- 原程序把码加到多组散射点上；本例只把码加到一个点上，所以可以直接看到一个点形成二维复制点阵。

## 一个容易混淆的地方

图中的“距离向”坐标是 RD 成像里的斜距偏移 `R-R0`，与 `SHIP.m` 中的 `R_axis=t*c/2` 一致，不是地面水平距离 `Y-Y0`。如果要换成地距，需要再做斜地距投影。
