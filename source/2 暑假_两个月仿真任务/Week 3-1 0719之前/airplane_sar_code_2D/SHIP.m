clearvars; clc; close all;

%% 1. 运行配置
% 小型实验飞机的近程机载聚束 SAR 参数。
%   'preview' : 快速预览，地距向约 0.30 m，方位向约 0.30 m
%   'uav'     : 默认实验，地距向约 0.15 m，方位向约 0.15 m
%   'high'    : 计算量较大，地距向约 0.10 m，方位向约 0.10 m
resolution_mode = 'uav';

% 成像显示动态范围。
display_dynamic_range_db = 25;
display_half_width_m = 10;

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

output_root = fullfile(script_dir, 'results');
if ~exist(output_root, 'dir')
    mkdir(output_root);
end

run_timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
run_name = sprintf('%s_%s', run_timestamp, resolution_mode);
run_dir = fullfile(output_root, run_name);
mkdir(run_dir);

%% 2. 雷达、场景和分辨率参数
fprintf('正在生成飞机目标的 SAR 原始回波...\n');

c = 3e8;
fc = 10e9;
lambda = c / fc;
Tp = 1e-6;

% 近程机载聚束几何：斜距约 1 km
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
        max_scatter_points = inf;
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

% 距离向原始分辨率是斜距分辨率；这里反推带宽，
% 使投影到地面后的地距分辨率达到用户设定值。
desired_slant_range_resolution = ...
    desired_ground_range_resolution * sin(beta1);
Br = c / (2 * desired_slant_range_resolution);
Kr = Br / Tp;
range_oversample = 1.20;
Fs = range_oversample * Br;

% 由所需方位分辨率反推合成孔径长度和观测时间。
% rho_a 约等于 lambda*R0/(2*Lsa)。
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

% 为目标尺寸和距离徙动留出快时间边界，避免脉冲被窗口截断。
range_margin_m = max(30, synthetic_aperture_length^2/(8*R0) + 5);
fast_time_span = Tp + 4*range_margin_m/c;
Nr = 2^nextpow2(ceil(fast_time_span * Fs));
t = 2*R0/c + ((-Nr/2):(Nr/2-1)) / Fs;
dt = 1/Fs;

actual_slant_range_resolution = c/(2*Br);
actual_ground_range_resolution = actual_slant_range_resolution/sin(beta1);
actual_aperture_length = (max(tm)-min(tm))*v_x;
actual_az_resolution = lambda*R0/(2*actual_aperture_length);

fprintf('分辨率模式: %s\n', resolution_mode);
fprintf('斜距 R0 = %.1f m，波长 = %.4f m\n', R0, lambda);
fprintf('距离向带宽 = %.1f MHz，斜距/地距分辨率 = %.3f/%.3f m\n', ...
    Br/1e6, actual_slant_range_resolution, actual_ground_range_resolution);
fprintf('合成孔径 = %.1f m，方位向分辨率约 = %.3f m\n', ...
    actual_aperture_length, actual_az_resolution);
fprintf('PRF = %.1f Hz，Fs = %.1f MHz，Na = %d，Nr = %d\n', ...
    PRF, Fs/1e6, Na, Nr);

estimated_raw_echo_mb = 16 * Na * Nr / 1024^2;
fprintf('每个复数回波矩阵约 %.1f MB。\n', estimated_raw_echo_mb);

%% 3. 加载飞机纯二维散射点
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

% 数据格式：[方位, 地距]。所有散射点都位于地面高度 z=0。
if size(target,2) ~= 2
    error(['纯二维散射点数据应为 2 列。请先运行 ship_trans.m，' ...
        '重新生成 airplane_scatter_points.mat。']);
end
target_azimuth = target(:,1) + X0;
target_ground_range = target(:,2) + Y0;
Ntar = size(target, 1);

fprintf('使用散射点数 = %d/%d\n', Ntar, size(target_all,1));
fprintf('飞机方位向尺寸约 %.3f m，地距向尺寸约 %.3f m\n', ...
    max(target(:,1))-min(target(:,1)), max(target(:,2))-min(target(:,2)));

estimated_work = double(Ntar) * double(Na) * double(Nr);
fprintf('回波生成规模指标 Ntar*Na*Nr = %.3g\n', estimated_work);

%% 4. 可控假目标与超表面反射参数
% 假目标中心相对于真实飞机中心的位置。
false_range_offset_m = 3.0;
false_azimuth_offset_m = 2.0;

% 被动超表面的功率反射效率必须不大于 1。
% 复反射系数的幅度等于功率效率的平方根。
reflection_power_efficiency = 0.80;
if ~isscalar(reflection_power_efficiency) || ...
        ~isfinite(reflection_power_efficiency) || ...
        reflection_power_efficiency < 0 || reflection_power_efficiency > 1
    error('被动超表面的功率反射效率必须位于 [0,1]。');
end
reflection_amplitude = sqrt(reflection_power_efficiency);

