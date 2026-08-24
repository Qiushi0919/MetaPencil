小型飞机 2.5D 散射 + 二维 SAR 回波代码

文件说明
1. airplane_model.stl
   已由你上传的 GLB 转换而来，保留了两个网格及其场景变换，共约 6208 个三角面。

2. ship_trans.m
   读取 STL，在三角面表面按面积均匀采样，缩放成长 6 m、翼展 4 m、高 0.9 m的小型实验飞机，
   并保留高度和三角面法向。
   数据格式：my_data = [方位, 地距, 高度, n_方位, n_地距, n_高度]。
   散射点分布图使用统一灰色，不在这里计算或预览散射幅度。

3. SHIP.m
   读取 2.5D 飞机散射点，在回波生成中使用三维斜距和逐脉冲面元迎角，
   使用 0/pi 两种状态的 1-bit 时空调制，在指定偏移方向生成飞机假目标。
   一次运行只输出“未加超表面”和“加 1-bit 超表面”两幅 SAR 图。

4. airplane_scatter_points.mat / txt
   已预先生成的 600 个 2.5D 散射点，可直接运行 SHIP.m。

运行顺序
A. 想直接看结果：运行 SHIP.m。
B. 想重新生成散射点：先运行 ship_trans.m，再运行 SHIP.m。

常用修改
- ship_trans.m 中 num_scatter_points：散射点数，建议 400~800。
- ship_trans.m 中 plane_length_m / plane_wingspan_m / plane_height_m：小飞机建模尺寸。
- ship_trans.m 中 yaw_deg：飞机在二维 SAR 平面内的朝向。
- SHIP.m 中 resolution_mode：
  * 'preview'  地距向约 0.30 m，方位向约 0.30 m，用于快速排错。
  * 'uav'      地距向约 0.15 m，方位向约 0.15 m，默认模式。
  * 'high'     地距向约 0.10 m，方位向约 0.10 m，计算量较大。
- SHIP.m 中 false_range_offset_m / false_azimuth_offset_m：修改假目标中心相对真实飞机的位置。
- SHIP.m 中 true_echo_weight / false_echo_weight：修改真实目标和假目标的等效幅度权重。

结果保存
- 每次运行会在 results/时间_模式/ 中生成：
  * sar_plain.png / fig：未加超表面的 SAR 图像。
  * sar_metasurface.png / fig：加 1-bit 超表面后的 SAR 图像。
  * metrics.csv：两幅图的峰值、能量、峰值位置和 -3 dB 面积。
  * sar_results.mat：图像矩阵及坐标，便于后续分析。

重要说明
- 最终 SAR 图像仍是二维的；“2.5D”指生成回波时保留高度与面元法向，高度会通过斜距和叠掩影响二维图像。
- 当前普通飞机散射模型已考虑高度、面元迎角、背面弱回波和 1/R^2 距离衰减，但尚未加入严格物理光学、边缘绕射、自遮挡、地面杂波和极化。
- 1-bit 量化只有 0/pi 两种状态，会产生正、负调制阶，所以通常形成一对对称假目标。
- 当前仍采用整机统一的等效时空调制，尚未加入超表面单元空间位置、方向图、转换效率和互耦。
- 在 MATLAB 桌面运行时，两幅结果图会停靠在同一个 Figures 区域，通过底部标签页切换。
