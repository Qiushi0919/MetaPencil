% 允许外部入口脚本传入四相位驻留比例；直接运行本文件时仍是
% 25%/25%/25%/25% 的2-bit平衡单边带版本。
if ~exist('two_bit_state_dwell_fraction', 'var')
    two_bit_state_dwell_fraction = [0.25, 0.25, 0.25, 0.25];
end
if ~exist('two_bit_case_tag', 'var')
    two_bit_case_tag = 'ssb_2bit';
end
if ~exist('two_bit_case_title', 'var')
    two_bit_case_title = '2-bit平衡四相位SSB';
end
if ~exist('two_bit_result_description', 'var')
    two_bit_result_description = ...
        '零阶与反向一阶抑制，中央2×2由(+1,+1)主谐波生成';
end
if ~exist('two_bit_full_half_width_m', 'var')
    two_bit_full_half_width_m = 48;
end
if ~exist('two_bit_az_resolution_override_m', 'var')
    two_bit_az_resolution_override_m = [];
end
if ~exist('two_bit_harmonic_max_order', 'var')
    two_bit_harmonic_max_order = 9;
end
if ~exist('two_bit_partition_delay_fraction', 'var')
    two_bit_partition_delay_fraction = [];
end
if ~exist('two_bit_output_root_override', 'var')
    two_bit_output_root_override = '';
end
if ~exist('two_bit_dc_branch_fraction', 'var')
    % 设为正数时，将该面积比例保持未调制；其余面积执行2-bit编码。
    % 两个支路在距离和方位维分别做空间相干平均，可同时保留0/+1阶。
    two_bit_dc_branch_fraction = 0;
end
clearvars -except two_bit_state_dwell_fraction two_bit_case_tag ...
    two_bit_case_title two_bit_result_description ...
    two_bit_full_half_width_m two_bit_az_resolution_override_m ...
    two_bit_harmonic_max_order two_bit_partition_delay_fraction ...
    two_bit_output_root_override two_bit_dc_branch_fraction;
clc; close all;

%% 1. 运行配置
% 四角歼-36的二维2-bit四相位实验。距离快时间和方位慢时间分别
% 采用0/90/180/270度旋转编码，四个状态的驻留比例可配置。
resolution_mode = 'uav';
display_dynamic_range_db = 30;
display_main_orders_dynamic_range_db = 20;
display_half_width_m = 16;
display_full_half_width_m = two_bit_full_half_width_m;

% 4×4 阵列相邻中心间距。中心坐标为 [-12,-4,+4,+12] m。
grid_spacing_m = 8.0;
grid_axis_m = (-1.5:1:1.5) * grid_spacing_m;
outer_coordinate_m = max(abs(grid_axis_m));

% 单极化2-bit单元的四个复反射状态。第一版采用理想等幅四相位；
% 后续可直接填写实测的四状态幅度和相位误差进行非理想性分析。
state_amplitude = [1, 1, 1, 1];
state_phase_nominal_deg = [0, 90, 180, 270];
state_phase_error_deg = [0, 0, 0, 0];
state_phase_actual_deg = state_phase_nominal_deg + state_phase_error_deg;
state_response = state_amplitude .* exp(1j*deg2rad(state_phase_actual_deg));
state_dwell_fraction = two_bit_state_dwell_fraction(:).';
if numel(state_dwell_fraction) ~= 4 || ...
        any(state_dwell_fraction <= 0) || ...
        abs(sum(state_dwell_fraction)-1) > 1e-12
    error('四相位驻留比例必须是4个正数，且总和为1。');
end

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

if isempty(two_bit_output_root_override)
    output_root = fullfile(script_dir, ['results_4x4_', two_bit_case_tag]);
else
    output_root = two_bit_output_root_override;
end
if ~exist(output_root, 'dir')
    mkdir(output_root);
end
run_timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
run_dir = fullfile(output_root, ...
    sprintf('%s_%s', run_timestamp, resolution_mode));
mkdir(run_dir);

%% 2. 雷达、场景和分辨率参数
fprintf('正在生成四角歼-36的二维%s SAR回波...\n', ...
    two_bit_case_title);

