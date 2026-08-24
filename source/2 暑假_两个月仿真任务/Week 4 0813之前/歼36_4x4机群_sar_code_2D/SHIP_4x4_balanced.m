clearvars; clc; close all;

%% 1. 运行配置
% 4×4 战斗机群平衡编码实验：四角为真实歼-36，距离向和方位向
% 分别采用50%/50%的0/pi编码。零阶和偶数阶被抑制。
resolution_mode = 'uav';
display_dynamic_range_db = 30;
display_main_orders_dynamic_range_db = 8;
display_half_width_m = 16;
display_full_half_width_m = 24;

% 4×4 阵列相邻中心间距。中心坐标为 [-12,-4,+4,+12] m。
grid_spacing_m = 8.0;
grid_axis_m = (-1.5:1:1.5) * grid_spacing_m;
outer_coordinate_m = max(abs(grid_axis_m));

% 平衡1-bit编码：0/pi状态各占50%。反射效率设为1，只研究编码分配。
zero_state_fraction = 0.50;
reflection_power_efficiency = 1.00;
reflection_amplitude = sqrt(reflection_power_efficiency);

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

output_root = fullfile(script_dir, 'results_4x4_balanced');
if ~exist(output_root, 'dir')
    mkdir(output_root);
end
run_timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
run_dir = fullfile(output_root, ...
    sprintf('%s_%s', run_timestamp, resolution_mode));
mkdir(run_dir);

%% 2. 雷达、场景和分辨率参数
fprintf('正在生成 4×4 歼-36机群的平衡1-bit SAR回波...\n');

c = 3e8;
fc = 10e9;
lambda = c / fc;
Tp = 1e-6;

beta1 = 60*pi/180;
H0 = 500;
v_x = 80;
Y0 = H0 * tan(beta1);
X0 = 0;
R0 = hypot(H0, Y0);

switch lower(resolution_mode)
    case 'preview'
        desired_ground_range_resolution = 0.30;
        desired_az_resolution = 0.30;
        max_scatter_points = 1000;
    case 'uav'
        desired_ground_range_resolution = 0.15;
        desired_az_resolution = 0.15;
        max_scatter_points = inf;
    case 'high'
        desired_ground_range_resolution = 0.10;
        desired_az_resolution = 0.10;
        max_scatter_points = 300;
    otherwise
        error('未知 resolution_mode：%s', resolution_mode);
end

desired_slant_range_resolution = ...
    desired_ground_range_resolution * sin(beta1);
Br = c / (2 * desired_slant_range_resolution);
Kr = Br / Tp;
Fs = 1.20 * Br;

synthetic_aperture_length = lambda * R0 / (2 * desired_az_resolution);
aperture_time = synthetic_aperture_length / v_x;
Ka = -2 * v_x^2 / (lambda * R0);
Ba = abs(Ka) * aperture_time;
PRF = ceil(1.20 * Ba);

Na = ceil(aperture_time * PRF);
if mod(Na, 2) ~= 0
    Na = Na + 1;
end
tm = ((-Na/2):(Na/2-1)) / PRF;
x_radar = tm * v_x;

% 阵列中心最远到 ±12 m，连同飞机尺寸和距离徙动预留边界。
range_margin_m = max(30, ...
    synthetic_aperture_length^2/(8*R0) + outer_coordinate_m + 8);
fast_time_span = Tp + 4*range_margin_m/c;
Nr = 2^nextpow2(ceil(fast_time_span * Fs));
t = 2*R0/c + ((-Nr/2):(Nr/2-1)) / Fs;
dt = 1/Fs;

actual_slant_range_resolution = c/(2*Br);
actual_ground_range_resolution = actual_slant_range_resolution/sin(beta1);
actual_aperture_length = (max(tm)-min(tm))*v_x;
actual_az_resolution = lambda*R0/(2*actual_aperture_length);

