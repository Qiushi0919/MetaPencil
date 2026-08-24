%% 单散射点：二维 1-bit 编码后形成距离向/方位向可调间距的复制点
% 本脚本从 ship原版代码 中抽出最核心的三步：
%   1) 生成一个点目标的线性调频 SAR 原始回波；
%   2) 快时间乘周期 0/pi 码，慢时间乘周期 0/pi 码；
%   3) 用 RD 算法做距离压缩、RCMC 和方位压缩。
%
% 运行方式：直接运行本文件。脚本会比较：未编码、较小间距、较大间距。

% 最重要的两个调参量：
%   fast_cycles          快时间在一个脉冲内重复多少个码周期
%   slow_period_samples  慢时间一个码周期占多少个脉冲
%
% 理论间距：
%   距离向间距 = c/(2*|Kr|) * fast_cycles/Tp
%   方位向间距 = v/|Ka| * PRF/slow_period_samples

% 周期 0/pi 码不是单一正弦，所以会产生多个谐波。每个距离谐波与每个
% 方位谐波组合后，一个真实散射点会在二维图像中形成“复制点阵”。

% 对应原代码：
%   fast_cycles          <-> pss_configs 第 3 列的快时间重复次数
%   slow_period_samples  <-> slow_code 的序列总长度

clear; clc; close all;

code_dir = fileparts(mfilename('fullpath'));
if isempty(code_dir)
    code_dir = pwd;
end
addpath(code_dir);

%% 1. 雷达与场景参数（与 ship 原版代码保持同一量级）
cfg.c       = 3e8;
cfg.fc      = 10e9;
cfg.lambda  = cfg.c / cfg.fc;

cfg.Tp      = 3e-6;          % 脉冲宽度
cfg.Br      = 300e6;         % 距离向带宽
cfg.Kr      = cfg.Br/cfg.Tp; % 距离调频率
cfg.Fs      = 2*cfg.Br;      % 快时间采样率

cfg.H0      = 20000;
cfg.beta    = 70*pi/180;
cfg.Y0      = cfg.H0*tan(cfg.beta);
cfg.R0      = hypot(cfg.H0, cfg.Y0);
cfg.v       = 1000;

cfg.target_az  = 0;          % 唯一散射点的方位坐标
cfg.target_amp = 1;

cfg.PRF             = 600;
cfg.az_aperture     = 240;   % 合成孔径长度
cfg.range_half_span = 50;    % 最终显示 R0 +/- 50 m

% 二次近似下的方位调频率。符号为负，与原 SHIP.m 一致。
cfg.Ka = -2*cfg.v^2/(cfg.lambda*cfg.R0);

fprintf('单散射点位置：方位 %.1f m，中心斜距 %.3f m\n', ...
    cfg.target_az, cfg.R0);
fprintf('Kr = %.3e Hz/s，Ka = %.3f Hz/s\n\n', cfg.Kr, cfg.Ka);

%% 2. 只生成一次“未编码”的单点原始回波
[raw_base, axes_data] = generate_single_point_echo(cfg);

%% 3. 三种情况：原始点、较小间距、较大间距
% 快时间基础码为 [0, 0, pi]，对应复反射系数 [+1,+1,-1]。
% 慢时间也采用 2/3 周期为 0、1/3 周期为 pi 的 1-bit 相位码。
cases(1) = struct( ...
    'name', '00_未编码', ...
    'fast_cycles', 0, ...
    'slow_period_samples', 0);

cases(2) = struct( ...
    'name', '01_编码A_较小间距', ...
    'fast_cycles', 4, ...
    'slow_period_samples', 32);

cases(3) = struct( ...
    'name', '02_编码B_较大间距', ...
    'fast_cycles', 10, ...
    'slow_period_samples', 16);

result_dir = fullfile(code_dir, '运行结果');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

%% 4. 编码、成像、绘图
for n = 1:numel(cases)
    one_case = cases(n);

    [raw_coded, code_info] = apply_2d_1bit_code( ...
        raw_base, axes_data.tau, cfg, one_case.fast_cycles, ...
        one_case.slow_period_samples);

    fprintf('--- %s ---\n', one_case.name);
    if one_case.fast_cycles == 0
        fprintf('不加编码，理论上只在原位置出现一个主峰。\n');
    else
        fprintf('快时间基频 = %.3f MHz\n', code_info.fast_f0/1e6);
        fprintf('理论距离向相邻谐波间距 = %.3f m\n', ...
            code_info.range_spacing);
        fprintf('慢时间基频 = %.3f Hz\n', code_info.slow_f0);
        fprintf('理论方位向相邻谐波间距 = %.3f m\n', ...
            code_info.az_spacing);
    end

    [img, image_axes] = rd_focus_single_point(raw_coded, axes_data, cfg);
    analyze_and_plot_result(img, image_axes, cfg, one_case, ...
        code_info, result_dir);
    fprintf('\n');
end

fprintf('完成。图片保存在：%s\n', result_dir);
fprintf('请先看 README_先看这里.md 和 原理推导.md。\n');

