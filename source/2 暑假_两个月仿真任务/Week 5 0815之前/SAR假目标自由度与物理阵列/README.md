# SAR假目标自由度与物理阵列仿真

## 文件

- `run_full_array_freedom_study.m`：最终推荐版本。所有1→N、两机、四机和任意形状均从“整数控制阵列→2-bit时序→原始LFM回波→RD成像”得到，并自动导出每个宏格的最终控制CSV。
- `run_target_freedom_study.m`：早期图像域快速扫参，只用于构思，不作为最终汇报证据。
- `SHIP_4x4_to_4x4_7x7_physical.m`：完整原始回波+RD成像版本。使用7×7整数面积分配（每维3个DC组+4个循环时延组）生成4×4共16架目标群。

## 推荐运行顺序

```matlab
run_full_array_freedom_study
SHIP_4x4_to_4x4_7x7_physical
```

第一段一次性完成全部自由度的完整回波仿真；第二段保留原3000散射点、0.15/0.075 m分辨率的高精度4机→16目标验证。结果分别写入 `results_full_array_exact` 与 `results_full_rd_7x7_physical`。

如果要模拟手机手绘，把白底黑线或黑底白线图片保存为 `phone_sketch_input/phone_sketch.png`，再次运行 `run_full_array_freedom_study.m`。代码会自动缩放、阈值化为7×7点阵，并输出与最终逻辑阵列一一对应的控制表和SAR图。

## 物理解释

图中的4×4、5×5、7×7是“最小控制超单元”的偏置分组数。每一格代表一组独立控制总线，实际投版时每组可以包含许多亚波长2-bit PIN反射单元，并在飞机表面周期重复铺设；不能把一格直接等同于一个孤立PIN管。
