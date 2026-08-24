歼-36小型等效模型纯二维散射 + 二维 SAR 回波代码

文件说明
1. j36_model.stl
   已由 Week 3-2/歼36.fbx 在本地转换而来，共约 7.1 万个三角面。

2. ship_trans.m
   读取歼-36 STL，进行 FBX 坐标轴重排，缩放成长 6.0 m、翼展 6.9 m的小型实验模型，
   再把网格压平到 Z=0 后按投影面积采样，
   得到方位-距离平面上的散射点，不保存高度和面元法向。
   数据格式：my_data = [方位, 地距]。
   散射点分布图使用统一灰色，不在这里计算或预览散射幅度。

3. SHIP.m
   读取纯二维飞机散射点，所有目标点高度固定为零、基础散射系数相同。
   雷达平台高度 H0 仅用于把二维地面坐标换算为传播斜距。
   使用 0/pi 两种状态的 1-bit 时空调制，在指定偏移方向生成飞机假目标。
   一次运行输出“未加超表面”“平衡编码超表面”和“30%/70%编码超表面”三幅 SAR 图。

4. airplane_scatter_points.mat / txt
   ship_trans.m 生成的 3000 个纯二维散射点，可直接运行 SHIP.m。

运行顺序
A. 想直接看结果：运行 SHIP.m。
B. 想重新生成散射点：先运行 ship_trans.m，再运行 SHIP.m。

常用修改
- ship_trans.m 中 num_scatter_points：散射点数，建议 400~800。
- ship_trans.m 中 plane_length_m / plane_wingspan_m：小飞机二维建模尺寸。
- ship_trans.m 中 yaw_deg：飞机在二维 SAR 平面内的朝向。
- SHIP.m 中 resolution_mode：
  * 'preview'  地距向约 0.30 m，方位向约 0.30 m，用于快速排错。
  * 'uav'      地距向约 0.15 m，方位向约 0.15 m，默认模式。
  * 'high'     地距向约 0.10 m，方位向约 0.10 m，计算量较大。
- SHIP.m 中 false_range_offset_m / false_azimuth_offset_m：修改假目标中心相对真实飞机的位置。
- SHIP.m 中 reflection_power_efficiency：修改被动超表面的功率反射效率，必须位于 0~1。

结果保存
- 每次运行会在 results/时间_模式/ 中生成：
  * sar_plain.png / fig：未加超表面的 SAR 图像。
  * sar_metasurface.png / fig：加 1-bit 超表面后的平衡编码 SAR 图像。
  * sar_metasurface_30_70.png / fig：0状态30%、1状态70%的编码 SAR 图像。
  * metrics.csv：三幅图的峰值、能量、峰值位置和 -3 dB 面积。
  * sar_results.mat：图像矩阵及坐标，便于后续分析。

重要说明
- 这是纯二维目标模型：散射点文件只有方位和地距两列，所有目标点高度恒为零。
- 当前所有散射点的基础散射系数相同，只考虑 1/R^2 距离衰减；不考虑高度、面元迎角、背面回波和三维叠掩。
- 雷达仍有平台高度 H0，否则无法定义机载 SAR 的斜距；“不考虑高度”专指目标不具有高度起伏。
- 整机完全覆盖时，超表面回波采用 s_meta=Gamma*s_plain；不会额外叠加一份独立裸机回波。
- Gamma=sqrt(eta)*exp(j*phi)，其中 eta 为功率反射效率，phi 只能取 0 或 pi。
- 平衡方案采用 50%/50% 的 0/pi 编码，零阶直流分量被抑制。
- 新增方案采用 0状态30%、1状态70%的 0/pi 编码，会保留非零直流分量，同时产生调制阶假目标。
- 当前仍采用整机统一的等效时空调制，尚未加入超表面单元空间位置、方向图和互耦。
- 在 MATLAB 桌面运行时，三幅结果图会停靠在同一个 Figures 区域，通过底部标签页切换。