partition_delay_fraction = two_bit_partition_delay_fraction(:).';
partition_supercell_enabled = ~isempty(partition_delay_fraction);
dc_branch_fraction = two_bit_dc_branch_fraction;
if ~isscalar(dc_branch_fraction) || ~isfinite(dc_branch_fraction) || ...
        dc_branch_fraction < 0 || dc_branch_fraction > 1
    error('未调制支路面积比例必须是[0,1]内的标量。');
end
modulated_branch_fraction = 1-dc_branch_fraction;
dc_branch_enabled = dc_branch_fraction > 0;
if partition_supercell_enabled
    if numel(partition_delay_fraction) ~= 4 || ...
            any(partition_delay_fraction < 0) || ...
            any(partition_delay_fraction >= 1)
        error('4×4局部超单元必须提供4个[0,1)范围内的归一化时延。');
    end
    ideal_four_state_response = exp(1j*deg2rad([0, 90, 180, 270]));
    if max(abs(state_response - ideal_four_state_response)) > 1e-12
        error(['当前4×4局部超单元快速等效只适用于理想等幅2-bit四相位。' ...
            '若要加入实测幅相误差，需要显式累加16种联合状态。']);
    end
    fprintf('启用单极化2-bit 4×4局部超单元相干抵消。\n');
    fprintf('归一化时延：[%.6f %.6f %.6f %.6f] T\n', ...
        partition_delay_fraction);
else
    fprintf('未启用局部超单元分区，使用整面同步编码。\n');
end

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

% 为了显示更大的方位视场，可以通过入口脚本增大合成孔径。
% 本参数为空时保持原版分辨率和视场不变。
if ~isempty(two_bit_az_resolution_override_m)
    desired_az_resolution = two_bit_az_resolution_override_m;
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

%% 5. 定义四角真实位置和期望目标位置
real_positions = [ ...
    -outer_coordinate_m, +outer_coordinate_m; ...
    +outer_coordinate_m, +outer_coordinate_m; ...
    -outer_coordinate_m, -outer_coordinate_m; ...
    +outer_coordinate_m, -outer_coordinate_m];

main_target_positions = [ ...
    -grid_spacing_m/2, +grid_spacing_m/2; ...
    +grid_spacing_m/2, +grid_spacing_m/2; ...
    -grid_spacing_m/2, -grid_spacing_m/2; ...
    +grid_spacing_m/2, -grid_spacing_m/2];

if dc_branch_enabled
    % 每架角点飞机同时保留距离/方位0阶和+1阶：
    % (0,0)、(1,0)、(0,1)、(1,1)。四架飞机合计形成4×4=16点。
    number_expected_targets = 4*4;
    source_id = zeros(number_expected_targets,1);
    range_order = zeros(number_expected_targets,1);
    azimuth_order = zeros(number_expected_targets,1);
    expected_range_m = zeros(number_expected_targets,1);
    expected_azimuth_m = zeros(number_expected_targets,1);
    source_range_column_m = zeros(number_expected_targets,1);
    source_azimuth_column_m = zeros(number_expected_targets,1);
    target_index = 0;
    for source_index = 1:size(real_positions,1)
        source_range_m = real_positions(source_index,1);
        source_azimuth_m = real_positions(source_index,2);
        inward_range_m = -sign(source_range_m)*grid_spacing_m;
        inward_azimuth_m = -sign(source_azimuth_m)*grid_spacing_m;
        for range_order_value = 0:1
            for azimuth_order_value = 0:1
                target_index = target_index+1;
                source_id(target_index) = source_index;
                range_order(target_index) = range_order_value;
                azimuth_order(target_index) = azimuth_order_value;
                expected_range_m(target_index) = source_range_m + ...
                    range_order_value*inward_range_m;
                expected_azimuth_m(target_index) = source_azimuth_m + ...
                    azimuth_order_value*inward_azimuth_m;
                source_range_column_m(target_index) = source_range_m;
                source_azimuth_column_m(target_index) = source_azimuth_m;
            end
        end
    end
    expected_positions = table((1:number_expected_targets).', source_id, ...
        range_order, azimuth_order, expected_range_m, expected_azimuth_m, ...
        source_range_column_m, source_azimuth_column_m, ...
        'VariableNames', {'target_id','source_id','range_order', ...
        'azimuth_order','range_m','azimuth_m','source_range_m', ...
        'source_azimuth_m'});
