%% 理想化 SAR 舰船散射中心图像演示
% 目的：

% 2) 显示这些散射中心在理想 SAR 图像中的位置；
% 3) 计算每个点对应的附加时延与近似多普勒偏移。
%
% 注意：
% 本代码使用二维点扩散函数生成“理想化成像结果”，
% 不是完整的原始回波仿真、距离徙动校正和方位匹配滤波程序。

clear; clc; close all;

%% ===================== 只需优先修改这里 =====================

% 每行：[距离向偏移 dR(m), 方位向偏移 dx(m), 相对强度]
% 可将这些点排成简化的船头、舰桥、桅杆、舷侧和船尾。
tarSAR = [
    -45, -10, 0.65;   % 船头
    -25,  -5, 0.45;   % 前甲板
     -5,   0, 1.00;   % 舰桥主散射中心
      5,   8, 0.80;   % 桅杆
     15,   0, 0.55;   % 舷侧
     35,  -4, 0.60;   % 后甲板
     50,  -8, 0.70    % 船尾
];

%% ===================== SAR 与显示参数 =====================

c0 = 299792458;
fc = 10e9;                 % 载频
lambda0 = c0/fc;
R0 = 10e3;                 % 场景中心斜距
v  = 150;                  % 平台速度

rhoR = 3;                  % 理想距离分辨率/点扩散尺度（m）
rhoA = 3;                  % 理想方位分辨率/点扩散尺度（m）

rangeAxis   = linspace(-80, 80, 801);
azimuthAxis = linspace(-50, 50, 601);
[Rg, Az] = meshgrid(rangeAxis, azimuthAxis);

%% ===================== 构造理想 SAR 图像 =====================

img = zeros(size(Rg));

for q = 1:size(tarSAR,1)
    dR  = tarSAR(q,1);
    dx  = tarSAR(q,2);
    amp = tarSAR(q,3);

    % MATLAB sinc(x) = sin(pi*x)/(pi*x)
    psfR = sinc((Rg-dR)/rhoR);
    psfA = sinc((Az-dx)/rhoA);

    % 为便于观察，采用幅度包络叠加
    img = img + amp .* abs(psfR .* psfA);
end

img = img / max(img(:));
imgdB = 20*log10(img + 1e-6);
imgdB(imgdB < -40) = -40;

figure('Color','w');
imagesc(rangeAxis, azimuthAxis, imgdB);
axis xy image;
caxis([-40 0]);
colorbar;
xlabel('距离向偏移 \DeltaR / m');
ylabel('方位向偏移 \Deltax / m');
title('理想化 SAR 舰船散射中心图像 / dB');
hold on;
plot(tarSAR(:,1), tarSAR(:,2), 'wx', 'LineWidth', 1.5, 'MarkerSize', 8);

%% ===================== 时延与多普勒参数换算 =====================

deltaTau = 2*tarSAR(:,1)/c0;

% 正侧视、小偏移近似；符号取决于坐标和傅里叶约定
deltaFD = 2*v*tarSAR(:,2)/(lambda0*R0);

fprintf('散射点参数换算：\n');
fprintf('编号   dR(m)    dx(m)    A      Δτ(ns)    近似ΔfD(Hz)\n');
for q = 1:size(tarSAR,1)
    fprintf('%2d   %7.2f  %7.2f  %5.2f   %9.3f   %10.3f\n', ...
        q, tarSAR(q,1), tarSAR(q,2), tarSAR(q,3), ...
        deltaTau(q)*1e9, deltaFD(q));
end

%% ===================== 关键关系 =====================
% 距离向：
%   ΔR = c0*Δτ/2
%
% 方位向（正侧视、小偏移近似）：
%   ΔfD ≈ 2*v*Δx/(lambda0*R0)
%
% 完整、聚焦良好的 SAR 假点需要设计整个慢时间相位历程：
%   phi_q(eta) = -4*pi*R_q(eta)/lambda0
% 而不仅是给一个恒定的频移。