fprintf('设定假目标中心偏移：地距 %+.2f m，方位 %+.2f m\n', ...
    false_range_offset_m, false_azimuth_offset_m);
fprintf('超表面功率反射效率：%.1f%%，反射幅度系数：%.3f\n', ...
    100*reflection_power_efficiency, reflection_amplitude);

%% 5. 生成普通飞机原始回波
sr_plain = complex(zeros(Na, Nr));

fprintf('开始累加散射点回波...\n');

for i = 1:Ntar
    for k = 1:Na
        % 纯二维目标：所有散射点高度固定为 z=0，不保存也不读取高度。
        % H0 只表示雷达平台高度，用于将二维地面坐标换算为斜距。
        delta_azimuth = x_radar(k) - target_azimuth(i);
        r_inst = sqrt(delta_azimuth^2 + ...
            target_ground_range(i)^2 + H0^2);

        % 所有二维散射点的基础散射系数相同，只保留距离衰减。
        scatter_amplitude = (R0/r_inst)^2;

        tr_delay = 2*r_inst/c;
        tau = t - tr_delay;
        pulse_mask = abs(tau) <= Tp/2;

        s_pulse = scatter_amplitude .* pulse_mask .* ...
            exp(1j*pi*Kr*tau.^2) .* exp(-1j*4*pi*r_inst/lambda);

        sr_plain(k,:) = sr_plain(k,:) + s_pulse;
    end

    if mod(i,25) == 0 || i == Ntar
        fprintf('已处理点数: %d/%d\n', i, Ntar);
    end
end

%% 6. 生成 1-bit 超表面假目标回波
% 距离向：快时间线性相位改变脉冲压缩峰值位置。
% 方位向：慢时间线性相位改变多普勒中心，从而平移方位位置。
false_slant_offset_m = false_range_offset_m * sin(beta1);
range_mod_frequency_hz = -2 * Kr * false_slant_offset_m / c;
azimuth_mod_frequency_hz = -Ka * false_azimuth_offset_m / v_x;

fast_time_relative = t - 2*R0/c;
phase_command = 2*pi * ( ...
    azimuth_mod_frequency_hz * tm(:) + ...
    range_mod_frequency_hz * fast_time_relative);

% 使用 50%/50% 的平衡 0/pi 编码。
modulation_1bit = ones(size(phase_command));
modulation_1bit(cos(phase_command) < 0) = -1;

reflection_coefficient = reflection_amplitude * modulation_1bit;
sr_metasurface = reflection_coefficient .* sr_plain;

plain_raw_energy = sum(abs(sr_plain).^2, 'all');
metasurface_raw_energy = sum(abs(sr_metasurface).^2, 'all');
raw_energy_ratio = metasurface_raw_energy / (plain_raw_energy + eps);

fprintf('1-bit 调制基频：快时间 %+.3f MHz，慢时间 %+.3f Hz\n', ...
    range_mod_frequency_hz/1e6, azimuth_mod_frequency_hz);
fprintf('超表面/裸机原始回波能量比：%.6f（设定 %.6f）\n', ...
    raw_energy_ratio, reflection_power_efficiency);

%% 7. RD 成像
fprintf('对普通飞机执行 RD 成像...\n');
[img_plain, R_axis_slant_relative, Az_axis] = rdFocus( ...
    sr_plain, t, tm, dt, c, R0, Tp, Kr, lambda, v_x, Ka, PRF);

fprintf('对加超表面的飞机执行 RD 成像...\n');
[img_metasurface, ~, ~] = rdFocus( ...
    sr_metasurface, t, tm, dt, c, R0, Tp, Kr, lambda, v_x, Ka, PRF);

% RD 处理内部使用斜距，显示时投影到地距坐标。
Range_axis_ground = R_axis_slant_relative / sin(beta1);

%% 8. 定量指标
plain_metrics = imageMetrics(img_plain, Range_axis_ground, Az_axis);
metasurface_metrics = imageMetrics( ...
    img_metasurface, Range_axis_ground, Az_axis);

fprintf('\n========== 成像指标 ==========\n');
printMetrics('未加超表面', plain_metrics);
printMetrics('加 1-bit 超表面', metasurface_metrics);

metrics_table = table( ...
    {'未加超表面'; '加1-bit超表面'}, ...
    repmat({char(resolution_mode)}, 2, 1), ...
    [plain_metrics.peak_amplitude; metasurface_metrics.peak_amplitude], ...
    [plain_metrics.total_energy; metasurface_metrics.total_energy], ...
    [plain_metrics.peak_range_m; metasurface_metrics.peak_range_m], ...
    [plain_metrics.peak_azimuth_m; metasurface_metrics.peak_azimuth_m], ...
    [plain_metrics.area_3db_m2; metasurface_metrics.area_3db_m2], ...
    'VariableNames', {'case_name','resolution_mode','peak_amplitude', ...
    'total_energy','peak_range_m','peak_azimuth_m','area_3db_m2'});

