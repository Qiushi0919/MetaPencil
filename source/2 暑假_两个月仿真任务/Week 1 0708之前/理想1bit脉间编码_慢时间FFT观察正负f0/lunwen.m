%% time_coding_full_flow_demo.m
% ==========================================================
% 理想 1-bit 时间编码超表面完整流程
%
% 对应理论关系：
%
%   Er(t) = Ei(t) * Gamma(t)
%
%   Gamma(t) = sum Gamma_m g(t-m*tau)
%
%   a_k = PF_k * TF_k
%
%   Gamma(f) = sum a_k delta(f-k*f0)
%
%   Er(f) = sum a_k Ei(f-k*f0)
%
% 对于单频入射波：
%
%   Ei(f) = delta(f-fc)
%
%   Er(f) = sum a_k delta(f-fc-k*f0)
%
% 当前编码：
%   bitSeq = [0 1]
%
% 映射关系：
%   0 -> Gamma = +1，反射相位 0°
%   1 -> Gamma = -1，反射相位 180°
%
% 注意：
% bitSeq 应填写编码序列的"最小重复周期"。
% 例如：
%   010101...       -> bitSeq = [0 1]
%   00110011...     -> bitSeq = [0 0 1 1]
%   00001111...     -> bitSeq = [0 0 0 0 1 1 1 1]
%
% 不需要额外工具箱。
% ==========================================================

clear;
clc;
close all;

%% =========================================================
% 1. 时间编码参数
% ==========================================================

% 理想 1-bit 编码的最小重复周期
bitSeq = [0 1];

% 一个编码周期中的时隙数
M = numel(bitSeq);

% 一个完整时间调制周期
T = 1e-3;                         % 1 ms

% 单个时隙宽度
tau = T / M;

% 时间调制基频
f0 = 1 / T;

% 两种理想反射状态
GammaState0 = 1 * exp(1j*0);      % 1∠0°   = +1
GammaState1 = 1 * exp(1j*pi);     % 1∠180° = -1

% 把编码位转换成复反射系数
Gamma_m = GammaState0 * ones(1,M);
Gamma_m(bitSeq == 1) = GammaState1;

%% =========================================================
% 2. 入射波参数
% ==========================================================

% 为了便于观察，使用20 kHz单频入射波
% 真实超表面载频可以是GHz，但图中不需要直接采样GHz载波
fc = 20e3;                        % 20 kHz

%% =========================================================
% 3. 数值采样参数
% ==========================================================

% 每个时隙的采样点数
samplesPerSlot = 2000;

% 一个完整调制周期的采样点数
samplesPerPeriod = M * samplesPerSlot;

% 采样频率
fs = samplesPerPeriod / T;

% 采样间隔
dt = 1 / fs;

% 一个周期内的时间
t_one_period = ...
    (0:samplesPerPeriod-1).' * dt;

% 一个周期内的离散采样序号
sampleIndex = ...
    (0:samplesPerPeriod-1).';

% 显示三个完整调制周期
periodsToShow = 3;

t_multi = ...
    (0:periodsToShow*samplesPerPeriod-1).' * dt;

%% =========================================================
% 4. 构造单位门函数 g(t)
%    对应式：
%
%       g(t) = 1, 0 <= t < tau
%            = 0, tau <= t < T
% ==========================================================

g_one_period = zeros(samplesPerPeriod,1);

g_one_period( ...
    t_one_period >= 0 & ...
    t_one_period < tau) = 1;

%% =========================================================
% 5. 构造一个周期的反射系数 Gamma(t)
%
%    Gamma(t) =
%    sum_{m=0}^{M-1} Gamma_m g(t-m*tau)
% ==========================================================

Gamma_one_period = zeros(samplesPerPeriod,1);

for m = 0:M-1

    indexStart = ...
        m*samplesPerSlot + 1;

    indexEnd = ...
        (m+1)*samplesPerSlot;

    Gamma_one_period(indexStart:indexEnd) = ...
        Gamma_m(m+1);

end

% 扩展成多个周期
Gamma_multi = repmat( ...
    Gamma_one_period, ...
    periodsToShow, ...
    1);

%% =========================================================
% 6. 构造入射波和反射波
%
%    Ei(t) = exp(j*2*pi*fc*t)
%
%    Er(t) = Ei(t) Gamma(t)
% ==========================================================

