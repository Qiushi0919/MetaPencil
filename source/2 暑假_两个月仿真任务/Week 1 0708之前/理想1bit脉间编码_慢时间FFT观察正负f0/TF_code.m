%% time_coding_four_tabs_8plots.m
% ==========================================================
% 理想 1-bit 时间编码超表面
% 一个窗口，4 个标签页，每个标签页对应一种编码
%
% 每个标签页只保留 8 个图：
%
% 1. Gamma(t) 编码相位
% 2. 入射波与反射波离散频谱
% 3. |PF_k|
% 4. angle(PF_k)
% 5. |TF_k|
% 6. angle(TF_k)
% 7. |a_k|
% 8. angle(a_k)
%
% 其中：
%   PF_k = (1/T)∫g(t)e^(-j2πkf0t)dt
%   TF_k = Σ Gamma_m e^(-j2πkm/M)
%   a_k  = PF_k * TF_k
%
% 0 -> Gamma = +1  (0°)
% 1 -> Gamma = -1  (180°)
%
% 所有数值都由 MATLAB 根据时域编码自动计算，
% 没有写死 2/pi 等理论数值。
% ==========================================================

clear;
clc;
close all;

%% =========================================================
% 1. 全局参数
% ==========================================================

T = 1e-3;                          % 调制周期 1 ms
f0 = 1 / T;                        % 调制基频 1 kHz
fc = 20e3;                         % 入射单频波频率 20 kHz
Kmax = 9;                          % 谐波范围 -9~9
kList = -Kmax:Kmax;
samplesPerSlot = 2000;             % 每个时隙采样点数

%% =========================================================
% 2. 四种编码情况（按最小重复周期填写）
% ==========================================================

caseBits = {
    [0 1], ...
    [0 0 1 1], ...
    [0 0 0 1], ...
    [0 0 0 0 1 1 1 1]
    };

caseNames = {
    'Case 1：01 周期编码', ...
    'Case 2：0011 周期编码', ...
    'Case 3：0001 周期编码', ...
    'Case 4：00001111 周期编码'
    };

%% =========================================================
% 3. 创建主窗口和标签页
% ==========================================================

