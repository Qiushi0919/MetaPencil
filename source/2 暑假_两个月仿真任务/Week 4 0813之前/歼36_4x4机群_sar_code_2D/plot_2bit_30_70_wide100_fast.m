clearvars; clc; close all;

%% 使用已聚焦的中心单机模板，按理论二维谐波系数合成±100 m视场
% 本脚本不重复计算长孔径原始回波，但保留当前模型中的谐波位置、
% 复幅度及重合目标的相干叠加，适合快速查看高阶假目标分布。

script_dir = fileparts(mfilename('fullpath'));
source_root = fullfile(script_dir, 'results_4x4_2bit_30_70');
source_runs = dir(fullfile(source_root, '*_uav'));
source_runs = source_runs([source_runs.isdir]);
if isempty(source_runs)
    error('找不到2-bit 30/70基础结果，请先运行SHIP_4x4_2bit_30_70.m。');
end
[~, newest_index] = max([source_runs.datenum]);
source_mat = fullfile(source_runs(newest_index).folder, ...
    source_runs(newest_index).name, 'sar_results_4x4_2bit_30_70.mat');

loaded = load(source_mat, 'img_single_reference', ...
    'single_aircraft_reference', 'Range_axis_ground', 'Az_axis', ...
    'real_positions', 'grid_spacing_m', 'state_response', ...
    'state_dwell_fraction');

view_half_width_m = 100;
template_half_width_m = 4.5;
maximum_order = 15;
display_ranges_db = [30, 40];

dx = mean(diff(loaded.Range_axis_ground));
dy = mean(diff(loaded.Az_axis));
pixel_spacing_m = min(dx, dy);
wide_axis = -view_half_width_m:pixel_spacing_m:view_half_width_m;

range_template_mask = abs(loaded.Range_axis_ground) <= ...
    template_half_width_m;
azimuth_template_mask = abs(loaded.Az_axis) <= ...
    template_half_width_m;
template = loaded.img_single_reference( ...
    azimuth_template_mask, range_template_mask);
template_range_axis = loaded.Range_axis_ground(range_template_mask);
template_azimuth_axis = loaded.Az_axis(azimuth_template_mask);

orders = (-maximum_order:maximum_order).';
coefficients = arrayfun(@(order) steppedPhaseFourierCoefficient( ...
    order, loaded.state_response, loaded.state_dwell_fraction), orders);

wide_image = complex(zeros(numel(wide_axis), numel(wide_axis)));
for source_index = 1:size(loaded.real_positions,1)
    source_range_m = loaded.real_positions(source_index,1);
    source_azimuth_m = loaded.real_positions(source_index,2);
    inward_range_m = -sign(source_range_m) * loaded.grid_spacing_m;
    inward_azimuth_m = -sign(source_azimuth_m) * loaded.grid_spacing_m;

    for range_index = 1:numel(orders)
        target_range_m = source_range_m + ...
            orders(range_index)*inward_range_m;
        output_range_indices = round((target_range_m + ...
            template_range_axis - wide_axis(1))/pixel_spacing_m) + 1;
        valid_range = output_range_indices >= 1 & ...
            output_range_indices <= numel(wide_axis);
        if ~any(valid_range)
            continue;
        end

        for azimuth_index = 1:numel(orders)
            target_azimuth_m = source_azimuth_m + ...
                orders(azimuth_index)*inward_azimuth_m;
            output_azimuth_indices = round((target_azimuth_m + ...
                template_azimuth_axis - wide_axis(1))/pixel_spacing_m) + 1;
            valid_azimuth = output_azimuth_indices >= 1 & ...
                output_azimuth_indices <= numel(wide_axis);
            if ~any(valid_azimuth)
                continue;
            end

            two_dimensional_coefficient = ...
                coefficients(range_index)*coefficients(azimuth_index);
            wide_image(output_azimuth_indices(valid_azimuth), ...
                output_range_indices(valid_range)) = ...
                wide_image(output_azimuth_indices(valid_azimuth), ...
                output_range_indices(valid_range)) + ...
                two_dimensional_coefficient * ...
                template(valid_azimuth, valid_range);
        end
    end
end

output_root = fullfile(script_dir, ...
    'results_4x4_2bit_30_70_wide100_fast');
if ~exist(output_root, 'dir')
    mkdir(output_root);
end
run_dir = fullfile(output_root, ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
mkdir(run_dir);

for display_index = 1:numel(display_ranges_db)
    dynamic_range_db = display_ranges_db(display_index);
    figure_wide = figure('Color','w', 'Position',[100,100,900,760]);
    image_db = 20*log10(abs(wide_image) + eps) - ...
        20*log10(loaded.single_aircraft_reference);
    imagesc(wide_axis, wide_axis, image_db, [-dynamic_range_db, 0]);
    set(gca, 'YDir','normal');
    axis image;
    xlim([-view_half_width_m, view_half_width_m]);
    ylim([-view_half_width_m, view_half_width_m]);
    xticks(-100:20:100);
    yticks(-100:20:100);
    grid on;
    colormap gray;
    colorbar;
    xlabel('相对地距向 (m)');
    ylabel('方位向 (m)');
    title(sprintf(['2-bit 30/70非平衡四相位编码：' ...
        '±100 m谐波合成（下限 -%d dB）'], dynamic_range_db));

    png_file = fullfile(run_dir, sprintf( ...
        'sar_2bit_30_70_wide100_minus%ddB.png', dynamic_range_db));
    fig_file = fullfile(run_dir, sprintf( ...
        'sar_2bit_30_70_wide100_minus%ddB.fig', dynamic_range_db));
    exportgraphics(figure_wide, png_file, 'Resolution', 220);
    savefig(figure_wide, fig_file);
end

save(fullfile(run_dir, 'wide100_harmonic_synthesis.mat'), ...
    'wide_image', 'wide_axis', 'orders', 'coefficients', ...
    'view_half_width_m', 'template_half_width_m', 'source_mat', '-v7.3');
fprintf('±100 m宽场结果已保存至：\n%s\n', run_dir);

function coefficient = steppedPhaseFourierCoefficient( ...
    order, state_response, state_dwell_fraction)
    phase_edges = 2*pi * [0, cumsum(state_dwell_fraction)];
    if order == 0
        coefficient = sum(state_response .* state_dwell_fraction);
        return;
    end

    coefficient = 0;
    for state_index = 0:3
        phase_start = phase_edges(state_index+1);
        phase_end = phase_edges(state_index+2);
        slot_integral = (exp(-1j*order*phase_start) - ...
            exp(-1j*order*phase_end))/(1j*order);
        coefficient = coefficient + state_response(state_index+1) * ...
            slot_integral/(2*pi);
    end
end