% 一个周期内的入射波
Ei_one_period = exp( ...
    1j * 2*pi * fc .* t_one_period);

% 一个周期内的反射波
Er_one_period = ...
    Ei_one_period .* Gamma_one_period;

% 多周期入射波
Ei_multi = exp( ...
    1j * 2*pi * fc .* t_multi);

% 多周期反射波
Er_multi = ...
    Ei_multi .* Gamma_multi;

%% =========================================================
% 7. MATLAB数值计算 PF
%
% PF是单位门函数g(t)的傅里叶级数系数：
%
%   PF_k =
%   (1/T) integral_0^T g(t)e^(-j2pikf0t)dt
%
% 离散计算：
%
%   PF_k =
%   (1/N) sum g[n]e^(-j2pikn/N)
% ==========================================================

Kmax = 9;

kList = -Kmax:Kmax;

PF = zeros(size(kList));

for ii = 1:numel(kList)

    k = kList(ii);

    basisFunction = exp( ...
        -1j * 2*pi * k .* ...
        sampleIndex / samplesPerPeriod);

    PF(ii) = ...
        sum(g_one_period .* basisFunction) ...
        / samplesPerPeriod;

end

%% =========================================================
% 8. MATLAB计算时间因子 TF
%
%   TF_k =
%   sum_{m=0}^{M-1}
%   Gamma_m e^(-j2pikm/M)
% ==========================================================

TF = zeros(size(kList));

for ii = 1:numel(kList)

    k = kList(ii);

    currentTF = 0;

    for m = 0:M-1

        currentTF = currentTF + ...
            Gamma_m(m+1) * ...
            exp(-1j*2*pi*k*m/M);

    end

    TF(ii) = currentTF;

end

%% =========================================================
% 9. 得到反射系数的傅里叶级数系数 a_k
%
%   a_k = PF_k * TF_k
%
% 所有数值均由MATLAB根据g(t)和Gamma_m计算，
% 没有写死2/pi、2/(3pi)等结果。
% ==========================================================

a_k = PF .* TF;

%% =========================================================
% 10. 从实际时域反射波计算离散频谱
%
% 入射波频率：
%
%   fc
%
% 反射波频率：
%
%   fc + k*f0
%
% 对时域波形进行复指数投影，计算每根谱线。
% ==========================================================

% 入射波在fc位置的谱线
incidentBasis = exp( ...
    -1j * 2*pi * fc .* t_one_period);

incidentLineCoefficient = ...
    sum(Ei_one_period .* incidentBasis) ...
    * dt / T;

% 反射波各阶频率
reflectedLineFrequencies = ...
    fc + kList*f0;

% MATLAB从Er(t)计算每根谱线
reflectedLineCoefficients = ...
    zeros(size(kList));

for ii = 1:numel(kList)

    currentFrequency = ...
        reflectedLineFrequencies(ii);

    spectrumBasis = exp( ...
        -1j * 2*pi * currentFrequency .* ...
        t_one_period);

    reflectedLineCoefficients(ii) = ...
        sum(Er_one_period .* spectrumBasis) ...
        * dt / T;

end

%% =========================================================
% 11. 输出MATLAB计算结果
% ==========================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('       理想1-bit时间编码超表面计算结果\n');
fprintf('====================================================\n');

fprintf('编码最小周期：           ');
fprintf('%d ',bitSeq);
fprintf('\n');

fprintf('时隙数 M：               %d\n',M);

fprintf('调制周期 T：             %.3f ms\n',T*1e3);

fprintf('时隙宽度 tau：           %.3f ms\n',tau*1e3);

fprintf('调制频率 f0：            %.3f Hz\n',f0);

fprintf('入射频率 fc：            %.3f kHz\n',fc/1e3);

fprintf('采样频率 fs：            %.3f MHz\n',fs/1e6);

fprintf('\n');

fprintf('入射波fc处的谱线幅度：   %.6f\n', ...
    abs(incidentLineCoefficient));

fprintf('\n');

fprintf(['  k       |PF|       |TF|       |a_k|' ...
    '      频率/kHz     |Er|\n']);

fprintf(['----------------------------------------' ...
    '-----------------------------\n']);

