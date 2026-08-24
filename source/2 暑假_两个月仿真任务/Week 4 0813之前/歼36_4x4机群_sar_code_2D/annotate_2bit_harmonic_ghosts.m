%% 平衡2-bit完整SAR图：中央假目标与主要十字副像彩色标注
% 读取完整版±100 m、30 dB结果，不重新计算四机原始回波。
% Figure 1：四架真实飞机共同调制后的完整SAR图。
% Figure 2：只保留右上角一架真实飞机时，各阶复制像的对应关系。
%
% 颜色仅用于框线和文字，底层SAR图像仍保持原始灰度和幅度。

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
result_root = fullfile(script_dir, ...
    'results_4x4_2bit_balanced_wide100');
result_files = dir(fullfile(result_root, '*_uav', ...
    'sar_results_4x4_2bit_balanced_wide100.mat'));
if isempty(result_files)
    error(['找不到平衡2-bit完整版结果。请先运行 ' ...
        'SHIP_4x4_2bit_balanced_wide100.m。']);
end
[~, newest_index] = max([result_files.datenum]);
result_file = fullfile(result_files(newest_index).folder, ...
    result_files(newest_index).name);
loaded = load(result_file);

fprintf('读取完整版结果：\n%s\n', result_file);

range_axis = loaded.Range_axis_ground;
azimuth_axis = loaded.Az_axis;
reference_peak = loaded.single_aircraft_reference;
grid_spacing_m = loaded.grid_spacing_m;
display_half_width_m = 100;
dynamic_range_db = 30;

% 五组需要辨认的二维谐波。第一组是希望保留的目标，后四组
% 是外侧十字中最主要的量化杂散谐波副像。
groups = struct( ...
    'order', {[1,1], [-3,1], [5,1], [1,-3], [1,5]}, ...
    'label', {'(1,1) 中央目标', ...
              '(-3,1) 距离负三阶', ...
              '(5,1) 距离正五阶', ...
              '(1,-3) 方位负三阶', ...
              '(1,5) 方位正五阶'}, ...
    'color', {[0.10,0.85,0.25], ...       % 绿色：目标(+1,+1)
              [1.00,0.20,0.15], ...       % 红色：(-3,+1)
              [1.00,0.25,0.85], ...       % 品红：(5,+1)
              [0.10,0.75,1.00], ...       % 青色：(+1,-3)
              [1.00,0.65,0.05]});         % 橙色：(+1,5)
real_color = [1.00,0.92,0.15];             % 黄色：真实飞机位置

box_width_m = 7.0;
box_height_m = 7.0;

%% 1. 四架真实飞机：直接标注完整SAR仿真结果
real_positions = loaded.real_positions;
four_group_positions = cell(numel(groups),1);
for group_index = 1:numel(groups)
    nr = groups(group_index).order(1);
    na = groups(group_index).order(2);
    four_group_positions{group_index} = harmonicPositions( ...
        real_positions, nr, na, grid_spacing_m);
end

figure_four = createWideFigure('Figure 1 - 四机谐波副像标注');
plotSarDbLocal(loaded.img_deception_ssb_2bit, range_axis, ...
    azimuth_axis, dynamic_range_db, reference_peak, ...
    display_half_width_m);
hold on;
drawPositionBoxes(real_positions, real_color, box_width_m, ...
    box_height_m, '', '--', 1.2, false);
for group_index = 1:numel(groups)
    drawPositionBoxes(four_group_positions{group_index}, ...
        groups(group_index).color, box_width_m, box_height_m, ...
        '', '-', 1.8, false);
end
addGroupLegend(groups, real_color);
hold off;
title({'四架真实飞机：中央2×2目标与主要高阶谐波十字副像', ...
    '彩色方框仅为标注；底图保持原始30 dB灰度幅度'});

%% 2. 单架真实飞机：由同一完整单机SAR模板重建全部允许谐波
% 选择右上角物理飞机(12,12)。该飞机的距离/方位编码都向内
% 偏移8 m，所以任意二维谐波的中心为：
%   p(nr,na) = (12,12) + (-8*nr, -8*na)。
single_real_position = [12, 12];
single_inward_step = -sign(single_real_position) * grid_spacing_m;

single_harmonic_image = complex(zeros( ...
    size(loaded.img_single_reference), ...
    'like', loaded.img_single_reference));

