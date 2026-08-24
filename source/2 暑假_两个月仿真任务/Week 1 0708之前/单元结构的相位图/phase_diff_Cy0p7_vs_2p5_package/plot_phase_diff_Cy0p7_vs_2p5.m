%% plot_phase_diff_Cy0p7_vs_2p5_中文注释版.m
% 功能：
%   绘制 Cy_val = 0.7 与 Cy_val = 2.5 两种状态下的展开相位曲线，
%   同时绘制二者的绝对相位差，并自动计算满足指定阈值的连续带宽。
%
% 使用方法：
%   1. 将本脚本与 phase_diff_Cy0p7_vs_2p5.csv 放在同一文件夹；
%   2. 在 MATLAB 命令窗口运行：
%          plot_phase_diff_Cy0p7_vs_2p5_中文注释版
%
% CSV 文件应至少包含以下列：
%   frequency_GHz                          频率，单位 GHz
%   phase_Cy0p7_deg_unwrapped              Cy_val=0.7 的展开相位，单位 deg
%   phase_Cy2p5_deg_unwrapped              Cy_val=2.5 的展开相位，单位 deg
%   signed_phase_diff_deg_2p5_minus_0p7    带符号相位差：2.5状态减0.7状态
%   abs_phase_diff_deg                     绝对相位差
%
% 说明：
%   本图共有三条曲线：
%   红色实线   —— Cy_val = 0.7 的展开相位
%   蓝色虚线   —— Cy_val = 2.5 的展开相位
%   紫色圆点线 —— 两状态的绝对相位差

clear;
clc;
close all;

%% ==================== 一、用户可调参数 ====================

% 横坐标显示范围，单位 GHz
xRange = [3, 9];

% 纵坐标显示范围，单位 deg
yRange = [-520, 230];

% 灰色阴影区域的纵坐标范围，用于突出“接近180°”的区域
% 这里只负责显示，不直接参与带宽计算
highlightBand = [150, 210];

% 带宽判据：当绝对相位差大于等于该值时，认为满足要求
% 对当前数据，设为179°时，计算出的带宽约为0.48 GHz
bandThresholdDeg = 179;

% 紫色相位差曲线上大约显示多少个圆点
% 原始数据点可能很多，因此只抽取部分点显示标记，避免图像过于拥挤
approxMarkerCount = 38;

%% ==================== 二、读取并检查数据 ====================

% 获取当前脚本所在文件夹
% 这样即使 MATLAB 当前工作目录不是脚本目录，也能正确找到CSV文件
scriptFolder = fileparts(mfilename('fullpath'));
if isempty(scriptFolder)
    scriptFolder = pwd;
end

% 拼接数据文件的完整路径
dataFile = fullfile(scriptFolder, 'phase_diff_Cy0p7_vs_2p5.csv');

% 若数据文件不存在，则停止运行并提示用户
if ~isfile(dataFile)
    error(['找不到数据文件：\n%s\n\n' ...
           '请将 phase_diff_Cy0p7_vs_2p5.csv 与本脚本放在同一文件夹中。'], ...
           dataFile);
end

% 读取CSV文件为table类型
T = readtable(dataFile);

% 定义程序运行所必需的数据列
requiredVariables = { ...
    'frequency_GHz', ...
    'phase_Cy0p7_deg_unwrapped', ...
    'phase_Cy2p5_deg_unwrapped', ...
    'signed_phase_diff_deg_2p5_minus_0p7', ...
    'abs_phase_diff_deg'};

% 检查CSV中是否缺少必要列
missingVariables = setdiff(requiredVariables, T.Properties.VariableNames);
if ~isempty(missingVariables)
    error('CSV文件缺少以下必要列：%s', strjoin(missingVariables, ', '));
end