else
    expected_positions = table((1:4).', main_target_positions(:,1), ...
        main_target_positions(:,2), real_positions(:,1), real_positions(:,2), ...
        'VariableNames', {'target_id','range_m','azimuth_m', ...
        'source_range_m','source_azimuth_m'});
end

fprintf('期望主结果：%s。\n', two_bit_result_description);

%% 6. 四角真实机群回波与二维2-bit单边带回波

sr_real_corners = complex(zeros(Na, Nr));
sr_deception_ssb_2bit = complex(zeros(Na, Nr));

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

    [range_code, range_state_index] = fourPhaseRamp( ...
        range_phase, state_response, state_dwell_fraction);
    [azimuth_code, azimuth_state_index] = fourPhaseRamp( ...
        azimuth_phase, state_response, state_dwell_fraction);

    if partition_supercell_enabled
        % 每个局部雷达分辨单元内等效放置4×4=16个共址子单元。
        % P_pq的距离编码相移d_p，方位编码相移d_q；每个子单元
        % 仍只输出0/90/180/270度四个单极化状态。理想四相位条件下，
        % 16项平均可分解为两个4项平均的外积，避免复制16份大矩阵。
        range_partition_average = complex(zeros(size(range_phase)));
        azimuth_partition_average = complex(zeros(size(azimuth_phase)));
        for partition_index = 1:4
            phase_delay = 2*pi*partition_delay_fraction(partition_index);
            delayed_range_code = fourPhaseRamp( ...
                range_phase-phase_delay, state_response, ...
                state_dwell_fraction);
            delayed_azimuth_code = fourPhaseRamp( ...
                azimuth_phase-phase_delay, state_response, ...
                state_dwell_fraction);
            range_partition_average = range_partition_average + ...
                delayed_range_code/4;
            azimuth_partition_average = azimuth_partition_average + ...
                delayed_azimuth_code/4;
        end
        if dc_branch_enabled
            % 等效于把每个维度的表面分成“未调制0阶支路”和
            % “四时延分区调制+1阶支路”，再对两维做笛卡尔积。
            range_effective_response = dc_branch_fraction + ...
                modulated_branch_fraction*range_partition_average;
            azimuth_effective_response = dc_branch_fraction + ...
                modulated_branch_fraction*azimuth_partition_average;
            modulation_2d_ssb = azimuth_effective_response .* ...
                range_effective_response;
        else
            modulation_2d_ssb = ...
                azimuth_partition_average .* range_partition_average;
        end
        combined_state_index = mod(azimuth_state_index + ...
            range_state_index, 4);
    else
        % 两个2-bit相位索引相加并模4，二维联合调制仍只调用同一个
        % 单极化四状态单元，不需要4×4=16个物理相位状态。
        combined_state_index = mod(azimuth_state_index + ...
            range_state_index, 4);
        if dc_branch_enabled
            range_effective_response = dc_branch_fraction + ...
                modulated_branch_fraction*range_code;
            azimuth_effective_response = dc_branch_fraction + ...
                modulated_branch_fraction*azimuth_code;
            modulation_2d_ssb = azimuth_effective_response .* ...
                range_effective_response;
        else
            modulation_2d_ssb = reshape( ...
                state_response(combined_state_index(:)+1), ...
                size(combined_state_index));
        end
    end
    sr_deception_ssb_2bit = sr_deception_ssb_2bit + ...
        modulation_2d_ssb .* sr_source;

    if source_index == 1
        first_code_statistics.range_state_fraction = ...
            stateFractions(range_state_index);
        first_code_statistics.azimuth_state_fraction = ...
            stateFractions(azimuth_state_index);
        first_code_statistics.combined_state_fraction = ...
            stateFractions(combined_state_index);
    end

    fprintf(['角点 %d：(地距 %+.1f, 方位 %+.1f) m，' ...
        '向内基频 %.3f MHz / %.3f Hz\n'], ...
        source_index, source_range_m, source_azimuth_m, ...
        range_mod_frequency_hz/1e6, azimuth_mod_frequency_hz);
end

% 理想/非理想四状态响应的单维傅里叶系数。
diagnostic_orders = (-two_bit_harmonic_max_order: ...
    two_bit_harmonic_max_order).';
diagnostic_coefficients_base = arrayfun( ...
    @(order) steppedPhaseFourierCoefficient( ...
        order, state_response, state_dwell_fraction), diagnostic_orders);