% 使用完整版保存的理论系数；保留落在±100 m显示区内的全部
% 非零二维谐波，而不是只人为画五架飞机。
valid_indices = find(abs(loaded.harmonic_coefficients) > 1e-8);
range_sample_m = median(diff(range_axis));
azimuth_sample_m = median(diff(azimuth_axis));
for range_index = valid_indices(:).'
    nr = loaded.harmonic_orders(range_index);
    range_position_m = single_real_position(1) + ...
        nr*single_inward_step(1);
    if abs(range_position_m) > display_half_width_m + box_width_m
        continue;
    end

    for azimuth_index = valid_indices(:).'
        na = loaded.harmonic_orders(azimuth_index);
        azimuth_position_m = single_real_position(2) + ...
            na*single_inward_step(2);
        if abs(azimuth_position_m) > display_half_width_m + box_height_m
            continue;
        end

        coefficient_2d = loaded.harmonic_coefficients(range_index) * ...
            loaded.harmonic_coefficients(azimuth_index);
        row_shift = round(azimuth_position_m/azimuth_sample_m);
        column_shift = round(range_position_m/range_sample_m);
        shifted_template = translateNoWrap( ...
            loaded.img_single_reference, row_shift, column_shift);
        single_harmonic_image = single_harmonic_image + ...
            coefficient_2d*shifted_template;
    end
end

single_group_positions = cell(numel(groups),1);
for group_index = 1:numel(groups)
    order = groups(group_index).order;
    single_group_positions{group_index} = single_real_position + ...
        order.*single_inward_step;
end

figure_single = createWideFigure('Figure 2 - 单机谐波副像标注');
plotSarDbLocal(single_harmonic_image, range_axis, azimuth_axis, ...
    dynamic_range_db, reference_peak, display_half_width_m);
hold on;
drawPositionBoxes(single_real_position, real_color, box_width_m, ...
    box_height_m, '真实飞机(零阶已抑制)', '--', 1.4, true);
for group_index = 1:numel(groups)
    order = groups(group_index).order;
    label = sprintf('(%+d,%+d)', order(1), order(2));
    drawPositionBoxes(single_group_positions{group_index}, ...
        groups(group_index).color, box_width_m, box_height_m, ...
        label, '-', 2.2, true);
end

% 画出由真实飞机到五个标注中心的细虚线，帮助辨认谐波平移。
for group_index = 1:numel(groups)
    destination = single_group_positions{group_index};
    plot([single_real_position(1), destination(1)], ...
        [single_real_position(2), destination(2)], ':', ...
        'Color', groups(group_index).color, 'LineWidth', 0.9, ...
        'HandleVisibility','off');
end
addGroupLegend(groups, real_color);
hold off;
title({'单架真实飞机(12,12)：一个目标谐波与四组主要十字副像', ...
    '真实飞机位置没有亮像，是因为平衡编码将零阶理论抑制'});

%% 3. 保存PNG、FIG和位置表
output_dir = fullfile(result_files(newest_index).folder, ...
    'harmonic_ghost_annotations');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

four_png = fullfile(output_dir, ...
    'annotated_four_aircraft_target_and_cross_ghosts.png');
four_fig = fullfile(output_dir, ...
    'annotated_four_aircraft_target_and_cross_ghosts.fig');
single_png = fullfile(output_dir, ...
    'annotated_single_aircraft_target_and_cross_ghosts.png');
single_fig = fullfile(output_dir, ...
    'annotated_single_aircraft_target_and_cross_ghosts.fig');

exportgraphics(figure_four, four_png, 'Resolution', 240);
exportgraphics(figure_single, single_png, 'Resolution', 240);
savefig(figure_four, four_fig);
savefig(figure_single, single_fig);

position_rows = {};
for group_index = 1:numel(groups)
    four_positions = four_group_positions{group_index};
    for source_index = 1:size(real_positions,1)
        position_rows(end+1,:) = { ... %#ok<AGROW>
            'four_aircraft', source_index, ...
            real_positions(source_index,1), ...
            real_positions(source_index,2), ...
            groups(group_index).order(1), ...
            groups(group_index).order(2), ...
            four_positions(source_index,1), ...
            four_positions(source_index,2), ...
            groups(group_index).label};
    end
    position_rows(end+1,:) = { ... %#ok<AGROW>
        'single_aircraft', 1, single_real_position(1), ...
        single_real_position(2), groups(group_index).order(1), ...
        groups(group_index).order(2), ...
        single_group_positions{group_index}(1), ...
        single_group_positions{group_index}(2), ...
        groups(group_index).label};