fprintf('分辨率模式：%s\n', resolution_mode);
fprintf('地距/方位分辨率约：%.3f / %.3f m\n', ...
    actual_ground_range_resolution, actual_az_resolution);
fprintf('4×4 中心坐标：[%s] m，间距 %.1f m\n', ...
    strtrim(sprintf('%+.1f ', grid_axis_m)), grid_spacing_m);
fprintf('Na = %d，Nr = %d，每个复数回波矩阵约 %.1f MB\n', ...
    Na, Nr, 16*Na*Nr/1024^2);

%% 3. 加载中心歼-36纯二维散射点
data_file = fullfile(script_dir, 'airplane_scatter_points.mat');
if ~isfile(data_file)
    error('找不到散射点文件：%s。请先运行 ship_trans.m。', data_file);
end

loaded = load(data_file, 'my_data');
target_all = loaded.my_data;
if isfinite(max_scatter_points) && size(target_all,1) > max_scatter_points
    keep_index = round(linspace(1, size(target_all,1), max_scatter_points));
    target = target_all(keep_index, :);
else
    target = target_all;
end

if size(target,2) ~= 2
    error('纯二维散射点数据必须为 [方位, 地距] 两列。');
end

target_azimuth = target(:,1) + X0;
target_ground_range = target(:,2) + Y0;
Ntar = size(target,1);

fprintf('中心歼-36散射点数：%d/%d\n', Ntar, size(target_all,1));
fprintf('单机方位/地距尺寸约：%.3f / %.3f m\n', ...
    range(target(:,1)), range(target(:,2)));

%% 4. 生成位于阵列中心的单机模板回波
% 只对散射点进行一次完整传播计算。四角飞机的位置利用小场景平移
% 算子生成，可避免将同一架飞机重复计算四遍。
sr_center = complex(zeros(Na, Nr));
fprintf('开始累加中心歼-36模板回波...\n');

for i = 1:Ntar
    for k = 1:Na
        delta_azimuth = x_radar(k) - target_azimuth(i);
        r_inst = sqrt(delta_azimuth^2 + ...
            target_ground_range(i)^2 + H0^2);
        scatter_amplitude = (R0/r_inst)^2;

        tr_delay = 2*r_inst/c;
        tau = t - tr_delay;
        pulse_mask = abs(tau) <= Tp/2;

        sr_center(k,:) = sr_center(k,:) + ...
            scatter_amplitude .* pulse_mask .* ...
            exp(1j*pi*Kr*tau.^2) .* ...
            exp(-1j*4*pi*r_inst/lambda);
    end

    if mod(i,50) == 0 || i == Ntar
        fprintf('已处理散射点：%d/%d\n', i, Ntar);
    end
end

%% 5. 定义 4×4 期望位置及谐波阶次
[range_grid, azimuth_grid] = meshgrid(grid_axis_m, grid_axis_m);
all_range = range_grid(:);
all_azimuth = azimuth_grid(:);

is_real = abs(all_range) == outer_coordinate_m & ...
    abs(all_azimuth) == outer_coordinate_m;
is_mixed = abs(all_range) < outer_coordinate_m & ...
    abs(all_azimuth) < outer_coordinate_m;
is_edge_first = ~is_real & ~is_mixed;

target_type = repmat({'一阶谐波'}, numel(all_range), 1);
target_type(is_real) = {'真实飞机（零阶）'};
target_type(is_mixed) = {'混合阶 (1,1)'};

source_range = sign(all_range) * outer_coordinate_m;
source_azimuth = sign(all_azimuth) * outer_coordinate_m;

expected_positions = table((1:numel(all_range)).', target_type, ...
    all_range, all_azimuth, source_range, source_azimuth, ...
    'VariableNames', {'target_id','target_type','range_m','azimuth_m', ...
    'source_range_m','source_azimuth_m'});

fprintf('期望阵列：真实飞机 %d，边缘一阶 %d，内侧混合阶 %d。\n', ...
    nnz(is_real), nnz(is_edge_first), nnz(is_mixed));