if partition_supercell_enabled
    diagnostic_partition_factor = arrayfun( ...
        @(order) mean(exp(-1j*2*pi*order*partition_delay_fraction)), ...
        diagnostic_orders);
else
    diagnostic_partition_factor = ones(size(diagnostic_orders));
end
diagnostic_coefficients = diagnostic_coefficients_base .* ...
    diagnostic_partition_factor;
if dc_branch_enabled
    diagnostic_coefficients = ...
        modulated_branch_fraction*diagnostic_coefficients;
    diagnostic_coefficients(diagnostic_orders == 0) = ...
        diagnostic_coefficients(diagnostic_orders == 0) + ...
        dc_branch_fraction;
end
c0_base = diagnostic_coefficients_base(diagnostic_orders == 0);
c_plus1_base = diagnostic_coefficients_base(diagnostic_orders == 1);
c_minus1_base = diagnostic_coefficients_base(diagnostic_orders == -1);
c0 = diagnostic_coefficients(diagnostic_orders == 0);
c_plus1 = diagnostic_coefficients(diagnostic_orders == 1);
c_minus1 = diagnostic_coefficients(diagnostic_orders == -1);
c_minus3 = diagnostic_coefficients(diagnostic_orders == -3);
c_plus5 = diagnostic_coefficients(diagnostic_orders == 5);

fprintf('\n========== 单极化2-bit四相位编码检查 ==========\n');
fprintf('四状态幅度：[%.3f %.3f %.3f %.3f]\n', state_amplitude);
fprintf('四状态实际相位：[%.1f %.1f %.1f %.1f] deg\n', ...
    state_phase_actual_deg);
fprintf('四状态理论驻留比例：[%.2f %.2f %.2f %.2f]%%\n', ...
    100*state_dwell_fraction);
fprintf('距离四状态比例：[%.2f %.2f %.2f %.2f]%%\n', ...
    100*first_code_statistics.range_state_fraction);
fprintf('方位四状态比例：[%.2f %.2f %.2f %.2f]%%\n', ...
    100*first_code_statistics.azimuth_state_fraction);
fprintf('二维联合四状态比例：[%.2f %.2f %.2f %.2f]%%\n', ...
    100*first_code_statistics.combined_state_fraction);
fprintf('原2-bit系数：|C0|=%.6f，|C+1|=%.6f，|C-1|=%.6f\n', ...
    abs(c0_base), abs(c_plus1_base), abs(c_minus1_base));
if partition_supercell_enabled
    s_plus1 = diagnostic_partition_factor(diagnostic_orders == 1);
    s_minus3 = diagnostic_partition_factor(diagnostic_orders == -3);
    s_plus5 = diagnostic_partition_factor(diagnostic_orders == 5);
    fprintf('分区因子：|S+1|=%.6f，|S-3|=%.3e，|S+5|=%.3e\n', ...
        abs(s_plus1), abs(s_minus3), abs(s_plus5));
end
fprintf('最终系数：|C0S0|=%.6f，|C+1S+1|=%.6f，|C-1S-1|=%.6f\n', ...
    abs(c0), abs(c_plus1), abs(c_minus1));
if dc_branch_enabled
    fprintf('空间支路面积：未调制=%.4f，分区调制=%.4f\n', ...
        dc_branch_fraction, modulated_branch_fraction);
    fprintf(['目标阶次集合：{0,+1}×{0,+1}；二维幅度 ' ...
        '|A00|=%.6f，|A01|=%.6f，|A10|=%.6f，|A11|=%.6f\n'], ...
        abs(c0*c0), abs(c0*c_plus1), ...
        abs(c_plus1*c0), abs(c_plus1*c_plus1));
end
fprintf('二维主(+1,+1)幅度=%.6f，功率=%.2f%%，相对未调制=%.3f dB\n', ...
    abs(c_plus1)^2, 100*abs(c_plus1)^4, ...
    20*log10(abs(c_plus1)^2 + eps));
fprintf('主要十字项：|A(-3,+1)|=%.3e，|A(+5,+1)|=%.3e\n', ...
    abs(c_minus3*c_plus1), abs(c_plus5*c_plus1));