end

position_table = cell2table(position_rows, 'VariableNames', { ...
    'scene','source_id','source_range_m','source_azimuth_m', ...
    'range_order_nr','azimuth_order_na','image_range_m', ...
    'image_azimuth_m','meaning'});
writetable(position_table, fullfile(output_dir, ...
    'annotated_harmonic_positions.csv'));

fprintf('\n标注结果已保存至：\n%s\n', output_dir);
fprintf('四机图：%s\n', four_png);
fprintf('单机图：%s\n', single_png);

%% ====================== 局部函数 ======================
function positions = harmonicPositions( ...
    real_positions, nr, na, grid_spacing_m)
% 每架角点飞机的编码基频都指向阵列内部。
    inward_step = -sign(real_positions) * grid_spacing_m;
    positions = real_positions + inward_step.*[nr,na];
end

function shifted = translateNoWrap(input_matrix, row_shift, column_shift)
% 整像素平移，不使用circshift，超出数组的部分补零而不回卷。
    [number_rows, number_columns] = size(input_matrix);
    shifted = complex(zeros(size(input_matrix), 'like', input_matrix));

    destination_row_start = max(1, 1 + row_shift);
    destination_row_end = min(number_rows, number_rows + row_shift);
    destination_column_start = max(1, 1 + column_shift);
    destination_column_end = min(number_columns, ...
        number_columns + column_shift);

    if destination_row_start > destination_row_end || ...
            destination_column_start > destination_column_end
        return;
    end

    source_row_start = destination_row_start - row_shift;
    source_row_end = destination_row_end - row_shift;
    source_column_start = destination_column_start - column_shift;
    source_column_end = destination_column_end - column_shift;

    shifted(destination_row_start:destination_row_end, ...
        destination_column_start:destination_column_end) = ...
        input_matrix(source_row_start:source_row_end, ...
        source_column_start:source_column_end);
end

function drawPositionBoxes(positions, color_value, width_m, height_m, ...
    label_text, line_style, line_width, show_text)
    for index = 1:size(positions,1)
        center_x = positions(index,1);
        center_y = positions(index,2);
        rectangle('Position', [center_x-width_m/2, ...
            center_y-height_m/2, width_m, height_m], ...
            'EdgeColor', color_value, 'LineStyle', line_style, ...
            'LineWidth', line_width, 'HandleVisibility','off');
        plot(center_x, center_y, '+', 'Color', color_value, ...
            'LineWidth', line_width, 'MarkerSize', 7, ...
            'HandleVisibility','off');
        if show_text && ~isempty(label_text)
            text(center_x, center_y+height_m/2+1.0, label_text, ...
                'Color', color_value, 'FontWeight','bold', ...
                'FontSize', 8, 'HorizontalAlignment','center', ...
                'VerticalAlignment','bottom', ...
                'Clipping','on', 'Interpreter','none');
        end
    end
end

function addGroupLegend(groups, real_color)
% 用不可见NaN线段生成独立于矩形对象的清晰图例。
    plot(nan,nan,'--s','Color',real_color,'LineWidth',1.4, ...
        'DisplayName','真实飞机位置（零阶理论抑制）');
    for index = 1:numel(groups)
        plot(nan,nan,'-s','Color',groups(index).color, ...
            'LineWidth',2.0,'DisplayName',groups(index).label);
    end
    legend('Location','southoutside','NumColumns',3, ...
        'Color','w','TextColor','k');
end

function fig = createWideFigure(figure_name)
    fig = figure('Color','w','Name',figure_name,'NumberTitle','off', ...
        'Position',[80,60,1040,860]);
end

function plotSarDbLocal(img, range_axis, azimuth_axis, ...
    dynamic_range_db, reference_peak, display_half_width_m)
    image_db = 20*log10(abs(img) + eps) - ...
        20*log10(reference_peak);
    imagesc(range_axis, azimuth_axis, image_db, ...
        [-dynamic_range_db,0]);
    set(gca,'YDir','normal','Color','k');
    axis image;
    xlim([-display_half_width_m,display_half_width_m]);
    ylim([-display_half_width_m,display_half_width_m]);
    colormap gray;
    colorbar;
    xlabel('相对地距向 (m)');
    ylabel('方位向 (m)');
end
