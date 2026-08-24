LFM + 1-bit 时间编码 + 单点 SAR 显示演示
================================================

文件：
1. demo_LFM_1bit_SAR_point.m
2. raw_CST_Cx0p7_Cy0p7_Cy2p5.csv

运行方法：
- 将两个文件保持在同一文件夹。
- 在 MATLAB 中打开并运行 demo_LFM_1bit_SAR_point.m。
- 程序会自动建立 output_figures 文件夹并输出四张 PNG：
  01_LFM_waveform_formula.png
  02_Gamma_intra_inter_code.png
  03_coded_echo_waveform.png
  04_SAR_range_doppler_point.png

当前自动选取的工作点约为：
- fc ≈ 5.661 GHz
- Cy=0.7：|Gamma0|≈0.777，相位≈-153.35°
- Cy=2.5：|Gamma1|≈0.886，相位≈26.56°
- 两状态相位差≈179.91°

本版本的物理定位：
这是第一阶段“等效回波闭环验证”。
假目标的位置由人工设置的距离延时 DeltaTau 和脉间多普勒相位决定；
CST 的 Gamma0/Gamma1 用于构造真实的 1-bit 反射调制。
它暂时不等价于“仅靠当前两状态编码就已经综合出任意延时和任意多普勒”。

常用修改位置：
- DeltaR：假目标距离偏移
- fd：假目标多普勒
- intraPattern：脉内 1-bit 编码
- bInter：脉间 1-bit 编码
- B、Tp、PRF、Np：SAR/LFM 参数