%% 7. RD 成像
fprintf('\n对未调制中心单机执行 RD 成像，建立统一0 dB参考...\n');
[img_single_reference, R_axis_slant_relative, Az_axis] = rdFocus( ...
    sr_center, t, tm, dt, c, R0, Tp, Kr, lambda, v_x, Ka, PRF);

fprintf('\n对四角真实飞机执行 RD 成像...\n');
[img_real_corners, ~, ~] = rdFocus( ...
    sr_real_corners, t, tm, dt, c, R0, Tp, Kr, lambda, v_x, Ka, PRF);

fprintf('对二维2-bit单边带欺骗回波执行 RD 成像...\n');
[img_deception_ssb_2bit, ~, ~] = rdFocus( ...
    sr_deception_ssb_2bit, t, tm, dt, c, R0, Tp, Kr, lambda, v_x, Ka, PRF);

Range_axis_ground = R_axis_slant_relative / sin(beta1);
single_aircraft_reference = max(abs(img_single_reference(:))) + eps;

%% 8. 画图
figure_layout = createResultFigure( ...
    sprintf('Figure 1 - %s期望布局', two_bit_case_title));
hold on;
scatter(real_positions(:,1), real_positions(:,2), 150, ...
    [0.80 0.15 0.10], 's', 'filled', ...
    'DisplayName', '四角真实飞机/零阶位置');
if dc_branch_enabled
    false_target_mask = expected_positions.range_order ~= 0 | ...
        expected_positions.azimuth_order ~= 0;
    scatter(expected_positions.range_m(false_target_mask), ...
        expected_positions.azimuth_m(false_target_mask), 120, ...
        [0.05 0.60 0.35], 'd', 'filled', ...
        'DisplayName', '12个0/+1阶组合假目标');
    for target_index = 1:height(expected_positions)
        if false_target_mask(target_index)
            plot([expected_positions.source_range_m(target_index), ...
                expected_positions.range_m(target_index)], ...
                [expected_positions.source_azimuth_m(target_index), ...
                expected_positions.azimuth_m(target_index)], ...
                '--', 'Color',[0.55 0.55 0.55], ...
                'HandleVisibility','off');
        end
    end
else
    scatter(main_target_positions(:,1), main_target_positions(:,2), 150, ...
        [0.05 0.60 0.35], 'd', 'filled', ...
        'DisplayName', '中央2×2主假目标 (+1,+1)');
    for index = 1:size(real_positions,1)
        plot([real_positions(index,1), main_target_positions(index,1)], ...
            [real_positions(index,2), main_target_positions(index,2)], ...
            '--', 'Color',[0.35 0.35 0.35], 'HandleVisibility','off');
    end
end
hold off;
axis equal;
grid on;
xlim([-outer_coordinate_m-2, outer_coordinate_m+2]);
ylim([-outer_coordinate_m-2, outer_coordinate_m+2]);
xticks(grid_axis_m);
yticks(grid_axis_m);
xlabel('相对地距向 (m)');
ylabel('方位向 (m)');
title(sprintf('%s：%s', two_bit_case_title, two_bit_result_description));
legend('Location', 'southoutside', 'Orientation', 'horizontal');

figure_real = createResultFigure('Figure 2 - 四角真实歼-36');
plotSarDb(img_real_corners, Range_axis_ground, Az_axis, ...
    display_dynamic_range_db, single_aircraft_reference, display_half_width_m);
title(sprintf('未调制四角真实歼-36（间距 %.1f m）', grid_spacing_m));

figure_deception = createResultFigure( ...
    sprintf('Figure 3 - %s（阵列区域）', two_bit_case_title));
plotSarDb(img_deception_ssb_2bit, Range_axis_ground, Az_axis, ...
    display_dynamic_range_db, single_aircraft_reference, display_half_width_m);
title(sprintf('%s：阵列区域', two_bit_case_title));

if dc_branch_enabled
    focus_region_name = '4×4目标群';
    focus_file_tag = 'target_grid_4x4';
else
    focus_region_name = '中央2×2';
    focus_file_tag = 'central_2x2';
end
figure_deception_main = createResultFigure( ...
    sprintf('Figure 4 - %s%s', two_bit_case_title, focus_region_name));
plotSarDb(img_deception_ssb_2bit, Range_axis_ground, Az_axis, ...
    display_main_orders_dynamic_range_db, single_aircraft_reference, ...
    display_half_width_m);