for ii = 1:numel(kList)

    fprintf('%3d    %8.5f   %8.5f   %8.5f   %10.3f   %8.5f\n', ...
        kList(ii), ...
        abs(PF(ii)), ...
        abs(TF(ii)), ...
        abs(a_k(ii)), ...
        reflectedLineFrequencies(ii)/1e3, ...
        abs(reflectedLineCoefficients(ii)));

end

fprintf('====================================================\n');

%% =========================================================
% 12. 绘图所需数据
% ==========================================================

% 一个周期内每个时隙对应的相位
GammaPhaseOnePeriod = ...
    mod(angle(Gamma_one_period)*180/pi,360);

% 多周期反射系数相位
GammaPhaseMulti = ...
    mod(angle(Gamma_multi)*180/pi,360);

% 区分0～0.5 ms与0.5～1 ms
% 对其他M值，也会自动按照第一个时隙边界区分
indexFirstPart = ...
    t_one_period >= 0 & ...
    t_one_period < tau;

indexSecondPart = ...
    t_one_period >= tau & ...
    t_one_period < T;

%% =========================================================
% 13. 建立总图
% ==========================================================

mainFigure = figure( ...
    'Name', ...
    '时间编码超表面完整理论流程', ...
    'NumberTitle', ...
    'off', ...
    'Color', ...
    'w', ...
    'Position', ...
    [40,40,1500,900]);

mainLayout = tiledlayout( ...
    mainFigure, ...
    3,3, ...
    'TileSpacing', ...
    'compact', ...
    'Padding', ...
    'compact');

title( ...
    mainLayout, ...
    '理想1-bit时间编码超表面：从反射系数到反射波频谱', ...
    'FontSize', ...
    16, ...
    'FontWeight', ...
    'bold');

%% =========================================================
% 图1：单位门函数g(t)
% ==========================================================

ax1 = nexttile(mainLayout);

plot( ...
    ax1, ...
    t_one_period*1e3, ...
    g_one_period, ...
    'LineWidth', ...
    1.6);

grid(ax1,'on');

xlim(ax1,[0,T*1e3]);

ylim(ax1,[-0.1,1.2]);

xlabel(ax1,'时间 / ms');

ylabel(ax1,'g(t)');

title(ax1, ...
    '周期单位脉冲函数 g(t)');



%% =========================================================
% 图2：一个周期内的Gamma(t)
% ==========================================================

ax2 = nexttile(mainLayout);

stairs( ...
    ax2, ...
    t_one_period*1e3, ...
    GammaPhaseOnePeriod, ...
    'LineWidth', ...
    1.6);

grid(ax2,'on');

xlim(ax2,[0,T*1e3]);

ylim(ax2,[-20,200]);

yticks(ax2,[0,180]);

xlabel(ax2,'时间 / ms');

ylabel(ax2,'反射相位 / °');

title(ax2, ...
    '一个周期内的 \Gamma(t)');


%% =========================================================
% 图3：多个周期的Gamma(t)
% ==========================================================

ax3 = nexttile(mainLayout);

stairs( ...
    ax3, ...
    t_multi*1e3, ...
    GammaPhaseMulti, ...
    'LineWidth', ...
    1.3);

grid(ax3,'on');

xlim(ax3,[0,periodsToShow*T*1e3]);

ylim(ax3,[-20,200]);

yticks(ax3,[0,180]);

xlabel(ax3,'时间 / ms');

ylabel(ax3,'反射相位 / °');

title(ax3, ...
    '\Gamma(t)');

%% =========================================================
% 图4：脉冲因子PF
% ==========================================================

ax4 = nexttile(mainLayout);

stem( ...
    ax4, ...
    kList, ...
    abs(PF), ...
    'filled', ...
    'LineWidth', ...
    1.1, ...
    'MarkerSize', ...
    4);

grid(ax4,'on');

xlim(ax4,[-Kmax-0.5,Kmax+0.5]);

xticks(ax4,kList);

xlabel(ax4,'谐波阶数 k');

ylabel(ax4,'|PF_k|');

title(ax4, ...
    '脉冲因子 PF');

%% =========================================================
% 图5：时间因子TF
% ==========================================================

ax5 = nexttile(mainLayout);

stem( ...
    ax5, ...
    kList, ...
    abs(TF), ...
    'filled', ...
    'LineWidth', ...
    1.1, ...
    'MarkerSize', ...
    4);

grid(ax5,'on');

