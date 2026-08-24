# 运行手册

## 1. 已验证环境

- macOS 26.5.2，Apple Silicon arm64。
- MATLAB R2025a（25.1.0.2943329）。
- 当前完整 SAR 核心只用 MATLAB 基础数值/绘图函数；手机草图入口额外需要 Image Processing Toolbox。
- Python 3.9+ 仅用于交接工具；研究计算不依赖 Python 包。

详见 `environment/`。

## 2. 解压和路径

所有交付运行命令都从 `MetaPencil_Handoff/` 根目录开始。源码保留了原始 `2 暑假_两个月仿真任务/...` 相对结构，因此当前主入口向上寻找 Week4 散射点的路径仍成立。

不要把 `outputs/` 中的 PNG 当作脚本输入。最小输入是：

```text
source/2 暑假_两个月仿真任务/Week 4 0813之前/
  歼36_4x4机群_sar_code_2D/airplane_scatter_points.mat
```

该 MAT 包含 `my_data`（3000×2，列为方位/地距）。

## 3. 烟雾测试

```bash
python3 handoff_tools/run_smoke_test.py
```

期望：进程返回 0，`logs/smoke_test.log` 中出现：

```text
SMOKE_TEST_STATUS=PASS
|C+1|=0.900316316157
|S+1|=0.823639103546
|S-3|≈1.96e-16
|S+5|≈9.21e-16
|A(+1,+1)|=0.549875229298
```

输出图：`outputs/latest/smoke_harmonic_suppression.png`。

## 4. 当前主入口

MATLAB 中执行：

```matlab
handoff_root = pwd;
code_dir = fullfile(handoff_root,'source','2 暑假_两个月仿真任务', ...
    'Week 5 0815之前','SAR假目标自由度与物理阵列');
cd(code_dir);
run_full_array_freedom_study
```

脚本会自动创建/覆盖当前副本内 `results_full_array_exact/` 中的同名 PNG/CSV/MAT。原始工作区未被改动。

### 默认计算规模

- `Na=288`、`Nr=2048`；
- 最多 700 散射点；
- 一个复矩阵约 9 MiB，运行过程中同时存在多个矩阵和图像；
- 建议至少 8 GB 可用内存；
- 全批量预计数十分钟，受 CPU 和图像导出影响。本次只实际跑了低成本烟雾测试。

## 5. 分步重现基线

### 1-bit 4×4 基线

```matlab
cd(fullfile(handoff_root,'source','2 暑假_两个月仿真任务', ...
    'Week 4 0813之前','歼36_4x4机群_sar_code_2D'));
SHIP_4x4
```

默认是 0 状态 30%、1 状态 70%，0.15 m 分辨率，3000 散射点；会创建时间戳目录，运行明显重于烟雾测试。

### 普通平衡 2-bit 宽视场

```matlab
SHIP_4x4_2bit_balanced_wide100
```

它通过变量配置后调用 `SHIP_4x4_ssb_2bit.m`。

### 4 时延谐波相消

```matlab
cd(fullfile(handoff_root,'source','2 暑假_两个月仿真任务', ...
    'Week 5 0815之前','歼36_4x4机群_2bit分区相消'));
SHIP_4x4_2bit_partition_cancel_wide100
```

### 高精度 4机→16目标

```matlab
cd(fullfile(handoff_root,'source','2 暑假_两个月仿真任务', ...
    'Week 5 0815之前','SAR假目标自由度与物理阵列'));
SHIP_4x4_to_4x4_7x7_physical
```

这个 wrapper 可能产生约 300 MB 的 MAT；交接包未含历史大 MAT。

## 6. 手机草图入口

把白底黑线或黑底白线图放到当前主目录：

```text
phone_sketch_input/phone_sketch.png
```

再次运行 `run_full_array_freedom_study.m`。脚本会缩放、Otsu 阈值化为 7×7 mask，输出 `compiled_phone_mask_7x7.csv` 和对应 SAR。若图片不存在，代码回退到内置 Z 形 mask；因此看到“phone”结果不一定意味着真实手机图片曾参与，必须检查输入文件。

## 7. 随机性

- 当前主入口、2-bit/1-bit 成像脚本使用确定性散射点和确定性等索引抽样，没有逐脉冲随机幅度。
- 当前 `ship_trans.m` 在随机表面采样前固定 `rng(2026)`，可复现。
- Week2 的若干旧 `ship_trans.m` 直接调用 `rand` 而未固定随机种子；旧结果不保证逐次一致。

## 8. 绝对路径与个人环境

发现的两个绝对路径只位于：

- 一份 Deep Research 交接 Markdown；
- `build_freedom_presentation.mjs` 的 artifact-tool import 和 `ROOT`。

ZIP 副本已脱敏。MJS 构建器若要重跑，需要把 `<REDACTED_...>` 改为本机运行时和源码目录；这不影响 MATLAB 主入口。

## 9. 常见失败

- `找不到歼-36散射点`：启动目录/相对结构被改变，或漏了 Week4 MAT。
- `4×4局部超单元快速等效只适用于理想等幅...`：在分区模式下填写了非理想四态；当前核心明确拒绝该近似。
- 手机函数未定义：缺 Image Processing Toolbox，或没有使用 R2025a 兼容环境。
- 内存不足：运行 0.075 m 方位高精度 wrapper；先用当前 0.25 m 主入口。
- 图像亮度不可比：误用了 `run_clear_low_channel_shapes.m` 的逐图归一化结果。

## 10. 输出与日志

- 原始脚本输出位于各自源码目录下的 `results_*`。
- 交付快照结果集中于 `outputs/`。
- 烟雾测试和打包审计在 `logs/`。
- 每次正式论文图运行应另外保存参数快照、命令、MATLAB 版本、绝对参考峰值和执行时间；当前历史脚本尚未统一做到这一点。
