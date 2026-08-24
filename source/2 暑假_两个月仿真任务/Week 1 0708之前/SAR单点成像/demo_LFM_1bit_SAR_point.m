%% demo_LFM_1bit_SAR_point.m
% 使用当前CST数据演示：
% 1) LFM波形与公式
% 2) 1-bit反射系数 Gamma 的脉内/脉间编码
% 3) 编码后的单点回波
% 4) 简化SAR距离-多普勒显示
%
% 重要说明：
% 这是“第一阶段等效验证”代码。假目标的位置由人工设置的
% 距离延时 DeltaTau 和脉间多普勒相位 exp(j*2*pi*fd*n*PRI) 决定；
% 当前CST提取的两个复反射系数 Gamma0/Gamma1 用于构造真实1-bit
% 反射调制。下一阶段再把人工延时/多普勒替换为由编码直接综合出的效果。

clear; close all; clc;

%% 0. 文件路径与输出目录
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end

csvFile = fullfile(scriptDir, 'raw_CST_Cx0p7_Cy0p7_Cy2p5.csv');
if ~isfile(csvFile)
    csvFile = fullfile(pwd, 'raw_CST_Cx0p7_Cy0p7_Cy2p5.csv');
end
if ~isfile(csvFile)
    error('找不到CSV文件：raw_CST_Cx0p7_Cy0p7_Cy2p5.csv');
end