title(sprintf('%s：显示下限 -%.0f dB（单机峰值=0 dB）', ...
    two_bit_case_title, display_main_orders_dynamic_range_db));

figure_deception_full = createResultFigure( ...
    sprintf('Figure 5 - %s完整视场', two_bit_case_title));
plotSarDb(img_deception_ssb_2bit, Range_axis_ground, Az_axis, ...
    display_dynamic_range_db, single_aircraft_reference, ...
    display_full_half_width_m);
title(sprintf('%s完整视场', two_bit_case_title));

%% 9. 单维谐波幅度与二维谐波矩阵
harmonic_orders = (-two_bit_harmonic_max_order: ...
    two_bit_harmonic_max_order).';
harmonic_coefficients_base = arrayfun( ...
    @(order) steppedPhaseFourierCoefficient( ...
        order, state_response, state_dwell_fraction), ...
    harmonic_orders);
if partition_supercell_enabled
    harmonic_partition_factor = arrayfun( ...
        @(order) mean(exp(-1j*2*pi*order*partition_delay_fraction)), ...
        harmonic_orders);
else
    harmonic_partition_factor = ones(size(harmonic_orders));
end
harmonic_coefficients = harmonic_coefficients_base .* ...
    harmonic_partition_factor;
if dc_branch_enabled
    harmonic_coefficients = ...
        modulated_branch_fraction*harmonic_coefficients;
    harmonic_coefficients(harmonic_orders == 0) = ...
        harmonic_coefficients(harmonic_orders == 0) + ...
        dc_branch_fraction;
end
harmonic_amplitude = abs(harmonic_coefficients);
harmonic_amplitude_db = 20*log10(harmonic_amplitude + eps);
harmonic_offset_m = harmonic_orders * grid_spacing_m;

harmonic_table = table(harmonic_orders, harmonic_offset_m, ...
    real(harmonic_coefficients_base), imag(harmonic_coefficients_base), ...
    abs(harmonic_partition_factor), ...
    real(harmonic_coefficients), imag(harmonic_coefficients), ...
    harmonic_amplitude, harmonic_amplitude_db, ...
    'VariableNames', {'harmonic_order','spatial_offset_m', ...
    'base_coefficient_real','base_coefficient_imag','partition_factor', ...
    'coefficient_real','coefficient_imag','amplitude','amplitude_db'});

figure_harmonics = createResultFigure( ...
    sprintf('Figure 6 - %s各次谐波幅度', two_bit_case_title));
tiledlayout(2,1, 'TileSpacing','compact', 'Padding','compact');
sgtitle(sprintf('%s：各次谐波幅度', two_bit_case_title));

harmonic_plot_db = max(harmonic_amplitude_db, -45);

nexttile;
stem(harmonic_offset_m, harmonic_plot_db, ...
    'filled', 'LineWidth', 1.4, 'MarkerSize', 5);
hold on;
yline(0, '--k', '未加超表面：A=1（0 dB）', ...
    'LabelHorizontalAlignment','left');
hold off;
grid on;
xlim([min(harmonic_offset_m)-grid_spacing_m/2, ...
    max(harmonic_offset_m)+grid_spacing_m/2]);
ylim([-45, 2]);
xticks(harmonic_offset_m);
xlabel('距离向偏移 / m');
ylabel('相对未调制单机幅度 / dB');
if dc_branch_enabled
    title(sprintf('距离向最终系数（目标0/+1阶，间距 %.1f m）', ...
        grid_spacing_m));
else
    title(sprintf('距离向最终系数（目标+1阶，间距 %.1f m）', ...
        grid_spacing_m));
end
for index = 1:numel(harmonic_orders)
    text(harmonic_offset_m(index), harmonic_plot_db(index)+1.0, ...
        sprintf('n=%+d', harmonic_orders(index)), ...
        'HorizontalAlignment','center', 'FontSize',8);
end

nexttile;
stem(harmonic_offset_m, harmonic_plot_db, ...
    'filled', 'LineWidth', 1.4, 'MarkerSize', 5);
hold on;
yline(0, '--k', '未加超表面：A=1（0 dB）', ...
    'LabelHorizontalAlignment','left');
hold off;
grid on;
xlim([min(harmonic_offset_m)-grid_spacing_m/2, ...
    max(harmonic_offset_m)+grid_spacing_m/2]);
