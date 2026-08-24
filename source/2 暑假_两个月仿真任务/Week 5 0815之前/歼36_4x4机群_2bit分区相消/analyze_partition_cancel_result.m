%% 按理论二维谐波坐标统计SAR局部峰值
clear; clc;

script_dir = fileparts(mfilename('fullpath'));
result_root = fullfile(script_dir, ...
    'results_4x4_2bit_partition_cancel_wide100');
run_folders = dir(fullfile(result_root, '*_uav'));
run_folders = run_folders([run_folders.isdir]);
if isempty(run_folders)
    error('没有找到已完成的UAV分辨率结果。');
end
[~, newest_index] = max([run_folders.datenum]);
run_dir = fullfile(result_root, run_folders(newest_index).name);
mat_files = dir(fullfile(run_dir, 'sar_results_4x4_*.mat'));
if numel(mat_files) ~= 1
    error('结果目录中的MAT文件数量不是1：%s', run_dir);
end

loaded = load(fullfile(run_dir, mat_files(1).name), ...
    'img_deception_ssb_2bit', 'single_aircraft_reference', ...
    'Range_axis_ground', 'Az_axis', 'real_positions', 'grid_spacing_m');

image_db = 20*log10(abs(loaded.img_deception_ssb_2bit)+eps) - ...
    20*log10(loaded.single_aircraft_reference);
selected_pairs = [ ...
     1,   1; ...
    -3,   1; ...
     5,   1; ...
     1,  -3; ...
     1,   5; ...
    -7,   1; ...
     1,  -7; ...
   -11,   1; ...
     1, -11; ...
    13,   1; ...
     1,  13];

number_pairs = size(selected_pairs,1);
number_sources = size(loaded.real_positions,1);
row_count = number_pairs*number_sources;
range_order = zeros(row_count,1);
azimuth_order = zeros(row_count,1);
source_id = zeros(row_count,1);
center_range_m = zeros(row_count,1);
center_azimuth_m = zeros(row_count,1);
roi_peak_db = nan(row_count,1);

roi_half_width_m = 3.5;
row = 0;
for pair_index = 1:number_pairs
    nr = selected_pairs(pair_index,1);
    na = selected_pairs(pair_index,2);
    for source_index = 1:number_sources
        row = row+1;
        source_range = loaded.real_positions(source_index,1);
        source_azimuth = loaded.real_positions(source_index,2);
        inward_range = -sign(source_range)*loaded.grid_spacing_m;
        inward_azimuth = -sign(source_azimuth)*loaded.grid_spacing_m;
        predicted_range = source_range + nr*inward_range;
        predicted_azimuth = source_azimuth + na*inward_azimuth;

        range_mask = abs(loaded.Range_axis_ground-predicted_range) <= ...
            roi_half_width_m;
        azimuth_mask = abs(loaded.Az_axis-predicted_azimuth) <= ...
            roi_half_width_m;

        range_order(row) = nr;
        azimuth_order(row) = na;
        source_id(row) = source_index;
        center_range_m(row) = predicted_range;
        center_azimuth_m(row) = predicted_azimuth;
        if any(range_mask) && any(azimuth_mask)
            roi_data = image_db(azimuth_mask, range_mask);
            roi_peak_db(row) = max(roi_data(:));
        end
    end
end

detail_table = table(range_order, azimuth_order, source_id, ...
    center_range_m, center_azimuth_m, roi_peak_db);
writetable(detail_table, fullfile(run_dir, 'harmonic_roi_peak_detail.csv'));

pair_peak_db = zeros(number_pairs,1);
pair_mean_peak_db = zeros(number_pairs,1);
for pair_index = 1:number_pairs
    nr = selected_pairs(pair_index,1);
    na = selected_pairs(pair_index,2);
    selected = range_order == nr & azimuth_order == na;
    pair_peak_db(pair_index) = max(roi_peak_db(selected), [], 'omitnan');
    pair_mean_peak_db(pair_index) = mean(roi_peak_db(selected), 'omitnan');
end
summary_table = table(selected_pairs(:,1), selected_pairs(:,2), ...
    pair_peak_db, pair_mean_peak_db, ...
    'VariableNames', {'range_order','azimuth_order', ...
    'maximum_roi_peak_db','mean_roi_peak_db'});
writetable(summary_table, fullfile(run_dir, 'harmonic_roi_peak_summary.csv'));

disp(summary_table);
fprintf('统计结果已保存至：%s\n', run_dir);