outDir = fullfile(scriptDir, 'output_figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 1. 从CST数据自动选择接近180°相差的工作频点
T = readtable(csvFile);

requiredVars = {'Cx_val','Cy_val','frequency_GHz','real','imag'};
assert(all(ismember(requiredVars, T.Properties.VariableNames)), ...
    'CSV列名不符合预期。需要包含：Cx_val, Cy_val, frequency_GHz, real, imag');

cyStates = unique(T.Cy_val, 'stable');
assert(numel(cyStates) >= 2, 'CSV中至少需要两组Cy状态。');

cy0 = cyStates(1);
cy1 = cyStates(2);

D0 = sortrows(T(T.Cy_val == cy0, :), 'frequency_GHz');
D1 = sortrows(T(T.Cy_val == cy1, :), 'frequency_GHz');

fMin = max(min(D0.frequency_GHz), min(D1.frequency_GHz));
fMax = min(max(D0.frequency_GHz), max(D1.frequency_GHz));
fGridGHz = linspace(fMin, fMax, 6001).';

g0Grid = interp1(D0.frequency_GHz, complex(D0.real, D0.imag), ...
    fGridGHz, 'linear');
g1Grid = interp1(D1.frequency_GHz, complex(D1.real, D1.imag), ...
    fGridGHz, 'linear');

mag0dB = 20*log10(abs(g0Grid) + eps);
mag1dB = 20*log10(abs(g1Grid) + eps);
phaseDiffDeg = abs(mod(rad2deg(angle(g1Grid ./ g0Grid)) + 180, 360) - 180);

% 优先在两个状态反射幅度均高于 -5 dB 的范围内寻找180°相差点
valid = (mag0dB > -5) & (mag1dB > -5);
if any(valid)
    validIdx = find(valid);
    [~, localIdx] = min(abs(phaseDiffDeg(valid) - 180));
    idxFc = validIdx(localIdx);
else
    [~, idxFc] = min(abs(phaseDiffDeg - 180));
end

fc = fGridGHz(idxFc) * 1e9;
Gamma0 = g0Grid(idxFc);
Gamma1 = g1Grid(idxFc);

fprintf('\n===== 自动选取的1-bit工作点 =====\n');
fprintf('fc = %.6f GHz\n', fc/1e9);
fprintf('状态0：Cx=%.3f, Cy=%.3f, |Gamma0|=%.4f (%.2f dB), phase=%.2f deg\n', ...
    D0.Cx_val(1), cy0, abs(Gamma0), 20*log10(abs(Gamma0)), rad2deg(angle(Gamma0)));
fprintf('状态1：Cx=%.3f, Cy=%.3f, |Gamma1|=%.4f (%.2f dB), phase=%.2f deg\n', ...
    D1.Cx_val(1), cy1, abs(Gamma1), 20*log10(abs(Gamma1)), rad2deg(angle(Gamma1)));
fprintf('两状态最小圆周相位差 = %.2f deg\n\n', phaseDiffDeg(idxFc));

%% 2. SAR与LFM参数
c = 299792458;          % 光速
B = 80e6;               % LFM带宽 80 MHz
Tp = 8e-6;              % 脉冲宽度 8 us
K = B / Tp;             % 调频斜率
fs = 200e6;             % 快时间采样率
PRF = 1000;             % 脉冲重复频率
PRI = 1 / PRF;
Np = 128;               % 脉冲数

% 选定一个假目标点（相对于参考距离门）
R0 = 2000;              % 参考距离门中心，m
DeltaR = 30;            % 假目标距离偏移，m
DeltaTau = 2*DeltaR/c;  % 对应往返延时
fd = 156.25;            % 目标多普勒，Hz；恰好落在FFT栅格上
A = 1;                  % 散射幅度
SNRdB = 30;             % 原始回波信噪比

% 快时间窗口
Nfast = 4096;
tFast = ((0:Nfast-1) - floor(Nfast/2)) / fs;

% 基带LFM发射脉冲
txMask = abs(tFast) <= Tp/2;
sTx = zeros(1, Nfast);
sTx(txMask) = exp(1j*pi*K*tFast(txMask).^2);

%% 3. 构造1-bit脉内编码、脉间编码及组合编码
% b_intra(m)：在一个脉冲内部随快时间变化
% b_inter(n)：在不同脉冲之间随慢时间变化
% b(n,m) = xor(b_inter(n), b_intra(m))
% Gamma(n,m) = Gamma0 + [Gamma1-Gamma0] * b(n,m)

Mslot = 16;  % 每个脉冲划分为16个时隙

% 为了让“脉内”和“脉间”在图上清楚可见，同时保留单点主峰，
% 这里使用较稀疏的1状态。可以直接修改下面两个序列。
intraPattern = [0 0 0 0 1 0 0 0 0 0 0 1 0 0 0 0];

slotIndex = floor((tFast + Tp/2) / (Tp/Mslot)) + 1;
insidePulse = (slotIndex >= 1) & (slotIndex <= Mslot);

bIntra = false(1, Nfast);
bIntra(insidePulse) = logical(intraPattern(slotIndex(insidePulse)));

bInter = false(Np, 1);
bInter(49:64) = true;   % 第49~64个脉冲切换为另一种脉间状态

bCode = xor(bInter, bIntra);  % 隐式扩展：Np × Nfast
GammaCode = Gamma0 + (Gamma1 - Gamma0) .* double(bCode);

%% 4. 生成单点等效回波
% r_n(t) = A * Gamma_n(t) * s_tx(t-DeltaTau)
%          * exp(j*2*pi*fd*n*PRI) + w_n(t)

tDelayed = tFast - DeltaTau;
echoMask = abs(tDelayed) <= Tp/2;
echoPulse = zeros(1, Nfast);
echoPulse(echoMask) = exp(1j*pi*K*tDelayed(echoMask).^2);

n = (0:Np-1).';
eta = n * PRI;
dopplerPhase = exp(1j*2*pi*fd*eta);

rawEcho = A .* GammaCode .* (dopplerPhase * echoPulse);

% 加入复高斯白噪声
rng(20260708);
signalPower = mean(abs(rawEcho(:)).^2);
noisePower = signalPower / (10^(SNRdB/10));
noise = sqrt(noisePower/2) .* ...
    (randn(size(rawEcho)) + 1j*randn(size(rawEcho)));
rawEcho = rawEcho + noise;

%% 5. 距离压缩 + 慢时间FFT，形成简化SAR距离-多普勒图
Nconv = 2*Nfast - 1;
Nfft = 2^nextpow2(Nconv);

matchedFilter = conj(fliplr(sTx));
H = fft(matchedFilter, Nfft);

rangeCompressedFull = ifft(fft(rawEcho, Nfft, 2) .* H, [], 2);
rangeCompressed = rangeCompressedFull(:, 1:Nconv);

RD = fftshift(fft(rangeCompressed, Np, 1), 1);

lags = -(Nfast-1):(Nfast-1);
rangeAxis = R0 + lags * c/(2*fs);
dopplerAxis = (-Np/2:Np/2-1) * (PRF/Np);

RDdB = 20*log10(abs(RD) / max(abs(RD(:))) + eps);

[~, peakLinearIdx] = max(abs(RD(:)));
[peakDopplerIdx, peakRangeIdx] = ind2sub(size(RD), peakLinearIdx);
detectedR = rangeAxis(peakRangeIdx);
detectedFd = dopplerAxis(peakDopplerIdx);

fprintf('===== SAR检测结果 =====\n');
fprintf('设定点：距离 %.2f m，多普勒 %.2f Hz\n', R0+DeltaR, fd);
fprintf('检测峰：距离 %.2f m，多普勒 %.2f Hz\n', detectedR, detectedFd);
fprintf('理论距离分辨率 c/(2B) = %.3f m\n\n', c/(2*B));

%% 图1：LFM波形和公式
fig1 = figure('Color','w','Position',[80 80 1100 720]);

yyaxis left
plot(tFast*1e6, real(sTx), 'LineWidth', 1.0);
ylabel('Re\{s_{tx}(t)\}');
ylim([-1.15 1.15]);

yyaxis right
instFreqMHz = K*tFast/1e6;
instFreqMHz(~txMask) = NaN;
plot(tFast*1e6, instFreqMHz, '--', 'LineWidth', 1.8);
ylabel('瞬时频率 / MHz');

xlabel('脉内快时间 t / \mus');
xlim([-Tp/2, Tp/2]*1e6);
grid on;
title('图1  LFM脉冲：时域波形与线性扫频');

% formula1 = sprintf(['s_{tx}(t)=rect(t/T_p)exp(j\\pi Kt^2),   K=B/T_p\n' ...
%     'f_{inst}(t)=Kt,   B=%.0f MHz,   T_p=%.1f \\mus'], B/1e6, Tp*1e6);
% annotation(fig1, 'textbox', [0.17 0.78 0.68 0.12], ...
%     'String', formula1, 'Interpreter','tex', ...
%     'HorizontalAlignment','center', 'FontSize',14, ...
%     'BackgroundColor','w', 'EdgeColor',[0.7 0.7 0.7]);

exportgraphics(fig1, fullfile(outDir, '01_LFM_waveform_formula.png'), ...
    'Resolution', 220);

%% 图2：反射系数Gamma，明确区分脉内与脉间编码
fig2 = figure('Color','w','Position',[80 60 1250 820]);
tl = tiledlayout(fig2, 2, 2, 'TileSpacing','compact', 'Padding','compact');

% (a) 两个CST状态
nexttile;
plot(real(Gamma0), imag(Gamma0), 'o', 'MarkerSize',10, 'LineWidth',2);
hold on;
plot(real(Gamma1), imag(Gamma1), 's', 'MarkerSize',10, 'LineWidth',2);
plot([0 real(Gamma0)], [0 imag(Gamma0)], '--');
plot([0 real(Gamma1)], [0 imag(Gamma1)], '--');
axis equal; grid on;
xlabel('Re\{\Gamma\}'); ylabel('Im\{\Gamma\}');
title(sprintf('(a) CST提取的两个1-bit状态，f_c=%.4f GHz', fc/1e9));
legend(sprintf('\\Gamma_0: %.1f^\\circ, %.2f dB', ...
    rad2deg(angle(Gamma0)), 20*log10(abs(Gamma0))), ...
    sprintf('\\Gamma_1: %.1f^\\circ, %.2f dB', ...
    rad2deg(angle(Gamma1)), 20*log10(abs(Gamma1))), ...
    'Location','best');

% (b) 脉内编码
nexttile;
phaseIntra = rad2deg(angle(Gamma0 + (Gamma1-Gamma0).*double(bIntra)));
stairs(tFast(txMask)*1e6, phaseIntra(txMask), 'LineWidth',1.5);
grid on;
xlabel('单个脉冲内部的快时间 t / \mus');
ylabel('arg\{\Gamma\} / deg');
title('(b) 脉内编码：一个脉冲内部切换');

% (c) 脉间编码
nexttile;
phaseInter = rad2deg(angle(Gamma0 + (Gamma1-Gamma0).*double(bInter)));
stairs(1:Np, phaseInter, 'LineWidth',1.5);
grid on;
xlabel('脉冲序号 n');
ylabel('arg\{\Gamma\} / deg');
title('(c) 脉间编码：不同脉冲之间切换');

% (d) 组合编码矩阵
nexttile;
slotCenters = ((0:Mslot-1)+0.5) * (Tp/Mslot) - Tp/2;
codeBySlot = xor(bInter, logical(intraPattern));
imagesc(slotCenters*1e6, 1:Np, double(codeBySlot));
axis xy;
xlabel('脉内快时间时隙 / \mus');
ylabel('脉冲序号 n');
title('(d) 组合编码 b(n,m)：横向=脉内，纵向=脉间');
cb = colorbar;
cb.Ticks = [0 1];
cb.TickLabels = {'状态0','状态1'};

title(tl, sprintf(['图2  1-bit反射系数：\\Gamma_{n,m}=\\Gamma_0+(\\Gamma_1-\\Gamma_0)b_{n,m}\n' ...
    'b_{n,m}=b_{intra}(m) XOR b_{inter}(n)，两状态相位差 %.2f^\\circ'], ...
    phaseDiffDeg(idxFc)), 'FontWeight','bold');

exportgraphics(fig2, fullfile(outDir, '02_Gamma_intra_inter_code.png'), ...
    'Resolution', 220);

%% 图3：回波波形
fig3 = figure('Color','w','Position',[80 80 1150 760]);
tl3 = tiledlayout(fig3, 2, 1, 'TileSpacing','compact', 'Padding','compact');

pulseToShow = 20;

nexttile;
plot(tFast*1e6, real(sTx), '--', 'LineWidth',1.0);
hold on;
echoNorm = rawEcho(pulseToShow,:) / (max(abs(rawEcho(pulseToShow,:))) + eps);
plot(tFast*1e6, real(echoNorm), 'LineWidth',1.0);
xlim([-Tp/2-0.7e-6, Tp/2+0.7e-6]*1e6);
grid on;
xlabel('快时间 t / \mus');
ylabel('归一化实部');
title(sprintf('(a) 第%d个脉冲：发射LFM与编码回波', pulseToShow));
legend('发射LFM','延时+1-bit编码后的回波','Location','best');

nexttile;
imagesc(tFast*1e6, 1:Np, abs(rawEcho));
axis xy;
xlim([-Tp/2-0.7e-6, Tp/2+0.7e-6]*1e6);
xlabel('快时间 t / \mus');
ylabel('脉冲序号 n');
title('(b) 原始回波矩阵 |\itr_n(t)\rm|：横向为距离快时间，纵向为方位慢时间');
colorbar;

title(tl3, sprintf(['图3  r_n(t)=A\\Gamma_n(t)s_{tx}(t-\\Delta\\tau)' ...
    'exp(j2\\pi f_dnT_r)+w_n(t)\n' ...
    '\\Delta\\tau=2\\Delta R/c=%.3f \\mus，\\Delta R=%.1f m，f_d=%.2f Hz'], ...
    DeltaTau*1e6, DeltaR, fd), 'FontWeight','bold');

exportgraphics(fig3, fullfile(outDir, '03_coded_echo_waveform.png'), ...
    'Resolution', 220);

%% 图4：简化SAR距离-多普勒显示
fig4 = figure('Color','w','Position',[100 80 1050 760]);

rangeWindow = [R0-50, R0+90];
dopplerWindow = [-300, 300];

rangeKeep = rangeAxis >= rangeWindow(1) & rangeAxis <= rangeWindow(2);
dopplerKeep = dopplerAxis >= dopplerWindow(1) & dopplerAxis <= dopplerWindow(2);

imagesc(rangeAxis(rangeKeep), dopplerAxis(dopplerKeep), ...
    RDdB(dopplerKeep, rangeKeep));
axis xy;
xlabel('距离 / m');
ylabel('多普勒频率 / Hz');
title('图4  简化SAR距离-多普勒显示：单个假目标点');
cb4 = colorbar;
ylabel(cb4, '归一化幅度 / dB');
caxis([-45 0]);
grid on;
hold on;

plot(R0+DeltaR, fd, 'wo', 'MarkerSize',12, 'LineWidth',2);
plot(detectedR, detectedFd, 'w+', 'MarkerSize',12, 'LineWidth',2);
text(R0+DeltaR+3, fd+15, ...
    sprintf('设定点 (%.1f m, %.2f Hz)', R0+DeltaR, fd), ...
    'Color','w', 'FontWeight','bold');
text(detectedR+3, detectedFd-25, ...
    sprintf('检测峰 (%.1f m, %.2f Hz)', detectedR, detectedFd), ...
    'Color','w', 'FontWeight','bold');

exportgraphics(fig4, fullfile(outDir, '04_SAR_range_doppler_point.png'), ...
    'Resolution', 220);

fprintf('四张图已保存到：\n%s\n', outDir);
fprintf('  01_LFM_waveform_formula.png\n');
fprintf('  02_Gamma_intra_inter_code.png\n');
fprintf('  03_coded_echo_waveform.png\n');
fprintf('  04_SAR_range_doppler_point.png\n');