ylim([-45, 2]);
xticks(harmonic_offset_m);
xlabel('方位向偏移 / m');
ylabel('相对未调制单机幅度 / dB');
if dc_branch_enabled
    title(sprintf('方位向最终系数（目标0/+1阶，间距 %.1f m）', ...
        grid_spacing_m));
else
    title(sprintf('方位向最终系数（目标+1阶，间距 %.1f m）', ...
        grid_spacing_m));
end
for index = 1:numel(harmonic_orders)
    text(harmonic_offset_m(index), harmonic_plot_db(index)+1.0, ...
        sprintf('n=%+d', harmonic_orders(index)), ...
        'HorizontalAlignment','center', 'FontSize',8);
end

two_dimensional_amplitude = harmonic_amplitude * harmonic_amplitude.';
two_dimensional_amplitude_db = 20*log10( ...
    two_dimensional_amplitude + eps);
figure_harmonic_matrix = createResultFigure( ...
    sprintf('Figure 7 - %s二维谐波矩阵', two_bit_case_title));
imagesc(harmonic_orders, harmonic_orders, ...
    two_dimensional_amplitude_db, [-45, 0]);
set(gca,'YDir','normal');
axis image;
colormap gray;
colorbar;
xticks(harmonic_orders);
yticks(harmonic_orders);
xlabel('距离谐波阶次 n_r');
ylabel('方位谐波阶次 n_a');
title('二维谐波幅度：20log_{10}|C_{n_r}C_{n_a}|');

%% 10. 自动保存
layout_png = fullfile(run_dir, 'array_layout_4x4.png');
layout_fig = fullfile(run_dir, 'array_layout_4x4.fig');
real_png = fullfile(run_dir, 'sar_four_real_corners.png');
real_fig = fullfile(run_dir, 'sar_four_real_corners.fig');
deception_png = fullfile(run_dir, ...
    sprintf('sar_4x4_%s.png', two_bit_case_tag));
deception_fig = fullfile(run_dir, ...
    sprintf('sar_4x4_%s.fig', two_bit_case_tag));
deception_main_png = fullfile(run_dir, ...
    sprintf('sar_4x4_%s_%s.png', two_bit_case_tag, focus_file_tag));
deception_main_fig = fullfile(run_dir, ...
    sprintf('sar_4x4_%s_%s.fig', two_bit_case_tag, focus_file_tag));
deception_full_png = fullfile(run_dir, ...
    sprintf('sar_4x4_%s_full_field.png', two_bit_case_tag));
deception_full_fig = fullfile(run_dir, ...
    sprintf('sar_4x4_%s_full_field.fig', two_bit_case_tag));
harmonics_png = fullfile(run_dir, ...
    sprintf('%s_harmonic_amplitudes.png', two_bit_case_tag));
harmonics_fig = fullfile(run_dir, ...
    sprintf('%s_harmonic_amplitudes.fig', two_bit_case_tag));
harmonics_csv = fullfile(run_dir, ...
    sprintf('%s_harmonic_amplitudes.csv', two_bit_case_tag));
harmonic_matrix_png = fullfile(run_dir, ...
    sprintf('%s_harmonic_matrix.png', two_bit_case_tag));
harmonic_matrix_fig = fullfile(run_dir, ...
    sprintf('%s_harmonic_matrix.fig', two_bit_case_tag));
mat_file = fullfile(run_dir, ...
    sprintf('sar_results_4x4_%s.mat', two_bit_case_tag));
position_csv = fullfile(run_dir, ...
    sprintf('expected_positions_%s.csv', two_bit_case_tag));

if exist('exportgraphics', 'file') == 2
    exportgraphics(figure_layout, layout_png, 'Resolution', 200);
    exportgraphics(figure_real, real_png, 'Resolution', 200);
    exportgraphics(figure_deception, deception_png, 'Resolution', 200);
    exportgraphics(figure_deception_main, deception_main_png, 'Resolution', 200);
    exportgraphics(figure_deception_full, deception_full_png, 'Resolution', 200);
    exportgraphics(figure_harmonics, harmonics_png, 'Resolution', 200);
    exportgraphics(figure_harmonic_matrix, harmonic_matrix_png, 'Resolution', 200);
