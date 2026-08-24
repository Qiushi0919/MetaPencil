%% 平衡2-bit SAR各阶谐波彩色散点图
% 不在灰度图上画框，而是将(+1,+1)、(-3,+1)、(+5,+1)、
% (+1,-3)、(+1,+5)五个独立SAR谐波分量的有效像素直接画成
% 不同颜色。输出单架真实飞机和四架真实飞机两种场景。
%
% 所有散点共用“未调制单机峰值=0 dB”的幅度参考；只有高于
% -30 dB的像素会显示，所以不同阶次的能量损失仍然保留。

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

fprintf('读取完整SAR复图像：\n%s\n', result_file);

display_half_width_m = 100;
dynamic_range_db = 30;
grid_spacing_m = loaded.grid_spacing_m;
reference_peak = loaded.single_aircraft_reference;
range_axis = loaded.Range_axis_ground;
azimuth_axis = loaded.Az_axis;

% 裁取中心单机模板。范围略大于歼-36散射点外形，以保留主瓣和
% 局部散斑，同时避免把远处的数值底噪重复平移到每个谐波位置。
template_range_half_width_m = 5.0;
template_azimuth_half_width_m = 5.0;
range_keep = abs(range_axis) <= template_range_half_width_m;
azimuth_keep = abs(azimuth_axis) <= template_azimuth_half_width_m;
template_complex = loaded.img_single_reference(azimuth_keep, range_keep);
template_range_axis = range_axis(range_keep);
template_azimuth_axis = azimuth_axis(azimuth_keep);
[template_range_grid, template_azimuth_grid] = meshgrid( ...
    template_range_axis, template_azimuth_axis);
template_db = 20*log10(abs(template_complex) + eps) - ...
    20*log10(reference_peak);

% 五组需要显示的二维谐波。前两列是(n_r,n_a)，color为其散点
% 基色；亮度仍由该像素的绝对dB值决定。
groups = struct( ...
    'order', {[1,1], [-3,1], [5,1], [1,-3], [1,5]}, ...
    'name', {'(1,1) 期望2×2假目标', ...
             '(-3,1) 距离负三阶十字副像', ...
             '(5,1) 距离正五阶十字副像', ...
             '(1,-3) 方位负三阶十字副像', ...
             '(1,5) 方位正五阶十字副像'}, ...
    'short_name', {'(1,1)', '(-3,1)', '(5,1)', '(1,-3)', '(1,5)'}, ...
    'color', {[0.10,0.95,0.25], ...  % 绿色：目标
              [1.00,0.18,0.12], ...  % 红色：距离-3
              [1.00,0.15,0.85], ...  % 品红：距离+5
              [0.05,0.72,1.00], ...  % 蓝色：方位-3
              [1.00,0.62,0.02]});    % 橙色：方位+5

% 从完整仿真保存的傅里叶系数中读取每一阶的复系数，避免在
% 绘图脚本里手填理论幅度。
for group_index = 1:numel(groups)
    nr = groups(group_index).order(1);
    na = groups(group_index).order(2);
    coefficient_range = loaded.harmonic_coefficients( ...
        loaded.harmonic_orders == nr);
    coefficient_azimuth = loaded.harmonic_coefficients( ...
        loaded.harmonic_orders == na);
    groups(group_index).coefficient = ...
        coefficient_range * coefficient_azimuth;
    groups(group_index).amplitude = ...
        abs(groups(group_index).coefficient);
    groups(group_index).amplitude_db = ...
        20*log10(groups(group_index).amplitude + eps);
end

fprintf('\n各彩色分量相对未调制单机的理论幅度：\n');
for group_index = 1:numel(groups)
    fprintf('%-8s  A = %.6f，%.2f dB\n', ...
        groups(group_index).short_name, ...
        groups(group_index).amplitude, ...
        groups(group_index).amplitude_db);
end

% 与原完整版一致的四个真实角点；单机选择右上角(12,12)。
four_real_positions = loaded.real_positions;
single_real_position = [12,12];

%% Figure 1：单架真实飞机产生的彩色谐波散点
figure_single = createColoredFigure( ...
    'Figure 1 - 单机各阶谐波彩色散点');