%% 9. 只显示未加/加超表面的两幅 SAR 图
comparison_reference = max([max(abs(img_plain(:))), ...
    max(abs(img_metasurface(:)))]) + eps;

figure_plain = createResultFigure('Figure 1 - 未加超表面');
plotSarDb(img_plain, Range_axis_ground, Az_axis, ...
    display_dynamic_range_db, comparison_reference, display_half_width_m);
title(sprintf('未加超表面 - 地距/方位分辨率 %.2f/%.2f m', ...
    actual_ground_range_resolution, actual_az_resolution));

figure_metasurface = createResultFigure('Figure 2 - 加 1-bit 超表面');
plotSarDb(img_metasurface, Range_axis_ground, Az_axis, ...
    display_dynamic_range_db, comparison_reference, display_half_width_m);
title(sprintf('加 1-bit 超表面 - 假目标偏移 地距 %+.1f m / 方位 %+.1f m', ...
    false_range_offset_m, false_azimuth_offset_m));

%% 10. 自动保存
plain_png_file = fullfile(run_dir, 'sar_plain.png');
plain_fig_file = fullfile(run_dir, 'sar_plain.fig');
metasurface_png_file = fullfile(run_dir, 'sar_metasurface.png');
metasurface_fig_file = fullfile(run_dir, 'sar_metasurface.fig');
mat_file = fullfile(run_dir, 'sar_results.mat');
csv_file = fullfile(run_dir, 'metrics.csv');

if exist('exportgraphics', 'file') == 2
    exportgraphics(figure_plain, plain_png_file, 'Resolution', 200);
    exportgraphics(figure_metasurface, metasurface_png_file, 'Resolution', 200);
else
    saveas(figure_plain, plain_png_file);
    saveas(figure_metasurface, metasurface_png_file);
end
savefig(figure_plain, plain_fig_file);
savefig(figure_metasurface, metasurface_fig_file);
writetable(metrics_table, csv_file);

save(mat_file, 'img_plain', 'img_metasurface', ...
    'R_axis_slant_relative', 'Range_axis_ground', 'Az_axis', ...
    'plain_metrics', 'metasurface_metrics', 'resolution_mode', ...
    'false_range_offset_m', 'false_azimuth_offset_m', ...
    'reflection_power_efficiency', 'reflection_amplitude', ...
    'plain_raw_energy', 'metasurface_raw_energy', 'raw_energy_ratio', ...
    'actual_slant_range_resolution', 'actual_ground_range_resolution', ...
    'actual_az_resolution', '-v7.3');

fprintf('\n结果已保存至：\n%s\n', run_dir);

%% ====================== 局部函数 ======================
function fig = createResultFigure(figure_name)
    fig = figure('Color', 'w', 'Name', figure_name, 'NumberTitle', 'off');
    if usejava('desktop')
        % 两幅图停靠在 MATLAB 的 Figures 区域，通过底部标签页切换。
        set(fig, 'WindowStyle', 'docked');
    else
        % 无桌面的批处理模式仍使用普通窗口，保证图片可以自动导出。
        set(fig, 'Position', [100, 100, 760, 620]);
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

function metrics = imageMetrics(img, range_axis, az_axis)
    amplitude = abs(img);
    power_img = amplitude.^2;
    [metrics.peak_amplitude, linear_index] = max(amplitude(:));
    metrics.total_energy = sum(power_img(:));

    [az_index, range_index] = ind2sub(size(amplitude), linear_index);
    metrics.peak_range_m = range_axis(range_index);
    metrics.peak_azimuth_m = az_axis(az_index);

    weight_sum = sum(power_img(:)) + eps;
    range_weight = sum(power_img, 1);
    az_weight = sum(power_img, 2);
    metrics.centroid_range_m = sum(range_axis .* range_weight) / weight_sum;
    metrics.centroid_azimuth_m = sum(az_axis(:) .* az_weight) / weight_sum;

    mask_3db = amplitude >= metrics.peak_amplitude*10^(-3/20);
    if numel(range_axis) > 1
        dr = abs(range_axis(2)-range_axis(1));
    else
        dr = 0;
    end
    if numel(az_axis) > 1
        da = abs(az_axis(2)-az_axis(1));
    else
        da = 0;
    end
    metrics.area_3db_m2 = nnz(mask_3db)*dr*da;
end

function printMetrics(label, metrics)
    fprintf('%s：\n', label);
    fprintf('  峰值幅度 = %.6g\n', metrics.peak_amplitude);
    fprintf('  积分能量 = %.6g\n', metrics.total_energy);
    fprintf('  峰值位置 = (距离 %.3f m, 方位 %.3f m)\n', ...
        metrics.peak_range_m, metrics.peak_azimuth_m);
    fprintf('  -3 dB 面积 = %.3f m^2\n', metrics.area_3db_m2);
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