%% 6. 四角真实机群回波与二维 1-bit 超表面回波
real_positions = [ ...
    -outer_coordinate_m, +outer_coordinate_m; ...
    +outer_coordinate_m, +outer_coordinate_m; ...
    -outer_coordinate_m, -outer_coordinate_m; ...
    +outer_coordinate_m, -outer_coordinate_m];

sr_real_corners = complex(zeros(Na, Nr));
sr_deception_1bit = complex(zeros(Na, Nr));

fast_time_relative = t - 2*R0/c;
first_code_statistics = struct();

for source_index = 1:size(real_positions,1)
    source_range_m = real_positions(source_index,1);
    source_azimuth_m = real_positions(source_index,2);

    % 将中心模板平移到真实飞机所在的角点。
    sr_source = shiftEcho(sr_center, source_range_m, source_azimuth_m, ...
        t, tm, c, R0, Kr, Ka, beta1, v_x);
    sr_real_corners = sr_real_corners + sr_source;

    % 编码基频对应向阵列内部移动一个网格间距。
    inward_range_m = -sign(source_range_m) * grid_spacing_m;
    inward_azimuth_m = -sign(source_azimuth_m) * grid_spacing_m;

    range_mod_frequency_hz = ...
        -2 * Kr * (inward_range_m*sin(beta1)) / c;
    azimuth_mod_frequency_hz = ...
        -Ka * inward_azimuth_m / v_x;

    range_phase = 2*pi * range_mod_frequency_hz * fast_time_relative;
    azimuth_phase = 2*pi * azimuth_mod_frequency_hz * tm(:);

    range_code = dutyOneBitCode(range_phase, zero_state_fraction);
    azimuth_code = dutyOneBitCode(azimuth_phase, zero_state_fraction);

    % 两个独立 1-bit 编码相乘仍只有 +1/-1 两种反射状态。
    % 其二维谱同时包含 (1,0)、(0,1) 和混合阶 (1,1)。
    modulation_2d_1bit = azimuth_code .* range_code;
    sr_deception_1bit = sr_deception_1bit + ...
        reflection_amplitude * modulation_2d_1bit .* sr_source;

    if source_index == 1
        first_code_statistics.range_zero_fraction = ...
            mean(range_code(:) > 0);
        first_code_statistics.azimuth_zero_fraction = ...
            mean(azimuth_code(:) > 0);
        first_code_statistics.combined_positive_fraction = ...
            mean(modulation_2d_1bit(:) > 0);
    end

    fprintf(['角点 %d：(地距 %+.1f, 方位 %+.1f) m，' ...
        '向内基频 %.3f MHz / %.3f Hz\n'], ...
        source_index, source_range_m, source_azimuth_m, ...
        range_mod_frequency_hz/1e6, azimuth_mod_frequency_hz);
end

% 单维占空比方波的理论傅里叶系数幅度。
c0 = 2*zero_state_fraction - 1;
c1 = 2*sin(pi*zero_state_fraction)/pi;
c2 = sin(2*pi*zero_state_fraction)/pi;

fprintf('\n========== 1-bit 编码检查 ==========\n');
fprintf('距离编码 0/1 比例：%.2f%% / %.2f%%\n', ...
    100*first_code_statistics.range_zero_fraction, ...
    100*(1-first_code_statistics.range_zero_fraction));
fprintf('方位编码 0/1 比例：%.2f%% / %.2f%%\n', ...
    100*first_code_statistics.azimuth_zero_fraction, ...
    100*(1-first_code_statistics.azimuth_zero_fraction));
fprintf('二维乘积编码 +1/-1 比例：%.2f%% / %.2f%%\n', ...
    100*first_code_statistics.combined_positive_fraction, ...
    100*(1-first_code_statistics.combined_positive_fraction));