hold on;
single_counts = plotSceneHarmonicPoints(single_real_position, groups, ...
    grid_spacing_m, template_range_grid, template_azimuth_grid, ...
    template_db, dynamic_range_db, 7);
plot(single_real_position(1), single_real_position(2), 'x', ...
    'Color',[1.00,0.95,0.15], 'LineWidth',2.2, 'MarkerSize',11, ...
    'DisplayName','真实飞机位置(零阶已抑制)');

% 单机图标出每一团彩色散点对应的阶次，不加方框。
single_centers = harmonicCenters(single_real_position, groups, ...
    grid_spacing_m);
for group_index = 1:numel(groups)
    text(single_centers(group_index,1), ...
        single_centers(group_index,2)+6.2, ...
        groups(group_index).short_name, ...
        'Color',groups(group_index).color, ...
        'FontWeight','bold','FontSize',11, ...
        'HorizontalAlignment','center');
end
finishColoredAxes(display_half_width_m, groups, ...
    '单架真实飞机：目标谐波与高阶十字副像的彩色SAR散点', ...
    dynamic_range_db);
hold off;

%% Figure 2：四架真实飞机产生的彩色谐波散点
figure_four = createColoredFigure( ...
    'Figure 2 - 四机各阶谐波彩色散点');
hold on;
four_counts = plotSceneHarmonicPoints(four_real_positions, groups, ...
    grid_spacing_m, template_range_grid, template_azimuth_grid, ...
    template_db, dynamic_range_db, 5);
plot(four_real_positions(:,1), four_real_positions(:,2), 'x', ...
    'Color',[1.00,0.95,0.15], 'LineWidth',2.0, 'MarkerSize',10, ...
    'DisplayName','四架真实飞机位置(零阶已抑制)');
finishColoredAxes(display_half_width_m, groups, ...
    '四架真实飞机：中央2×2目标与外侧高阶谐波十字副像', ...
    dynamic_range_db);
hold off;