% 将各列提取为列向量
frequency = T.frequency_GHz(:);
phase07 = T.phase_Cy0p7_deg_unwrapped(:);
phase25 = T.phase_Cy2p5_deg_unwrapped(:);
signedPhaseDifference = T.signed_phase_diff_deg_2p5_minus_0p7(:);
phaseDifference = T.abs_phase_diff_deg(:);

% 删除包含 NaN 或 Inf 的无效数据行
valid = isfinite(frequency) & isfinite(phase07) & ...
        isfinite(phase25) & isfinite(phaseDifference);

frequency = frequency(valid);
phase07 = phase07(valid);
phase25 = phase25(valid);
signedPhaseDifference = signedPhaseDifference(valid);
phaseDifference = phaseDifference(valid);

% 按频率从小到大排序，保证后续插值和绘图正确
[frequency, order] = sort(frequency);
phase07 = phase07(order);
phase25 = phase25(order);
signedPhaseDifference = signedPhaseDifference(order);
phaseDifference = phaseDifference(order);

%% ==================== 三、计算满足阈值的连续带宽 ====================

% 为了更准确地确定阈值交点，先在原始数据之间进行高密度PCHIP插值
% PCHIP相比普通三次样条更不容易出现过冲，适合保持原曲线形状
fineFrequency = linspace(frequency(1), frequency(end), 60000).';

fineDifference = interp1( ...
    frequency, ...          % 原始频率
    phaseDifference, ...    % 原始绝对相位差
    fineFrequency, ...      % 高密度频率网格
    'pchip');               % 分段三次Hermite插值

% 只在设定的横坐标显示范围内寻找有效频带
inDisplayRange = fineFrequency >= xRange(1) & ...
                 fineFrequency <= xRange(2);

% 相位差达到阈值，并且位于显示范围内的点记为有效
validBand = fineDifference >= bandThresholdDeg & inDisplayRange;

% 在布尔数组前后补false，再求差分，以寻找连续有效区间的起止位置
transitions = diff([false; validBand; false]);

% 从false变为true的位置，是某个有效频带的起点
startIndices = find(transitions == 1);

% 从true变为false的位置前一个点，是某个有效频带的终点
endIndices = find(transitions == -1) - 1;

% 初始化带宽结果
bandStart = NaN;
bandEnd = NaN;
bandwidthGHz = NaN;

% 若存在一个或多个有效区间，则选择其中最宽的连续频带
if ~isempty(startIndices)
    candidateWidths = fineFrequency(endIndices) - ...
                      fineFrequency(startIndices);

    [~, widestIndex] = max(candidateWidths);

    bandStart = fineFrequency(startIndices(widestIndex));
    bandEnd = fineFrequency(endIndices(widestIndex));
    bandwidthGHz = bandEnd - bandStart;
end

%% ==================== 四、创建图窗和坐标轴 ====================

% 创建白色背景图窗，并指定合适的窗口尺寸
fig = figure( ...
    'Color', 'w', ...
    'Name', 'Cy=0.7 与 Cy=2.5 相位差', ...
    'Units', 'pixels', ...
    'Position', [120, 80, 1180, 850]);

% 创建坐标轴，并适当留出标题、标签和图例空间
ax = axes(fig, ...
    'Position', [0.10, 0.11, 0.84, 0.82]);

hold(ax, 'on');
box(ax, 'on');
grid(ax, 'on');

%% ==================== 五、绘制灰色目标区域 ====================

% 先绘制灰色阴影区域，使其位于所有曲线下方
% HandleVisibility='off' 表示不在图例中显示该区域
patch(ax, ...
    [xRange(1), xRange(2), xRange(2), xRange(1)], ...
    [highlightBand(1), highlightBand(1), ...
     highlightBand(2), highlightBand(2)], ...
    [0.85, 0.85, 0.85], ...
    'FaceAlpha', 0.62, ...
    'EdgeColor', 'none', ...
    'HandleVisibility', 'off');

%% ==================== 六、绘制三条主要曲线 ====================