mainFigure = figure( ...
    'Name', '理想1-bit时间编码：8图版', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', [30, 30, 1700, 950]);

try
    mainFigure.WindowState = 'maximized';
catch
end

tabGroup = uitabgroup( ...
    'Parent', mainFigure, ...
    'Units', 'normalized', ...
    'Position', [0, 0, 1, 1]);

%% =========================================================
% 4. 逐个 Case 计算并绘图
% ==========================================================

for caseIndex = 1:numel(caseBits)

    % ------------------------------------------------------
    % 当前 Case
    % ------------------------------------------------------
    bitSeq = caseBits{caseIndex};
    caseName = caseNames{caseIndex};
    bitString = sprintf('%d', bitSeq);

    M = numel(bitSeq);             % 时隙数
    tau = T / M;                   % 单个时隙宽度

    % 理想 1-bit 反射状态
    Gamma_m = ones(1, M);
    Gamma_m(bitSeq == 1) = -1;

    % ------------------------------------------------------
    % 数值采样
    % ------------------------------------------------------
    samplesPerPeriod = M * samplesPerSlot;
    fs = samplesPerPeriod / T;
    dt = 1 / fs;

    t = (0:samplesPerPeriod-1).' * dt;
    sampleIndex = (0:samplesPerPeriod-1).';

    % ------------------------------------------------------
    % 单位门函数 g(t)
    % ------------------------------------------------------
    g = zeros(samplesPerPeriod, 1);
    g(t >= 0 & t < tau) = 1;

    % ------------------------------------------------------
    % 构造 Gamma(t)
    % ------------------------------------------------------
    Gamma_t = zeros(samplesPerPeriod, 1);

    for m = 0:M-1
        indexStart = m*samplesPerSlot + 1;
        indexEnd   = (m+1)*samplesPerSlot;
        Gamma_t(indexStart:indexEnd) = Gamma_m(m+1);
    end

    % ------------------------------------------------------
    % 入射波与反射波
    % ------------------------------------------------------
    Ei_t = exp(1j * 2*pi * fc .* t);
    Er_t = Ei_t .* Gamma_t;

    % ------------------------------------------------------
    % 计算 PF_k
    % PF_k = (1/N) Σ g[n] exp(-j2πkn/N)
    % ------------------------------------------------------
    PF = zeros(size(kList));

    for ii = 1:numel(kList)
        k = kList(ii);
        basisFunction = exp( ...
            -1j * 2*pi * k .* sampleIndex / samplesPerPeriod);

        PF(ii) = sum(g .* basisFunction) / samplesPerPeriod;
    end

    % ------------------------------------------------------
    % 计算 TF_k
    % TF_k = Σ Gamma_m exp(-j2πkm/M)
    % ------------------------------------------------------
    TF = zeros(size(kList));

    for ii = 1:numel(kList)
        k = kList(ii);
        currentTF = 0;

        for m = 0:M-1
            currentTF = currentTF + ...
                Gamma_m(m+1) * exp(-1j * 2*pi * k * m / M);
        end

        TF(ii) = currentTF;
    end

    % ------------------------------------------------------
    % 计算 a_k
    % ------------------------------------------------------
    a_k = PF .* TF;

    % ------------------------------------------------------
    % 从时域数值计算入射波与反射波谱线
    % ------------------------------------------------------
    incidentBasis = exp(-1j * 2*pi * fc .* t);

    incidentLineCoefficient = ...
        sum(Ei_t .* incidentBasis) * dt / T;

    reflectedLineFrequencies = fc + kList*f0;
    reflectedLineCoefficients = zeros(size(kList));

    for ii = 1:numel(kList)
        currentFrequency = reflectedLineFrequencies(ii);
        spectrumBasis = exp(-1j * 2*pi * currentFrequency .* t);

        reflectedLineCoefficients(ii) = ...
            sum(Er_t .* spectrumBasis) * dt / T;
    end

    % ------------------------------------------------------
    % 建立当前标签页
    % ------------------------------------------------------
    currentTab = uitab( ...
        'Parent', tabGroup, ...
        'Title', sprintf('Case %d：%s', caseIndex, bitString));

    currentLayout = tiledlayout( ...
        currentTab, ...
        4, 2, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    title( ...
        currentLayout, ...
        sprintf('%s    M=%d，T=%.3f ms，f_0=%.1f Hz', ...
        caseName, M, T*1e3, f0), ...
        'FontSize', 15, ...
        'FontWeight', 'bold');

    % ======================================================
    % 图1：Gamma(t) 相位
    % ======================================================
    ax1 = nexttile(currentLayout, 1);

    phaseGamma = mod(angle(Gamma_t)*180/pi, 360);

    stairs(ax1, t/T, phaseGamma, 'LineWidth', 1.5);
    hold(ax1, 'on');

    for m = 1:M-1
        xline(ax1, m/M, ':', 'LineWidth', 0.8);
    end

    grid(ax1, 'on');
    xlim(ax1, [0, 1]);
    ylim(ax1, [-20, 200]);
    yticks(ax1, [0, 180]);

    xlabel(ax1, '归一化时间 t/T');
    ylabel(ax1, '\angle\Gamma(t) / °');

    title(ax1, sprintf('图1：理想1-bit相位编码（%s）', bitString));

    % ======================================================
    % 图2：频谱
    % ======================================================
    ax2 = nexttile(currentLayout, 2);

    frequencyOffset = kList * f0;

    stem(ax2, 0, abs(incidentLineCoefficient), ...
        'filled', 'LineWidth', 1.5, 'MarkerSize', 7);
    hold(ax2, 'on');

    stem(ax2, frequencyOffset, abs(reflectedLineCoefficients), ...
        'filled', 'LineWidth', 1.1, 'MarkerSize', 5);

    grid(ax2, 'on');
    xlim(ax2, [-(Kmax+1)*f0, (Kmax+1)*f0]);

    xlabel(ax2, '相对载频的频率偏移 / Hz');
    ylabel(ax2, '谱线幅度');

    title(ax2, '图2：MATLAB从时域波形计算的离散频谱');

    legend(ax2, '入射波：f_c', '反射波：f_c+kf_0', ...
        'Location', 'best');

    % ======================================================
    % 图3：|PF_k|
    % ======================================================
    ax3 = nexttile(currentLayout, 3);
    drawMagnitudePlot(ax3, PF, kList, '图3：|PF_k|');

    % ======================================================
    % 图4：angle(PF_k)
    % ======================================================
    ax4 = nexttile(currentLayout, 4);
    drawPhasePlot(ax4, PF, kList, '图4：\angle PF_k');

    % ======================================================
    % 图5：|TF_k|
    % ======================================================
    ax5 = nexttile(currentLayout, 5);
    drawMagnitudePlot(ax5, TF, kList, '图5：|TF_k|');

    % ======================================================
    % 图6：angle(TF_k)
    % ======================================================
    ax6 = nexttile(currentLayout, 6);
    drawPhasePlot(ax6, TF, kList, '图6：\angle TF_k');

    % ======================================================
    % 图7：|a_k|
    % ======================================================
    ax7 = nexttile(currentLayout, 7);
    drawMagnitudePlot(ax7, a_k, kList, '图7：|a_k|');

    % ======================================================
    % 图8：angle(a_k)
    % ======================================================
    ax8 = nexttile(currentLayout, 8);
    drawPhasePlot(ax8, a_k, kList, '图8：\angle a_k');

    % ------------------------------------------------------
    % 命令行输出
    % ------------------------------------------------------
    fprintf('\n');
    fprintf('====================================================\n');
    fprintf('%s\n', caseName);
    fprintf('编码序列：%s\n', bitString);
    fprintf('M=%d，tau=%.4f ms，f0=%.2f Hz\n', M, tau*1e3, f0);
    fprintf('----------------------------------------------------\n');
    fprintf(' k       |PF|     ∠PF       |TF|     ∠TF       |a_k|    ∠a_k\n');
    fprintf('----------------------------------------------------\n');

    for ii = 1:numel(kList)
        fprintf('%3d   %8.4f %8.2f°   %8.4f %8.2f°   %8.4f %8.2f°\n', ...
            kList(ii), ...
            abs(PF(ii)), angle(PF(ii))*180/pi, ...
            abs(TF(ii)), angle(TF(ii))*180/pi, ...
            abs(a_k(ii)), angle(a_k(ii))*180/pi);
    end

end

tabGroup.SelectedTab = tabGroup.Children(end);

%% =========================================================
% 局部函数1：幅度图
% ==========================================================

function drawMagnitudePlot(ax, complexData, kList, titleText)

    stem(ax, kList, abs(complexData), ...
        'filled', 'LineWidth', 1.1, 'MarkerSize', 4);

    grid(ax, 'on');

    xlim(ax, [min(kList)-0.5, max(kList)+0.5]);
    xticks(ax, kList);

    xlabel(ax, '谐波阶数 k');
    ylabel(ax, '幅度');

    title(ax, titleText);

end

%% =========================================================
% 局部函数2：相位图
% ==========================================================

function drawPhasePlot(ax, complexData, kList, titleText)

    magnitudeData = abs(complexData);
    maximumMagnitude = max(magnitudeData);

    if maximumMagnitude < 1e-12
        maximumMagnitude = 1;
    end

    % 只对非零系数显示相位
    validIndex = magnitudeData > maximumMagnitude * 1e-6;

    phaseDegree = angle(complexData(validIndex)) * 180/pi;

    stem(ax, kList(validIndex), phaseDegree, ...
        'filled', 'LineWidth', 1.1, 'MarkerSize', 4);

    grid(ax, 'on');

    xlim(ax, [min(kList)-0.5, max(kList)+0.5]);
    ylim(ax, [-190, 190]);

    xticks(ax, kList);
    yticks(ax, [-180, -90, 0, 90, 180]);

    xlabel(ax, '谐波阶数 k');
    ylabel(ax, '相位 / °');

    title(ax, titleText);

end