%% Figure 3：单机和四机并排对照，方便直接放入PPT
figure_compare = figure('Color','w', ...
    'Name','Figure 3 - 单机与四机彩色谐波对照', ...
    'NumberTitle','off','Position',[50,80,1500,700]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

nexttile;
hold on;
plotSceneHarmonicPoints(single_real_position, groups, ...
    grid_spacing_m, template_range_grid, template_azimuth_grid, ...
    template_db, dynamic_range_db, 5);
plot(single_real_position(1), single_real_position(2), 'x', ...
    'Color',[1.00,0.95,0.15], 'LineWidth',2, 'MarkerSize',9, ...
    'HandleVisibility','off');
finishColoredAxes(display_half_width_m, groups, ...
    '单机：一个主目标＋四组主要十字副像', ...
    dynamic_range_db, false);
hold off;

nexttile;
hold on;
plotSceneHarmonicPoints(four_real_positions, groups, ...
    grid_spacing_m, template_range_grid, template_azimuth_grid, ...
    template_db, dynamic_range_db, 4);
plot(four_real_positions(:,1), four_real_positions(:,2), 'x', ...
    'Color',[1.00,0.95,0.15], 'LineWidth',2, 'MarkerSize',9, ...
    'HandleVisibility','off');
finishColoredAxes(display_half_width_m, groups, ...
    '四机：中央2×2主目标＋外侧十字副像', ...
    dynamic_range_db, false);
hold off;
sgtitle({'平衡2-bit各阶谐波彩色SAR散点', ...
    '同一30 dB绝对门限；颜色表示阶次，点的明暗表示幅度'});

%% 保存
output_dir = fullfile(result_files(newest_index).folder, ...
    'harmonic_colored_scatter');
if ~exist(output_dir,'dir')
    mkdir(output_dir);
end

single_png = fullfile(output_dir, ...
    'single_aircraft_colored_harmonic_scatter.png');
four_png = fullfile(output_dir, ...
    'four_aircraft_colored_harmonic_scatter.png');
compare_png = fullfile(output_dir, ...
    'single_vs_four_colored_harmonic_scatter.png');

exportgraphics(figure_single, single_png, 'Resolution',240);
exportgraphics(figure_four, four_png, 'Resolution',240);
exportgraphics(figure_compare, compare_png, 'Resolution',240);
savefig(figure_single, strrep(single_png,'.png','.fig'));
savefig(figure_four, strrep(four_png,'.png','.fig'));
savefig(figure_compare, strrep(compare_png,'.png','.fig'));

order_matrix = vertcat(groups.order);
amplitude_vector = vertcat(groups.amplitude);
amplitude_db_vector = vertcat(groups.amplitude_db);
point_count_single = single_counts(:);
point_count_four = four_counts(:);
summary_table = table(order_matrix(:,1),order_matrix(:,2), ...
    amplitude_vector,amplitude_db_vector,point_count_single, ...
    point_count_four,'VariableNames',{'range_order_nr', ...
    'azimuth_order_na','amplitude','amplitude_db', ...
    'visible_points_single','visible_points_four'});
writetable(summary_table,fullfile(output_dir, ...
    'colored_harmonic_scatter_summary.csv'));

fprintf('\n彩色谐波散点结果已保存至：\n%s\n',output_dir);
fprintf('单机：%s\n',single_png);
fprintf('四机：%s\n',four_png);
fprintf('对照：%s\n',compare_png);

%% ====================== 局部函数 ======================
function counts = plotSceneHarmonicPoints(real_positions, groups, ...
    grid_spacing_m, template_range_grid, template_azimuth_grid, ...
    template_db, dynamic_range_db, marker_size)
% 把每一个阶次的实际SAR像素变成对应颜色的散点。为避免强分量
% 覆盖弱分量，先画较弱的五阶/三阶，最后画(+1,+1)主目标。
    [~,plot_order] = sort([groups.amplitude],'ascend');
    counts = zeros(numel(groups),1);
    for sorted_index = 1:numel(plot_order)
        group_index = plot_order(sorted_index);
        nr = groups(group_index).order(1);
        na = groups(group_index).order(2);
        absolute_db = template_db + groups(group_index).amplitude_db;
        visible = absolute_db >= -dynamic_range_db;
        if ~any(visible(:))
            continue;
        end

        local_x = template_range_grid(visible);
        local_y = template_azimuth_grid(visible);
        point_db = absolute_db(visible);
        brightness = 0.25 + 0.75*min(max( ...
            (point_db+dynamic_range_db)/dynamic_range_db,0),1);
        point_colors = brightness .* groups(group_index).color;

        for source_index = 1:size(real_positions,1)
            inward_step = -sign(real_positions(source_index,:)) * ...
                grid_spacing_m;
            center = real_positions(source_index,:) + ...
                inward_step.*[nr,na];
            scatter(center(1)+local_x, center(2)+local_y, ...
                marker_size, point_colors, 'filled', ...
                'Marker','o','HandleVisibility','off');
            counts(group_index) = counts(group_index) + numel(local_x);
        end
    end
end

function centers = harmonicCenters(real_position, groups, grid_spacing_m)
    inward_step = -sign(real_position) * grid_spacing_m;
    centers = zeros(numel(groups),2);
    for index = 1:numel(groups)
        centers(index,:) = real_position + ...
            inward_step.*groups(index).order;
    end
end

function fig = createColoredFigure(figure_name)
    fig = figure('Color','w','Name',figure_name,'NumberTitle','off', ...
        'Position',[80,50,1050,900]);
end

function finishColoredAxes(display_half_width_m,groups,title_text, ...
    dynamic_range_db,show_legend)
    if nargin < 5
        show_legend = true;
    end
    set(gca,'Color','k','XColor','k','YColor','k','FontSize',11);
    axis image;
    xlim([-display_half_width_m,display_half_width_m]);
    ylim([-display_half_width_m,display_half_width_m]);
    grid on;
    set(gca,'GridColor',[0.35,0.35,0.35],'GridAlpha',0.25);
    xlabel('相对地距向 (m)');
    ylabel('方位向 (m)');
    title({title_text,sprintf( ...
        '颜色=二维谐波阶次，显示门限=-%g dB',dynamic_range_db)});

    if show_legend
        for index = 1:numel(groups)
            scatter(nan,nan,28,groups(index).color,'filled', ...
                'DisplayName',groups(index).name);
        end
        legend('Location','southoutside','NumColumns',2, ...
            'Color','w','TextColor','k');
    end
end