else
    saveas(figure_layout, layout_png);
    saveas(figure_real, real_png);
    saveas(figure_deception, deception_png);
    saveas(figure_deception_main, deception_main_png);
    saveas(figure_deception_full, deception_full_png);
    saveas(figure_harmonics, harmonics_png);
    saveas(figure_harmonic_matrix, harmonic_matrix_png);
end
savefig(figure_layout, layout_fig);
savefig(figure_real, real_fig);
savefig(figure_deception, deception_fig);
savefig(figure_deception_main, deception_main_fig);
savefig(figure_deception_full, deception_full_fig);
savefig(figure_harmonics, harmonics_fig);
savefig(figure_harmonic_matrix, harmonic_matrix_fig);
writetable(expected_positions, position_csv);
writetable(harmonic_table, harmonics_csv);

save(mat_file, 'img_single_reference', 'img_real_corners', ...
    'img_deception_ssb_2bit', 'single_aircraft_reference', ...
    'R_axis_slant_relative', 'Range_axis_ground', 'Az_axis', ...
    'expected_positions', 'real_positions', 'main_target_positions', ...
    'grid_axis_m', 'grid_spacing_m', 'state_amplitude', ...
    'state_dwell_fraction', 'two_bit_case_tag', 'two_bit_case_title', ...
    'display_full_half_width_m', 'two_bit_az_resolution_override_m', ...
    'two_bit_harmonic_max_order', ...
    'state_phase_nominal_deg', 'state_phase_error_deg', ...
    'state_phase_actual_deg', 'state_response', ...
    'partition_supercell_enabled', 'partition_delay_fraction', ...
    'dc_branch_enabled', 'dc_branch_fraction', ...
    'modulated_branch_fraction', ...
    'diagnostic_partition_factor', ...
    'first_code_statistics', 'c0_base', 'c_plus1_base', ...
    'c_minus1_base', 'c0', 'c_plus1', 'c_minus1', ...
    'c_minus3', 'c_plus5', ...
    'harmonic_orders', 'harmonic_offset_m', ...
    'harmonic_coefficients_base', 'harmonic_partition_factor', ...
    'harmonic_coefficients', 'harmonic_amplitude', ...
    'harmonic_amplitude_db', 'two_dimensional_amplitude', ...
    'two_dimensional_amplitude_db', 'resolution_mode', ...
    'actual_ground_range_resolution', 'actual_az_resolution', '-v7.3');

fprintf('\n结果已保存至：\n%s\n', run_dir);

%% ====================== 局部函数 ======================
function coefficient = steppedPhaseFourierCoefficient( ...
    order, state_response, state_dwell_fraction)
% 四个时间槽内分别保持state_response的复反射系数，
% state_dwell_fraction给出各时间槽占一个调制周期的比例。
% 傅里叶约定：Gamma(phi)=sum_n C_n*exp(j*n*phi)。
    number_states = numel(state_response);
    phase_edges = 2*pi * [0, cumsum(state_dwell_fraction)];
    if order == 0
        coefficient = sum(state_response .* state_dwell_fraction);
    else
        coefficient = 0;
        for state_index = 0:(number_states-1)
            phase_start = phase_edges(state_index+1);
            phase_end = phase_edges(state_index+2);
            slot_integral = (exp(-1j*order*phase_start) - ...
                exp(-1j*order*phase_end)) / (1j*order);
            coefficient = coefficient + ...
                state_response(state_index+1) * slot_integral/(2*pi);
        end
    end
end

function [code, state_index] = fourPhaseRamp( ...
    phase, state_response, state_dwell_fraction)
% 按state_dwell_fraction将一个2pi周期分成四个相位槽。
% 输出索引0/1/2/3和对应单极化2-bit复反射系数。
    phase_in_period = mod(phase, 2*pi);
    normalized_phase = phase_in_period/(2*pi);
    state_edges = [0, cumsum(state_dwell_fraction)];
    state_index = zeros(size(normalized_phase));
    for index = 1:3
        state_index(normalized_phase >= state_edges(index+1)) = index;
    end
    code = reshape(state_response(state_index(:)+1), size(state_index));
end

function fractions = stateFractions(state_index)
% 返回四个状态在当前离散采样中的实际比例。
    fractions = zeros(1,4);
    for index = 0:3
        fractions(index+1) = mean(state_index(:) == index);
    end
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
