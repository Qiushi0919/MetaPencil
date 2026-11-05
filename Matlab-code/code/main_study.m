%% 最新报告 SAR 复现入口（2026-11-05）
% 在 MATLAB 打开本文件，点击“运行”。完整计算700个散射点，仅保存PNG、参数、指标和运行记录。
% fc=9.5GHz、B=1GHz、Fs=9.6GSa/s、PRF=3072Hz；水平阵面；三图共同参考-80..0dB。
% 复数回波和单元/阵列响应仍参与计算；不输出大型MAT或可编辑FIG文件。
% 输出保存在本目录 results_report 下的新时间目录，不覆盖前次结果。
% 原多案例/四机程序在 ../历史版本/报告同步前_20261105/code 中完整保留。
clear; clc;
script_dir=fileparts(mfilename('fullpath'));
addpath(script_dir);
result=main_study_spatial;
