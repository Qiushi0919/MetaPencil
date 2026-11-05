# MATLAB 报告复现交付

用户要求同步最新版到 `Matlab-code/code`，旧版先备份，并对齐报告参数、水平阵面和−80 dB对照。默认运行 `Matlab-code/code/main_study.m`，详细参数和操作见 `Matlab-code/使用说明.md`。

实际运行：MATLAB R2025a，工作目录 `/tmp`，700散射点，2426×32768复数样本。完整运行成功；计算和MAT保存995.59 s，含绘图约17.5 min，输出约10.4 GiB。输出为 `Matlab-code/code/results_report/20261105_161814_428`。

验收：`matlab_acceptance.json` 和 `acceptance.log`。三幅完整复图与20261030报告归档逐点最大误差0，参考峰值/坐标/散射点/单点指标一致，FIG色阶/坐标/CData验收通过。窗口水平模型峰值−57.341081 dB。字体重画及首轮读取较慢中止的过程见 `validation_notes.txt`；静态分析仅保留原报告循环的AGROW/ALIGN建议，没有语法错误。

来源：`source_reuse.json`证明12个数值函数保持；`source_manifest.json`和`backup_manifest.json`记录当前代码、输入及10个旧文件的SHA256。`CHANGE_PLAN.txt`说明旧→新参数、姿态与显示迁移。`run_manifest.json`记录实际运行和绘图来源；原绘图源和初始清单保留，后续字体修订不改变复数结果。

科学边界：理想载频水平有限阵因子乘完整目标复回波，保持报告RD算法。无方向补偿，不含真实散射点分区、全波、宽带实际单元或硬件。共同未调制700点峰值参考，20log10场幅；−80 dB仅显示下限，原复数不截断。五组MATLAB图可重新生成，排版与原Python渲染器不同，科学数据相同。

发布仅含代码、小型输入、旧代码备份、文档和轻量验收文件；大MAT/FIG、OS元数据、完整工作区迁移和报告DOCX不入库。`.gitattributes`对备份four_aircraft.m保留的原始尾随空格设置单文件检查例外。
