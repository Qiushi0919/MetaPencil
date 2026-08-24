%% ideal_1bit_slowtime_fft_tabs_full_v2.m
% 理想 1-bit 脉间相位编码与慢时间 FFT
%
% Fig1：连续雷达脉冲与脉间编码
% Fig2：理想反射系数的幅度和相位
% Fig3：编码前后的慢时间回波
% Fig4：慢时间 FFT 中观察 ±f0
% Fig5：连续单频入射波、反射系数、回波、谐波谱
% Fig6：连续雷达脉冲列、反射系数、反射脉冲和慢时间 FFT
%
% 核心关系：
%
%   入射波：
%       E_i(t)
%
%   理想1-bit反射系数：
%       Gamma0 = +1
%       Gamma1 = -1
%
%   反射回波：
%       E_r(t) = Gamma(t) E_i(t)
%
% 注意：
%   入射波本身不编码；
%   编码只作用在反射系数 Gamma 上。
%
% 不需要额外工具箱。

clear;
clc;
close all;

%% =========================================================
%  1. 雷达慢时间参数
% ==========================================================

PRF = 1000;                         % 脉冲重复频率，Hz
Tr  = 1 / PRF;                      % 脉冲重复周期，s

Np = 800;                           % 总脉冲数
n  = (0:Np-1).';                    % 脉冲序号
eta = n * Tr;                       % 慢时间，s

% 一个脉间编码周期包含的雷达脉冲数
pulsesPerPeriod = 40;

assert(mod(pulsesPerPeriod,2) == 0, ...
    'pulsesPerPeriod 必须为偶数。');

assert(mod(Np,pulsesPerPeriod) == 0, ...
    'Np 必须为 pulsesPerPeriod 的整数倍。');

% 时间调制频率
f0 = PRF / pulsesPerPeriod;

% 时间调制周期
T0 = 1 / f0;

%% =========================================================
%  2. 理想 1-bit 反射状态
% ==========================================================

Gamma0 = 1 * exp(1j * 0);           % 1∠0°   = +1
Gamma1 = 1 * exp(1j * pi);          % 1∠180° = -1

%% =========================================================
%  3. 构造周期性脉间编码
% ==========================================================

% 一个编码周期内：
%
% 前20个脉冲：
%   Gamma = +1
%
% 后20个脉冲：
%   Gamma = -1

pulseInPeriod = mod(n, pulsesPerPeriod);

bitCode = pulseInPeriod >= pulsesPerPeriod/2;

GammaSlow = Gamma0 * ones(Np,1);

GammaSlow(bitCode) = Gamma1;

%% =========================================================
%  4. 构造固定距离单元的慢时间回波
% ==========================================================

% 假设已经选定了一个固定距离单元。
%
% 未编码静止目标：
%
%   s_uncoded[n] = A
%
% 编码后的回波：
%
%   s_coded[n] = Gamma[n] A

A = 1;

% 原始目标多普勒
% 设置为0，表示目标本身位于零多普勒
fdTarget = 0;

targetDopplerPhase = exp(1j * 2*pi * fdTarget .* eta);

% 未编码慢时间回波
slowEchoUncoded = A .* targetDopplerPhase;

% 编码后的慢时间回波
slowEchoCoded = GammaSlow .* slowEchoUncoded;

%% =========================================================
%  5. 慢时间 FFT
% ==========================================================

S_uncoded = fftshift(fft(slowEchoUncoded)) / Np;

S_coded = fftshift(fft(slowEchoCoded)) / Np;

fdAxis = (-Np/2 : Np/2-1).' * PRF / Np;

magUncoded = abs(S_uncoded);

magCoded = abs(S_coded);

powerCoded = abs(S_coded).^2;

powerCodedPercent = ...
    100 * powerCoded / sum(powerCoded);

%% =========================================================
%  6. 提取主要谐波
% ==========================================================

Kmax = 9;

kList = (-Kmax:Kmax).';

harmonicFreq = fdTarget + kList * f0;

harmonicAmplitude = zeros(size(kList));

harmonicPowerPercent = zeros(size(kList));