xlim(ax5,[-Kmax-0.5,Kmax+0.5]);

xticks(ax5,kList);

xlabel(ax5,'谐波阶数 k');

ylabel(ax5,'|TF_k|');

title(ax5, ...
    '时间因子 TF');

%% =========================================================
% 图6：a_k = PF * TF
%
% 不再绘制第二组"数值验证"点。
% a_k本身由MATLAB计算出的PF和TF相乘得到。
% ==========================================================

ax6 = nexttile(mainLayout);

stem( ...
    ax6, ...
    kList, ...
    abs(a_k), ...
    'filled', ...
    'LineWidth', ...
    1.2, ...
    'MarkerSize', ...
    5);

grid(ax6,'on');

xlim(ax6,[-Kmax-0.5,Kmax+0.5]);

xticks(ax6,kList);

xlabel(ax6,'谐波阶数 k');

ylabel(ax6,'|a_k|');

title(ax6, ...
    '反射系数谐波系数 a_k=PF_kTF_k');

%% =========================================================
% 图7：完整1 ms入射波
%
% 前后两个时隙使用不同颜色，
% 只是为了标记Gamma(t)的切换时刻。
% 入射波本身没有被编码。
% ==========================================================

ax7 = nexttile(mainLayout);

plot( ...
    ax7, ...
    t_one_period(indexFirstPart)*1e3, ...
    real(Ei_one_period(indexFirstPart)), ...
    'LineWidth', ...
    1.2);

hold(ax7,'on');

plot( ...
    ax7, ...
    t_one_period(indexSecondPart)*1e3, ...
    real(Ei_one_period(indexSecondPart)), ...
    'LineWidth', ...
    1.2);



grid(ax7,'on');

xlim(ax7,[0,T*1e3]);

ylim(ax7,[-1.2,1.2]);

xlabel(ax7,'时间 / ms');

ylabel(ax7,'Re\{E_i(t)\}');

title(ax7, ...
    '入射波E_i(t)');



%% =========================================================
% 图8：完整1 ms反射波
%
% 前半段：
%   Gamma=+1，Er=Ei
%
% 后半段：
%   Gamma=-1，Er=-Ei
% ==========================================================

ax8 = nexttile(mainLayout);

plot( ...
    ax8, ...
    t_one_period(indexFirstPart)*1e3, ...
    real(Er_one_period(indexFirstPart)), ...
    'LineWidth', ...
    1.2);

hold(ax8,'on');

plot( ...
    ax8, ...
    t_one_period(indexSecondPart)*1e3, ...
    real(Er_one_period(indexSecondPart)), ...
    'LineWidth', ...
    1.2);



grid(ax8,'on');

xlim(ax8,[0,T*1e3]);

ylim(ax8,[-1.2,1.2]);

xlabel(ax8,'时间 / ms');

ylabel(ax8,'Re\{E_r(t)\}');

title(ax8, ...
    'E_r(t)=E_i(t)\Gamma(t)');



%% =========================================================
% 图9：MATLAB从时域波形计算出的离散频谱
%
% 不使用连续折线。
%
% 入射波谱线：
%   fc
%
% 反射波谱线：
%   fc+k*f0
%
% 每根反射谱线均通过Er(t)的数值积分计算。
% ==========================================================

ax9 = nexttile(mainLayout);

% 入射波在fc处的离散谱线
stem( ...
    ax9, ...
    fc/1e3, ...
    abs(incidentLineCoefficient), ...
    'filled', ...
    'LineWidth', ...
    1.6, ...
    'MarkerSize', ...
    7);

hold(ax9,'on');

% 反射波在fc+k*f0处的离散谱线
stem( ...
    ax9, ...
    reflectedLineFrequencies/1e3, ...
    abs(reflectedLineCoefficients), ...
    'filled', ...
    'LineWidth', ...
    1.2, ...
    'MarkerSize', ...
    5);

grid(ax9,'on');

xlim(ax9,[ ...
    (fc-(Kmax+1)*f0)/1e3, ...
    (fc+(Kmax+1)*f0)/1e3]);

xlabel(ax9,'频率 / kHz');

ylabel(ax9,'谱线幅度');

title(ax9, ...
    '入射波与反射波频谱');

legend( ...
    ax9, ...
    '入射波：f_c', ...
    '反射波：f_c+kf_0', ...
    'Location', ...
    'best');