fprintf('理论系数：|C0|=%.3f，|C1|=%.3f，|C2|=%.3f\n', ...
    abs(c0), abs(c1), abs(c2));
fprintf(['二维主要阶次幅度：零阶 |C0^2|=%.3f，边缘一阶 ' ...
    '|C0*C1|=%.3f，内侧混合阶 |C1^2|=%.3f\n'], ...
    abs(c0^2), abs(c0*c1), abs(c1^2));

%% 7. RD 成像
fprintf('\n对四角真实飞机执行 RD 成像...\n');
[img_real_corners, R_axis_slant_relative, Az_axis] = rdFocus( ...
    sr_real_corners, t, tm, dt, c, R0, Tp, Kr, lambda, v_x, Ka, PRF);

fprintf('对二维 1-bit 欺骗回波执行 RD 成像...\n');
[img_deception_1bit, ~, ~] = rdFocus( ...
    sr_deception_1bit, t, tm, dt, c, R0, Tp, Kr, lambda, v_x, Ka, PRF);

Range_axis_ground = R_axis_slant_relative / sin(beta1);
comparison_reference = max([max(abs(img_real_corners(:))), ...
    max(abs(img_deception_1bit(:)))]) + eps;
deception_reference = max(abs(img_deception_1bit(:))) + eps;

%% 8. 画图
figure_layout = createResultFigure('Figure 1 - 4×4期望阵列布局');
hold on;
scatter(all_range(is_real), all_azimuth(is_real), 150, ...
    [0.80 0.15 0.10], 's', 'filled', 'DisplayName', '真实飞机（零阶）');
scatter(all_range(is_edge_first), all_azimuth(is_edge_first), 110, ...
    [0.10 0.35 0.80], 'o', 'filled', 'DisplayName', '一阶谐波');
scatter(all_range(is_mixed), all_azimuth(is_mixed), 120, ...
    [0.05 0.60 0.35], 'd', 'filled', 'DisplayName', '混合阶 (1,1)');
for index = 1:numel(all_range)
    text(all_range(index)+0.35, all_azimuth(index)+0.35, ...
        sprintf('%d', index), 'FontSize', 8);
end
hold off;
axis equal;
grid on;
xlim([min(grid_axis_m)-2, max(grid_axis_m)+2]);
ylim([min(grid_axis_m)-2, max(grid_axis_m)+2]);
xticks(grid_axis_m);
yticks(grid_axis_m);
xlabel('相对地距向 (m)');
ylabel('方位向 (m)');
title('4×4期望布局：4个真实目标 + 8个一阶 + 4个混合阶');
legend('Location', 'southoutside', 'Orientation', 'horizontal');

figure_real = createResultFigure('Figure 2 - 四角真实歼-36');
plotSarDb(img_real_corners, Range_axis_ground, Az_axis, ...
    display_dynamic_range_db, comparison_reference, display_half_width_m);
title(sprintf('四角真实歼-36（间距 %.1f m）', grid_spacing_m));

figure_deception = createResultFigure( ...
    'Figure 3 - 平衡二维1-bit编码（30 dB动态范围）');
plotSarDb(img_deception_1bit, Range_axis_ground, Az_axis, ...
    display_dynamic_range_db, comparison_reference, display_half_width_m);
title(sprintf(['平衡二维1-bit编码：0状态 %.0f%% / 1状态 %.0f%%，' ...
    '零阶与偶数阶抑制'], ...
    100*zero_state_fraction, 100*(1-zero_state_fraction)));

figure_deception_main = createResultFigure( ...
    'Figure 4 - 平衡编码主导±1阶（中央2×2）');
plotSarDb(img_deception_1bit, Range_axis_ground, Az_axis, ...
    display_main_orders_dynamic_range_db, deception_reference, ...
    display_half_width_m);
title(sprintf('平衡二维1-bit编码：%.0f dB显示范围，突出中央2×2主导±1阶', ...
    display_main_orders_dynamic_range_db));