% 1. Cy_val = 0.7 的展开相位：红色实线
h07 = plot(ax, frequency, phase07, ...
    '-', ...
    'Color', [0.95, 0.12, 0.06], ...
    'LineWidth', 2.4, ...
    'DisplayName', 'Phase: Cy_val = 0.7');

% 2. Cy_val = 2.5 的展开相位：蓝色虚线
h25 = plot(ax, frequency, phase25, ...
    '-', ...
    'Color', [0.03, 0.30, 0.78], ...
    'LineWidth', 2.4, ...
    'DisplayName', 'Phase: Cy_val = 2.5');

% 根据总数据点数，计算紫色曲线圆点标记的间隔
markerStep = max(1, round(numel(frequency) / approxMarkerCount));
markerIndices = 1:markerStep:numel(frequency);

% 确保最后一个数据点也显示圆点
if markerIndices(end) ~= numel(frequency)
    markerIndices(end + 1) = numel(frequency);
end

% 3. 绝对相位差：紫色实线加空心圆点
hDiff = plot(ax, frequency, phaseDifference, ...
    '-o', ...
    'Color', [0.55, 0.08, 0.62], ...
    'LineWidth', 2.7, ...
    'MarkerIndices', markerIndices, ...
    'MarkerSize', 7.0, ...
    'MarkerEdgeColor', [0.55, 0.08, 0.62], ...
    'MarkerFaceColor', 'w', ...
    'DisplayName', '|Phase diff: 2.5 - 0.7|');

%% ==================== 七、添加文字与带宽标注 ====================

% 在灰色区域左侧添加说明文字
% 将文字放在远离图例的位置，避免重叠
% text(ax, xRange(1) + 0.18, highlightBand(2) - 12, ...
%     {'Phase difference', 'around 180°'}, ...
%     'HorizontalAlignment', 'left', ...
%     'VerticalAlignment', 'top', ...
%     'FontSize', 13, ...
%     'FontWeight', 'normal', ...
%     'Color', [0.08, 0.08, 0.08], ...
%     'Clipping', 'on');

% 仅在成功计算出有效带宽时绘制一个带宽箭头
if isfinite(bandwidthGHz)

    % 箭头纵坐标，放在灰色区域下方，避免遮挡曲线峰值
    arrowY = 138;

    % 控制箭头两端与水平线之间的间距
    arrowHeadLength = min(0.055, 0.16 * bandwidthGHz);

    % 绘制箭头中间的水平线
    plot(ax, ...
        [bandStart + arrowHeadLength, bandEnd - arrowHeadLength], ...
        [arrowY, arrowY], ...
        'k-', ...
        'LineWidth', 1.8, ...
        'HandleVisibility', 'off');

    % 左箭头
    plot(ax, bandStart, arrowY, ...
        '<', ...
        'Color', 'k', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 8, ...
        'HandleVisibility', 'off');

    % 右箭头
    plot(ax, bandEnd, arrowY, ...
        '>', ...
        'Color', 'k', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 8, ...
        'HandleVisibility', 'off');

    % 在箭头下方显示带宽数值
    text(ax, mean([bandStart, bandEnd]), arrowY - 12, ...
        sprintf('%.3f GHz', bandwidthGHz), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 12, ...
        'FontWeight', 'normal', ...
        'Color', 'k', ...
        'BackgroundColor', 'w', ...
        'Margin', 1.5, ...
        'Clipping', 'on');
end

%% ==================== 八、设置坐标轴、标题与图例 ====================

% 设置显示范围
xlim(ax, xRange);
ylim(ax, yRange);

% 设置主刻度
xticks(ax, xRange(1):1:xRange(2));
yticks(ax, -500:100:200);