for ii = 1:length(kList)

    [~, index] = min( ...
        abs(fdAxis - harmonicFreq(ii)));

    harmonicAmplitude(ii) = ...
        magCoded(index);

    harmonicPowerPercent(ii) = ...
        powerCodedPercent(index);

end

indexZero = find(kList == 0);

indexPositiveOne = find(kList == 1);

indexNegativeOne = find(kList == -1);

%% =========================================================
%  7. 命令行输出
% ==========================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('       理想1-bit脉间编码与慢时间FFT仿真结果\n');
fprintf('====================================================\n');

fprintf('脉冲重复频率 PRF：          %.2f Hz\n', PRF);

fprintf('总脉冲数 Np：               %d\n', Np);

fprintf('每个编码周期脉冲数：        %d\n', ...
    pulsesPerPeriod);

fprintf('调制频率 f0：                %.2f Hz\n', f0);

fprintf('调制周期 T0：                %.2f ms\n', ...
    T0 * 1e3);

fprintf('FFT频率分辨率：              %.3f Hz\n', ...
    PRF / Np);

fprintf('\n');

fprintf('零阶谐波功率占比：           %.6f %%\n', ...
    harmonicPowerPercent(indexZero));

fprintf('+1阶谐波功率占比：           %.3f %%\n', ...
    harmonicPowerPercent(indexPositiveOne));

fprintf('-1阶谐波功率占比：           %.3f %%\n', ...
    harmonicPowerPercent(indexNegativeOne));

fprintf('正负一阶合计功率占比：       %.3f %%\n', ...
    harmonicPowerPercent(indexPositiveOne) + ...
    harmonicPowerPercent(indexNegativeOne));

fprintf('连续方波理论值 8/pi^2：      %.3f %%\n', ...
    100 * 8 / pi^2);

fprintf('====================================================\n');
fprintf('\n');

%% =========================================================
%  8. 基础绘图数据
% ==========================================================

showPeriods = 3;

showPulseNumber = ...
    showPeriods * pulsesPerPeriod;

nShow = n(1:showPulseNumber);

etaShow_ms = ...
    eta(1:showPulseNumber) * 1e3;

bitCodeShow = ...
    bitCode(1:showPulseNumber);

GammaShow = ...
    GammaSlow(1:showPulseNumber);

uncodedShow = ...
    slowEchoUncoded(1:showPulseNumber);

codedShow = ...
    slowEchoCoded(1:showPulseNumber);

phaseShowDeg = ...
    mod(angle(GammaShow) * 180/pi, 360);

%% =========================================================
%  9. 创建主窗口和选项卡
% ==========================================================

mainFigure = figure( ...
    'Name', ...
    '理想1-bit脉间编码与慢时间FFT', ...
    'NumberTitle', ...
    'off', ...
    'Color', ...
    'w', ...
    'Position', ...
    [30, 30, 1500, 920]);

tabGroup = uitabgroup( ...
    'Parent', mainFigure, ...
    'Units', 'normalized', ...
    'Position', [0, 0, 1, 1]);

tab1 = uitab( ...
    'Parent', tabGroup, ...
    'Title', 'Fig1 连续脉冲与编码');

tab2 = uitab( ...
    'Parent', tabGroup, ...
    'Title', 'Fig2 反射系数');

tab3 = uitab( ...
    'Parent', tabGroup, ...
    'Title', 'Fig3 慢时间回波');

tab4 = uitab( ...
    'Parent', tabGroup, ...
    'Title', 'Fig4 慢时间FFT');

tab5 = uitab( ...
    'Parent', tabGroup, ...
    'Title', 'Fig5 连续单频波对照');

tab6 = uitab( ...
    'Parent', tabGroup, ...
    'Title', 'Fig6 连续雷达脉冲版');

%% =========================================================
%  Fig1：连续雷达脉冲与脉间编码
% ==========================================================