figure_deception_full = createResultFigure( ...
    'Figure 5 - 平衡二维1-bit编码完整视场');
plotSarDb(img_deception_1bit, Range_axis_ground, Az_axis, ...
    display_dynamic_range_db, comparison_reference, ...
    display_full_half_width_m);
title('平衡二维1-bit编码完整视场：仅奇数阶晶格');

%% 9. 平衡 1-bit 编码各次谐波幅度
% 这里画的是单个一维周期编码的理论傅里叶系数。距离向和方位向
% 使用相同的30/70编码，因此系数幅度相同；横坐标的空间偏移均为
% 谐波阶次乘以一个网格间距。
harmonic_orders = (-5:5).';
harmonic_coefficients = arrayfun( ...
    @(order) oneBitFourierCoefficient(order, zero_state_fraction), ...
    harmonic_orders);
harmonic_amplitude = abs(harmonic_coefficients);
% 以未加超表面的单架飞机幅度 A=1（0 dB）为统一参考；此处只画
% 理想编码系数，不额外乘 reflection_amplitude。
harmonic_amplitude_db = 20*log10(harmonic_amplitude + eps);
harmonic_offset_m = harmonic_orders * grid_spacing_m;

harmonic_table = table(harmonic_orders, harmonic_offset_m, ...
    real(harmonic_coefficients), imag(harmonic_coefficients), ...
    harmonic_amplitude, harmonic_amplitude_db, ...
    'VariableNames', {'harmonic_order','spatial_offset_m', ...
    'coefficient_real','coefficient_imag','amplitude','amplitude_db'});

figure_harmonics = createResultFigure( ...
    'Figure 6 - 平衡编码各次谐波幅度');
tiledlayout(2,1, 'TileSpacing','compact', 'Padding','compact');
sgtitle('各次谐波幅度');

nexttile;
stem(harmonic_offset_m, harmonic_amplitude_db, ...
    'filled', 'LineWidth', 1.4, 'MarkerSize', 5);
hold on;
yline(0, '--k', '未加超表面：A=1（0 dB）', ...
    'LabelHorizontalAlignment','left');
hold off;
grid on;
xlim([min(harmonic_offset_m)-grid_spacing_m/2, ...
    max(harmonic_offset_m)+grid_spacing_m/2]);
ylim([-25, 2]);
xticks(harmonic_offset_m);
xlabel('距离向偏移 / m');
ylabel('相对未调制单机幅度 / dB');
title(sprintf('距离向（理论间距 %.1f m）', grid_spacing_m));
for index = 1:numel(harmonic_orders)
    text(harmonic_offset_m(index), harmonic_amplitude_db(index)+1.0, ...
        sprintf('n=%+d', harmonic_orders(index)), ...
        'HorizontalAlignment','center', 'FontSize',8);
end

nexttile;
stem(harmonic_offset_m, harmonic_amplitude_db, ...
    'filled', 'LineWidth', 1.4, 'MarkerSize', 5);
hold on;
yline(0, '--k', '未加超表面：A=1（0 dB）', ...
    'LabelHorizontalAlignment','left');
hold off;
grid on;
xlim([min(harmonic_offset_m)-grid_spacing_m/2, ...
    max(harmonic_offset_m)+grid_spacing_m/2]);
ylim([-25, 2]);
xticks(harmonic_offset_m);
xlabel('方位向偏移 / m');
ylabel('相对未调制单机幅度 / dB');
title(sprintf('方位向（理论间距 %.1f m）', grid_spacing_m));
for index = 1:numel(harmonic_orders)
    text(harmonic_offset_m(index), harmonic_amplitude_db(index)+1.0, ...
        sprintf('n=%+d', harmonic_orders(index)), ...
        'HorizontalAlignment','center', 'FontSize',8);
end