% 横坐标标签
xlabel(ax, 'Frequency (GHz)', ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

% 纵坐标标签
ylabel(ax, 'Phase (deg)', ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

% 图标题
% Interpreter='none' 可避免下划线被MATLAB解释为下标
 title(ax, '相位曲线', ...
    'Interpreter', 'none', ...
    'FontSize', 18, ...
    'FontWeight', 'bold');

% 只将三条主要曲线加入图例，固定放在右上角
lgd = legend(ax, [h07, h25, hDiff], ...
    'Location', 'northeast', ...
    'FontSize', 12, ...
    'Box', 'on', ...
    'Interpreter', 'none');

% 设置图例背景和边框
lgd.Color = 'w';
lgd.EdgeColor = [0.15, 0.15, 0.15];

% 坐标轴整体美化
ax.FontSize = 13;
ax.FontName = 'Arial';
ax.LineWidth = 1.25;
ax.GridAlpha = 0.20;
ax.GridLineStyle = '--';
ax.Layer = 'top';

%% ==================== 九、配置鼠标数据提示 ====================

% DataTipTemplate 可以自定义鼠标点击曲线后显示的字段
% 使用try是为了兼容不支持该功能的旧版MATLAB
try
    % 红色曲线的数据提示
    h07.DataTipTemplate.DataTipRows(1).Label = 'Frequency / GHz';
    h07.DataTipTemplate.DataTipRows(2).Label = 'Phase Cy=0.7 / deg';

    % 蓝色曲线的数据提示
    h25.DataTipTemplate.DataTipRows(1).Label = 'Frequency / GHz';
    h25.DataTipTemplate.DataTipRows(2).Label = 'Phase Cy=2.5 / deg';

    % 紫色相位差曲线的数据提示
    hDiff.DataTipTemplate.DataTipRows(1).Label = 'Frequency / GHz';
    hDiff.DataTipTemplate.DataTipRows(2).Label = '|Phase difference| / deg';

    % 在紫色曲线的数据提示中增加带符号相位差
    hDiff.DataTipTemplate.DataTipRows(end + 1) = ...
        dataTipTextRow('Signed difference / deg', signedPhaseDifference);

    % 在紫色曲线的数据提示中增加相对于180°的误差
    hDiff.DataTipTemplate.DataTipRows(end + 1) = ...
        dataTipTextRow('Error to 180° / deg', abs(phaseDifference - 180));
catch
    % 旧版MATLAB若不支持DataTipTemplate，则跳过自定义设置
end

% 开启数据光标模式
cursorMode = datacursormode(fig);
cursorMode.Enable = 'on';

% 尝试让数据提示自动吸附到最近的原始数据点
try
    cursorMode.SnapToDataVertex = 'on';
catch
    % 某些MATLAB版本不支持该属性时，忽略即可
end

%% ==================== 十、在命令窗口输出计算结果 ====================

% 找到绝对相位差的最大值及其对应频率
[peakDifference, peakIndex] = max(phaseDifference);
peakFrequency = frequency(peakIndex);

fprintf('\nCy_val = 0.7 与 Cy_val = 2.5 的相位差分析\n');
fprintf('最大绝对相位差：%.6f deg，对应频率：%.6f GHz\n', ...
    peakDifference, peakFrequency);

% 输出带宽计算结果
if isfinite(bandwidthGHz)
    fprintf('满足 |相位差| >= %.3f deg 的最宽连续频带：\n', ...
        bandThresholdDeg);
    fprintf('  起始频率：%.6f GHz\n', bandStart);
    fprintf('  终止频率：%.6f GHz\n', bandEnd);
    fprintf('  带宽：    %.6f GHz\n', bandwidthGHz);
else
    fprintf('当前数据中不存在满足 |相位差| >= %.3f deg 的连续频带。\n', ...
        bandThresholdDeg);
end

%% ==================== 十一、可选：导出高清图片 ====================

% 取消下一行前面的百分号，即可导出300 dpi高清PNG图片
% exportgraphics(fig, ...
%     'phase_diff_Cy0p7_vs_2p5_clean.png', ...
%     'Resolution', 300);