layout1 = tiledlayout( ...
    tab1, ...
    3, 1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

title(layout1, ...
    'Fig1：连续雷达脉冲与理想1-bit脉间编码', ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

ax11 = nexttile(layout1);

stem( ...
    ax11, ...
    etaShow_ms, ...
    ones(showPulseNumber,1), ...
    'filled', ...
    'LineWidth', 1.0, ...
    'MarkerSize', 3);

grid(ax11, 'on');

ylim(ax11, [0, 1.25]);

xlabel(ax11, '慢时间 \eta / ms');

ylabel(ax11, '雷达脉冲');

title(ax11, ...
    sprintf('连续雷达脉冲，PRF = %.0f Hz', PRF));

ax12 = nexttile(layout1);

stairs( ...
    ax12, ...
    etaShow_ms, ...
    double(bitCodeShow), ...
    'LineWidth', 1.8);

grid(ax12, 'on');

ylim(ax12, [-0.2, 1.2]);

yticks(ax12, [0, 1]);

xlabel(ax12, '慢时间 \eta / ms');

ylabel(ax12, '编码位');

title(ax12, ...
    sprintf('每%d个雷达脉冲构成一个编码周期', ...
    pulsesPerPeriod));

ax13 = nexttile(layout1);

stairs( ...
    ax13, ...
    etaShow_ms, ...
    real(GammaShow), ...
    'LineWidth', 1.8);

grid(ax13, 'on');

ylim(ax13, [-1.3, 1.3]);

yticks(ax13, [-1, 1]);

xlabel(ax13, '慢时间 \eta / ms');

ylabel(ax13, 'Re\{\Gamma[n]\}');

title(ax13, ...
    sprintf('\\Gamma[n]=+1/-1，调制频率 f_0=%.1f Hz', ...
    f0));

%% =========================================================
%  Fig2：理想反射系数
% ==========================================================

layout2 = tiledlayout( ...
    tab2, ...
    3, 1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

title(layout2, ...
    'Fig2：理想1-bit反射系数', ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

ax21 = nexttile(layout2);

stairs( ...
    ax21, ...
    nShow, ...
    double(bitCodeShow), ...
    'LineWidth', 1.8);

grid(ax21, 'on');

ylim(ax21, [-0.2, 1.2]);

yticks(ax21, [0, 1]);

xlabel(ax21, '脉冲序号 n');

ylabel(ax21, '编码位');

title(ax21, ...
    '脉间1-bit编码序列');

ax22 = nexttile(layout2);

stairs( ...
    ax22, ...
    nShow, ...
    abs(GammaShow), ...
    'LineWidth', 1.8);

grid(ax22, 'on');

ylim(ax22, [0, 1.2]);

xlabel(ax22, '脉冲序号 n');

ylabel(ax22, '|\Gamma[n]|');

title(ax22, ...
    '理想反射幅度始终等于1');

ax23 = nexttile(layout2);

stairs( ...
    ax23, ...
    nShow, ...
    phaseShowDeg, ...
    'LineWidth', 1.8);

grid(ax23, 'on');

ylim(ax23, [-20, 200]);

yticks(ax23, [0, 180]);

xlabel(ax23, '脉冲序号 n');

ylabel(ax23, '\angle\Gamma[n] / °');

title(ax23, ...
    '反射相位在0°和180°之间周期切换');

%% =========================================================
%  Fig3：编码前后的慢时间回波
% ==========================================================

layout3 = tiledlayout( ...
    tab3, ...
    3, 1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

title(layout3, ...
    'Fig3：编码前后的慢时间回波', ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

ax31 = nexttile(layout3);

plot( ...
    ax31, ...
    nShow, ...
    real(uncodedShow), ...
    'o-', ...
    'LineWidth', 1.2, ...
    'MarkerSize', 4);

grid(ax31, 'on');

ylim(ax31, [-1.3, 1.3]);

xlabel(ax31, '脉冲序号 n');

ylabel(ax31, '回波实部');

title(ax31, ...
    '未编码静止目标：慢时间回波保持不变');

ax32 = nexttile(layout3);

plot( ...
    ax32, ...
    nShow, ...
    real(codedShow), ...
    'o-', ...
    'LineWidth', 1.2, ...
    'MarkerSize', 4);

grid(ax32, 'on');

ylim(ax32, [-1.3, 1.3]);

xlabel(ax32, '脉冲序号 n');

ylabel(ax32, '回波实部');

title(ax32, ...
    '加入脉间编码后：回波在+1和-1之间切换');

ax33 = nexttile(layout3);

plot( ...
    ax33, ...
    real(codedShow), ...
    imag(codedShow), ...
    'o', ...
    'LineWidth', 1.3, ...
    'MarkerSize', 6);

grid(ax33, 'on');

axis(ax33, 'equal');

xlim(ax33, [-1.3, 1.3]);

ylim(ax33, [-1.3, 1.3]);

xlabel(ax33, '实部');

ylabel(ax33, '虚部');

title(ax33, ...
    '编码回波在复平面上的两个状态');

%% =========================================================
%  Fig4：慢时间FFT
% ==========================================================

layout4 = tiledlayout( ...
    tab4, ...
    2, 1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

title(layout4, ...
    'Fig4：慢时间FFT中观察正负f_0', ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

ax41 = nexttile(layout4);

stem( ...
    ax41, ...
    fdAxis, ...
    magUncoded, ...
    'filled', ...
    'LineWidth', 1.0, ...
    'MarkerSize', 3);

grid(ax41, 'on');

xlim(ax41, [-6*f0, 6*f0]);

ylim(ax41, [0, 1.1]);

xlabel(ax41, '多普勒频率 / Hz');

ylabel(ax41, '归一化幅度');

title(ax41, ...
    '未编码：能量集中在零多普勒0 Hz');

ax42 = nexttile(layout4);

stem( ...
    ax42, ...
    fdAxis, ...
    magCoded, ...
    'filled', ...
    'LineWidth', 1.0, ...
    'MarkerSize', 3);

grid(ax42, 'on');

xlim(ax42, [-6*f0, 6*f0]);

ylim(ax42, [0, 1.1*max(magCoded)]);

xlabel(ax42, '多普勒频率 / Hz');

ylabel(ax42, '归一化幅度');

title(ax42, ...
    '编码后：出现\pmf_0、\pm3f_0、\pm5f_0');

hold(ax42, 'on');

xline( ...
    ax42, ...
    f0, ...
    '--', ...
    sprintf('+f_0 = +%.1f Hz', f0));

xline( ...
    ax42, ...
    -f0, ...
    '--', ...
    sprintf('-f_0 = -%.1f Hz', f0));

xline( ...
    ax42, ...
    0, ...
    ':', ...
    '零阶');

%% =========================================================
%  Fig5：连续单频入射波对照
% ==========================================================

% 这里的入射波对所有编码情况完全相同。
%
% 入射波：
%
%   E_i(t) = exp(j2πf_c t)
%
% 只有反射系数 Gamma(t) 随编码改变。
%
% 回波：
%
%   E_r(t) = Gamma(t) E_i(t)

M = 16;

samplesPerSlot = 50;

periodsToShow = 2;

samplesPerCodePeriod = ...
    M * samplesPerSlot;

totalShowSamples = ...
    periodsToShow * samplesPerCodePeriod;

timeNormalized = ...
    (0:totalShowSamples-1).' / samplesPerCodePeriod;

% 为显示方便，每个调制周期画8个载波周期
visibleCarrierCycles = 8;

% 这是固定的、未编码的入射波
incidentCW = exp( ...
    1j * 2*pi * visibleCarrierCycles .* timeNormalized);

codeCase1 = repmat([0 1], 1, 8);

codeCase2 = repmat([0 0 1 1], 1, 4);

codeCase3 = ...
    [0 0 0 0 1 1 1 1 ...
     0 0 0 0 1 1 1 1];

codeCase4 = ...
    [0 0 0 1 0 0 0 1 ...
     0 0 0 1 0 0 0 1];

allCodeCases = { ...
    codeCase1, ...
    codeCase2, ...
    codeCase3, ...
    codeCase4};

caseNames = { ...
    '01010101...', ...
    '00110011...', ...
    '00001111...', ...
    '00010001...'};

layout5 = tiledlayout( ...
    tab5, ...
    4, 4, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

title(layout5, ...
    ['Fig5：入射波始终相同，' ...
     '编码只作用在反射系数上'], ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

harmonicOrders = -8:8;

for caseIndex = 1:4

    currentCode = ...
        allCodeCases{caseIndex};

    gammaSlots = ones(1,M);

    gammaSlots(currentCode == 1) = -1;

    gammaOnePeriod = repelem( ...
        gammaSlots, ...
        samplesPerSlot).';

    gammaTime = repmat( ...
        gammaOnePeriod, ...
        periodsToShow, ...
        1);

    gammaPhaseDeg = zeros(size(gammaTime));

    gammaPhaseDeg(real(gammaTime) < 0) = 180;

    % 只有这里才将反射系数乘到入射波上
    reflectedCW = gammaTime .* incidentCW;

    sampleIndexOnePeriod = ...
        (0:samplesPerCodePeriod-1).';

    harmonicCoefficient = ...
        zeros(size(harmonicOrders));

    for harmonicIndex = 1:length(harmonicOrders)

        currentOrder = ...
            harmonicOrders(harmonicIndex);

        basisFunction = exp( ...
            -1j * 2*pi * currentOrder .* ...
            sampleIndexOnePeriod / ...
            samplesPerCodePeriod);

        harmonicCoefficient(harmonicIndex) = ...
            mean(gammaOnePeriod .* basisFunction);

    end

    harmonicMagnitude = ...
        abs(harmonicCoefficient);

    % -----------------------------------------------------
    % 第1列：固定的入射波
    % -----------------------------------------------------

    axIncident = nexttile( ...
        layout5, ...
        (caseIndex-1)*4 + 1);

    plot( ...
        axIncident, ...
        timeNormalized, ...
        real(incidentCW), ...
        'LineWidth', 1.2);

    grid(axIncident, 'on');

    ylim(axIncident, [-1.2, 1.2]);

    xlabel(axIncident, '时间 / T');

    ylabel(axIncident, '幅度');

    title(axIncident, ...
        '固定入射波 E_i(t)');

    % -----------------------------------------------------
    % 第2列：反射系数
    % -----------------------------------------------------

    axGamma = nexttile( ...
        layout5, ...
        (caseIndex-1)*4 + 2);

    stairs( ...
        axGamma, ...
        timeNormalized, ...
        gammaPhaseDeg, ...
        'LineWidth', 1.5);

    grid(axGamma, 'on');

    ylim(axGamma, [-20, 200]);

    yticks(axGamma, [0, 180]);

    xlabel(axGamma, '时间 / T');

    ylabel(axGamma, '相位 / °');

    title(axGamma, ...
        ['\Gamma(t)：', caseNames{caseIndex}]);

    % -----------------------------------------------------
    % 第3列：编码后的反射回波
    % -----------------------------------------------------

    axReflected = nexttile( ...
        layout5, ...
        (caseIndex-1)*4 + 3);

    plot( ...
        axReflected, ...
        timeNormalized, ...
        real(reflectedCW), ...
        'LineWidth', 1.2);

    grid(axReflected, 'on');

    ylim(axReflected, [-1.2, 1.2]);

    xlabel(axReflected, '时间 / T');

    ylabel(axReflected, '幅度');

    title(axReflected, ...
        'E_r(t)=\Gamma(t)E_i(t)');

    % -----------------------------------------------------
    % 第4列：谐波频谱
    % -----------------------------------------------------

    axSpectrum = nexttile( ...
        layout5, ...
        (caseIndex-1)*4 + 4);

    stem( ...
        axSpectrum, ...
        harmonicOrders, ...
        harmonicMagnitude, ...
        'filled', ...
        'LineWidth', 1.1, ...
        'MarkerSize', 4);

    grid(axSpectrum, 'on');

    xlim(axSpectrum, [-8.5, 8.5]);

    ylim(axSpectrum, ...
        [0, max(harmonicMagnitude)*1.15 + 0.02]);

    xlabel(axSpectrum, '谐波阶数 k');

    ylabel(axSpectrum, '|a_k|');

    title(axSpectrum, ...
        '反射系数谐波谱');

end

%% =========================================================
%  Fig6：连续雷达脉冲版本
% ==========================================================

% 这一部分模拟真正的连续雷达脉冲列：
%
% 脉冲1、脉冲2、脉冲3……
%
% 入射脉冲本身完全相同，不进行编码。
%
% 超表面只在不同脉冲之间切换：
%
%   Gamma[n] = +1 或 -1
%
% 因此反射脉冲为：
%
%   E_r(t,n) = Gamma[n] E_i(t,n)

numberOfPulseTrainPulses = 80;

samplesPerPRI = 200;

pulseDutyRatio = 0.30;

pulseWidth = pulseDutyRatio * Tr;

fastSampleRate = samplesPerPRI * PRF;

totalPulseTrainSamples = ...
    numberOfPulseTrainPulses * samplesPerPRI;

pulseTrainTime = ...
    (0:totalPulseTrainSamples-1).' / fastSampleRate;

% 当前采样点属于第几个脉冲
pulseNumberAtSample = ...
    floor(pulseTrainTime / Tr) + 1;

pulseNumberAtSample( ...
    pulseNumberAtSample > numberOfPulseTrainPulses) = ...
    numberOfPulseTrainPulses;

% 每个PRI内部的时间
timeInsidePRI = ...
    mod(pulseTrainTime, Tr);

% 矩形脉冲包络
pulseEnvelope = ...
    double(timeInsidePRI < pulseWidth);

% 为了在图中看清载波，
% 每个雷达脉冲内部设置5个可视化载波周期
visibleCyclesInsidePulse = 5;

visiblePulseCarrierFrequency = ...
    visibleCyclesInsidePulse / pulseWidth;

% 连续雷达入射脉冲列
% 注意：这里没有乘任何编码
incidentPulseTrain = ...
    pulseEnvelope .* ...
    exp(1j * 2*pi * ...
    visiblePulseCarrierFrequency .* pulseTrainTime);

% 取前80个脉冲对应的反射系数
GammaPulseSequence = ...
    GammaSlow(1:numberOfPulseTrainPulses);

% 将每个脉冲的Gamma扩展到该PRI内所有采样点
GammaPulseTime = ...
    GammaPulseSequence(pulseNumberAtSample);

% 编码只施加在反射波上
reflectedPulseTrain = ...
    GammaPulseTime .* incidentPulseTrain;

% 慢时间采样：
% 取每个脉冲中心位置的复包络
slowIncidentSamples = ...
    ones(numberOfPulseTrainPulses,1);

slowReflectedSamples = ...
    GammaPulseSequence;

% 对这80个脉冲做慢时间FFT
pulseTrainFFTUncoded = ...
    fftshift(fft(slowIncidentSamples)) / ...
    numberOfPulseTrainPulses;

pulseTrainFFTCoded = ...
    fftshift(fft(slowReflectedSamples)) / ...
    numberOfPulseTrainPulses;

pulseTrainDopplerAxis = ...
    (-numberOfPulseTrainPulses/2 : ...
    numberOfPulseTrainPulses/2-1).' * ...
    PRF / numberOfPulseTrainPulses;

layout6 = tiledlayout( ...
    tab6, ...
    3, 2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

title(layout6, ...
    ['Fig6：连续雷达脉冲列不编码，' ...
     '1-bit编码只作用在反射过程'], ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

% ---------------------------------------------------------
% 图6-1：连续入射脉冲列包络
% ---------------------------------------------------------

ax61 = nexttile(layout6);

plot( ...
    ax61, ...
    pulseTrainTime * 1e3, ...
    pulseEnvelope, ...
    'LineWidth', 1.2);

grid(ax61, 'on');

ylim(ax61, [-0.1, 1.2]);

xlabel(ax61, '时间 / ms');

ylabel(ax61, '脉冲包络');

title(ax61, ...
    '连续入射雷达脉冲列：每个脉冲完全相同');

% ---------------------------------------------------------
% 图6-2：不同脉冲对应的反射系数
% ---------------------------------------------------------

ax62 = nexttile(layout6);

stairs( ...
    ax62, ...
    0:numberOfPulseTrainPulses-1, ...
    real(GammaPulseSequence), ...
    'LineWidth', 1.6);

grid(ax62, 'on');

ylim(ax62, [-1.3, 1.3]);

yticks(ax62, [-1, 1]);

xlabel(ax62, '脉冲序号 n');

ylabel(ax62, 'Re\{\Gamma[n]\}');

title(ax62, ...
    '超表面脉间编码：不同脉冲乘以+1或-1');

% ---------------------------------------------------------
% 图6-3：放大观察入射脉冲
% ---------------------------------------------------------

zoomPulseCount = 8;

zoomSamples = ...
    zoomPulseCount * samplesPerPRI;

ax63 = nexttile(layout6);

plot( ...
    ax63, ...
    pulseTrainTime(1:zoomSamples) * 1e3, ...
    real(incidentPulseTrain(1:zoomSamples)), ...
    'LineWidth', 1.1);

grid(ax63, 'on');

ylim(ax63, [-1.2, 1.2]);

xlabel(ax63, '时间 / ms');

ylabel(ax63, '幅度');

title(ax63, ...
    '入射脉冲列 E_i(t)：没有编码');

% ---------------------------------------------------------
% 图6-4：放大观察反射脉冲
% ---------------------------------------------------------

ax64 = nexttile(layout6);

plot( ...
    ax64, ...
    pulseTrainTime(1:zoomSamples) * 1e3, ...
    real(reflectedPulseTrain(1:zoomSamples)), ...
    'LineWidth', 1.1);

grid(ax64, 'on');

ylim(ax64, [-1.2, 1.2]);

xlabel(ax64, '时间 / ms');

ylabel(ax64, '幅度');

title(ax64, ...
    '反射脉冲列 E_r(t)=\Gamma[n]E_i(t)');

% ---------------------------------------------------------
% 图6-5：脉冲之间的慢时间样本
% ---------------------------------------------------------

ax65 = nexttile(layout6);

plot( ...
    ax65, ...
    0:numberOfPulseTrainPulses-1, ...
    real(slowIncidentSamples), ...
    'o-', ...
    'LineWidth', 1.0, ...
    'MarkerSize', 3);

hold(ax65, 'on');

plot( ...
    ax65, ...
    0:numberOfPulseTrainPulses-1, ...
    real(slowReflectedSamples), ...
    's-', ...
    'LineWidth', 1.0, ...
    'MarkerSize', 3);

grid(ax65, 'on');

ylim(ax65, [-1.3, 1.3]);

xlabel(ax65, '脉冲序号 n');

ylabel(ax65, '慢时间样本');

title(ax65, ...
    '每个脉冲抽取一个慢时间样本');

legend( ...
    ax65, ...
    '入射脉冲样本', ...
    '反射脉冲样本', ...
    'Location', 'best');

% ---------------------------------------------------------
% 图6-6：慢时间FFT
% ---------------------------------------------------------

ax66 = nexttile(layout6);

stem( ...
    ax66, ...
    pulseTrainDopplerAxis, ...
    abs(pulseTrainFFTUncoded), ...
    'LineWidth', 1.0, ...
    'MarkerSize', 3);

hold(ax66, 'on');

stem( ...
    ax66, ...
    pulseTrainDopplerAxis, ...
    abs(pulseTrainFFTCoded), ...
    'LineWidth', 1.0, ...
    'MarkerSize', 3);

grid(ax66, 'on');

xlim(ax66, [-6*f0, 6*f0]);

xlabel(ax66, '多普勒频率 / Hz');

ylabel(ax66, '归一化幅度');

title(ax66, ...
    '连续脉冲列的慢时间FFT');

legend( ...
    ax66, ...
    '未编码：0 Hz', ...
    '编码后：\pmf_0等谐波', ...
    'Location', 'best');

xline( ...
    ax66, ...
    f0, ...
    '--', ...
    '+f_0');

xline( ...
    ax66, ...
    -f0, ...
    '--', ...
    '-f_0');

%% =========================================================
%  10. 默认打开Fig6
% ==========================================================

tabGroup.SelectedTab = tab6;