%% 10. 自动保存
layout_png = fullfile(run_dir, 'array_layout_4x4.png');
layout_fig = fullfile(run_dir, 'array_layout_4x4.fig');
real_png = fullfile(run_dir, 'sar_four_real_corners.png');
real_fig = fullfile(run_dir, 'sar_four_real_corners.fig');
deception_png = fullfile(run_dir, 'sar_4x4_deception_1bit.png');
deception_fig = fullfile(run_dir, 'sar_4x4_deception_1bit.fig');
deception_main_png = fullfile(run_dir, ...
    'sar_4x4_balanced_main_orders_8db.png');
deception_main_fig = fullfile(run_dir, ...
    'sar_4x4_balanced_main_orders_8db.fig');
deception_full_png = fullfile(run_dir, ...
    'sar_4x4_deception_1bit_full_field.png');
deception_full_fig = fullfile(run_dir, ...
    'sar_4x4_deception_1bit_full_field.fig');
harmonics_png = fullfile(run_dir, 'one_bit_harmonic_amplitudes.png');
harmonics_fig = fullfile(run_dir, 'one_bit_harmonic_amplitudes.fig');
harmonics_csv = fullfile(run_dir, 'one_bit_harmonic_amplitudes.csv');
mat_file = fullfile(run_dir, 'sar_results_4x4.mat');
position_csv = fullfile(run_dir, 'expected_positions_4x4.csv');

if exist('exportgraphics', 'file') == 2
    exportgraphics(figure_layout, layout_png, 'Resolution', 200);
    exportgraphics(figure_real, real_png, 'Resolution', 200);
    exportgraphics(figure_deception, deception_png, 'Resolution', 200);
    exportgraphics(figure_deception_main, deception_main_png, 'Resolution', 200);
    exportgraphics(figure_deception_full, deception_full_png, 'Resolution', 200);
    exportgraphics(figure_harmonics, harmonics_png, 'Resolution', 200);
else
    saveas(figure_layout, layout_png);
    saveas(figure_real, real_png);
    saveas(figure_deception, deception_png);
    saveas(figure_deception_main, deception_main_png);
    saveas(figure_deception_full, deception_full_png);
    saveas(figure_harmonics, harmonics_png);
end
savefig(figure_layout, layout_fig);
savefig(figure_real, real_fig);
savefig(figure_deception, deception_fig);
savefig(figure_deception_main, deception_main_fig);
savefig(figure_deception_full, deception_full_fig);
savefig(figure_harmonics, harmonics_fig);
writetable(expected_positions, position_csv);
writetable(harmonic_table, harmonics_csv);

save(mat_file, 'img_real_corners', 'img_deception_1bit', ...
    'R_axis_slant_relative', 'Range_axis_ground', 'Az_axis', ...
    'expected_positions', 'real_positions', 'grid_axis_m', ...
    'grid_spacing_m', 'zero_state_fraction', ...
    'reflection_power_efficiency', 'first_code_statistics', ...
    'c0', 'c1', 'c2', 'harmonic_orders', 'harmonic_offset_m', ...
    'harmonic_coefficients', 'harmonic_amplitude', ...
    'harmonic_amplitude_db', 'resolution_mode', ...
    'actual_ground_range_resolution', 'actual_az_resolution', '-v7.3');

fprintf('\n结果已保存至：\n%s\n', run_dir);

%% ====================== 局部函数 ======================
function coefficient = oneBitFourierCoefficient(order, zero_fraction)
% 周期为2pi、前zero_fraction部分为+1、其余部分为-1的方波系数。
    if order == 0
        coefficient = 2*zero_fraction - 1;
    else
        coefficient = 2*sin(pi*order*zero_fraction)/(pi*order) * ...
            exp(-1j*pi*order*zero_fraction);
    end
end

