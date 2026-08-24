# 技术债务

## P0：会影响论文结论或硬件外推

1. **理想状态硬编码**：当前 H primitive 分支拒绝非理想四态；零陷鲁棒性没有实现。
2. **没有统一能量定义**：不同对话/表格曾混用场幅、功率比例和SAR峰值。
3. **二维可分离未验证**：真实硬件是否能独立实现快/慢时间相位偏置仍是核心风险。
4. **多机同步未建模**：数值复求和不等于实际严格相干。
5. **散射模型过简**：2D等幅点不能代表真实宽带斜入射歼-36 RCS。

## P1：会阻碍复现和迭代

1. **超长脚本和重复局部函数**：主入口611行、公共2bit核心888行；`rdFocus`、`shiftEcho`、`fourPhaseRamp`在多个脚本重复。
2. **无Git**：没有commit/branch/patch历史。
3. **参数散落与魔法数字**：`8`、`7.5`、`[-36,-42]`、`[0,.1,5/6,14/15]`、不同分辨率写在脚本体内。
4. **结果目录策略不一致**：Week4用时间戳；当前主入口覆盖固定目录；历史脚本又直接依赖特定时间戳。
5. **大文件泛滥**：134个FIG约2.31GB、56个MAT约3.70GB。
6. **不可追踪数据依赖**：部分分析脚本写死某个历史MAT目录；PPT构建器写死个人绝对路径。
7. **展示脚本漂移**：`run_clear_low_channel_shapes`故意逐图归一化，命名没有明显标识“不可比”。
8. **输出名误导**：`four_aircraft_7x7_to16_pair.png`实际案例外层是4×4。

## P2：代码质量和性能

1. Code Analyzer 报告主入口原226行循环动态扩展数组（AGROW）。
2. 旧快速脚本有未使用输入参数（INUSD）。
3. 原始回波散射点×慢时间双循环没有向量化/并行化，未使用`parfor`或GPU。
4. 每次完整运行重复生成中心回波；不同脚本各自维护缓存格式。
5. `balancedTileMap`只做蛇形交织，没有统一的空间谱评价或随机种子/优化种子。
6. 手机草图回退行为未在图标题/参数快照中显式标记。
7. Week2若干旧随机脚本未固定随机种子。
8. 多个历史文件有大量重复或注释保留代码，但没有明确deprecated标志。

## 建议重构边界

本次交接没有重构原算法。下一轮只应做“行为保持”的小步抽取：

```text
+metapencil/loadScatterModel.m
+metapencil/generateCenterEcho.m
+metapencil/fourPhaseRamp.m
+metapencil/harmonicCoefficient.m
+metapencil/compilePhysicalResponse.m
+metapencil/shiftEcho.m
+metapencil/rdFocus.m
+metapencil/plotSarDb.m
+metapencil/evaluateMetrics.m
```

先用烟雾测试和一组小型金标准MAT锁定输出，再替换各旧脚本调用；不要一次性重写整个项目。

## TODO/FIXME扫描

源码中没有形成系统性的 `TODO/FIXME/XXX` 标记。真正的技术债务主要表现为复制代码、硬编码、旧版本和不可追踪数据，而不是显式待办注释。