function code = dutyOneBitCode(phase, zero_fraction)
% 相位0映射为 +1，相位pi映射为 -1。
% 按折叠相位由小到大选择固定数量的 +1，保证有限离散样本中的
% 0/1 总数严格接近 zero_fraction，而不是受每周期采样点数限制。
    phase_in_period = mod(phase, 2*pi);
    number_samples = numel(phase_in_period);
    number_zero_state = round(zero_fraction * number_samples);

    % 极小的确定性扰动只用于均匀打破重复相位的排序并列，不改变
    % 主体相位顺序；这样不会把所有边界样本集中在序列的一端。
    sample_index = (1:number_samples).';
    tie_break = 1e-10 * mod(sample_index*0.618033988749895, 1);
    sort_score = phase_in_period(:) + tie_break;
    [~, sorted_index] = sort(sort_score, 'ascend');

    code_vector = -ones(number_samples, 1);
    code_vector(sorted_index(1:number_zero_state)) = 1;
    code = reshape(code_vector, size(phase));
end

function shifted_echo = shiftEcho(sr, range_offset_m, azimuth_offset_m, ...
    t, tm, c, R0, Kr, Ka, beta1, v_x)
% 小场景平移算子：快时间线性相位控制地距位置，慢时间线性相位
% 控制方位位置。这里用于放置真实飞机模板，不是超表面量化编码。
    slant_offset_m = range_offset_m * sin(beta1);
    range_frequency_hz = -2 * Kr * slant_offset_m / c;
    azimuth_frequency_hz = -Ka * azimuth_offset_m / v_x;
    fast_time_relative = t - 2*R0/c;
    phase = 2*pi * (azimuth_frequency_hz*tm(:) + ...
        range_frequency_hz*fast_time_relative);
    shifted_echo = sr .* exp(1j*phase);
end

function fig = createResultFigure(figure_name)
    fig = figure('Color', 'w', 'Name', figure_name, 'NumberTitle', 'off');
    if usejava('desktop')
        set(fig, 'WindowStyle', 'docked');
    else
        set(fig, 'Position', [100, 100, 780, 650]);
    end
end

function [img, R_axis_relative, Az_axis] = rdFocus( ...
    sr, t, tm, dt, c, R0, Tp, Kr, lambda, v_x, Ka, PRF)

    [Na, Nr] = size(sr);
    t_ref = ((-Nr/2):(Nr/2-1)) * dt;
    h_ref = exp(1j*pi*Kr*t_ref.^2) .* (abs(t_ref) <= Tp/2);
    H_range = conj(fft(fftshift(h_ref)));

    S_range = fft(sr, [], 2) .* H_range;
    s_rc = ifft(S_range, [], 2);

    S_az = fft(s_rc, [], 1);
    fa = (0:Na-1)'/Na * PRF;
    fa(fa > PRF/2) = fa(fa > PRF/2) - PRF;

    R_axis = t*c/2;
    s_rcmc = complex(zeros(size(S_az)));
    fprintf('执行 RCMC 插值...\n');
    for k = 1:Na
        move_factor = lambda^2 * fa(k)^2 / (8*v_x^2);
        shift_R = R_axis * move_factor;
        s_rcmc(k,:) = interp1(R_axis, S_az(k,:), ...
            R_axis + shift_R, 'linear', 0);
    end

    H_az = exp(1j*pi*fa.^2/Ka);
    img = ifft(s_rcmc .* H_az, [], 1);
    R_axis_relative = R_axis - R0;
    Az_axis = tm*v_x;
end

function plotSarDb(img, range_axis, az_axis, dynamic_range_db, ...
    reference_peak, display_half_width_m)
    img_db = 20*log10(abs(img) + eps);
    img_db = img_db - 20*log10(reference_peak);
    imagesc(range_axis, az_axis, img_db, [-dynamic_range_db, 0]);
    set(gca, 'YDir', 'normal');
    axis image;
    xlim([-display_half_width_m, display_half_width_m]);
    ylim([-display_half_width_m, display_half_width_m]);
    colormap gray;
    colorbar;
    xlabel('相对地距向 (m)');
    ylabel('方位向 (m)');
end
