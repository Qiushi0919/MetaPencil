%% 时变2-bit超表面SAR假目标：自由度与物理控制超单元系统级仿真
% 本脚本分为两层：
%   1) 读取完整原始回波/RD成像得到的单架歼-36复图像，作为统一模板；
%   2) 利用SAR线性系统的平移叠加性质，快速扫描1->N、2机线目标和4机二维目标。
% 物理超单元部分显式比较4×4、5×5、7×7整数控制分区。
%
% 注意：1->N多目标图表示“多波形通道/空间分区”系统级能力。每个通道都必须由
% 一组实际2-bit单元承担，不能把K个目标理解为单个PIN管凭空复制K份能量。

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
output_dir = fullfile(script_dir, 'results_freedom_study');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

source_mat = fullfile(script_dir, '..', ...
    '歼36_4x4机群_2bit_4x4目标群_谐波相消', ...
    'results_4x4_target_group_partition_cancel_wide100', ...
    '20260815_202454_uav', ...
    'sar_results_4x4_2bit_4x4_target_group_partition_cancel_wide100.mat');
if ~isfile(source_mat)
    error('找不到完整RD单机模板：%s', source_mat);
end

S = load(source_mat, 'img_single_reference', 'Range_axis_ground', ...
    'Az_axis', 'single_aircraft_reference');
[template_amplitude, template_x_m, template_y_m] = ...
    extractAircraftTemplate(S.img_single_reference, ...
    S.Range_axis_ground, S.Az_axis, S.single_aircraft_reference);

set(groot, 'defaultAxesFontName', 'PingFang SC');
set(groot, 'defaultTextFontName', 'PingFang SC');
set(groot, 'defaultAxesFontSize', 12);

grid_spacing_m = 8;
scene_half_width_m = 28;
scene_step_m = 0.12;
scene_axis_m = -scene_half_width_m:scene_step_m:scene_half_width_m;
display_floor_db = -30;

delay_fraction = [0, 1/10, 5/6, 14/15];
base_plus1 = 2*sqrt(2)/pi;
partition_plus1 = abs(mean(exp(-1j*2*pi*delay_fraction)));
eta_1d = base_plus1*partition_plus1;
eta_2d = eta_1d^2;

fprintf('平衡2-bit：|C+1|=%.6f\n', base_plus1);
fprintf('四分区相消：|S+1|=%.6f\n', partition_plus1);
fprintf('一个二维调制通道：|A(+1,+1)|=%.6f (%.2f dB)\n', ...
    eta_2d, 20*log10(eta_2d));

%% 1. 单架飞机：1->1/2/3/4/5/9/16
single_cases = {
    '1to1', [1,1], '1→1：单个指定假目标';
    '1to2', [-1,1; 1,1], '1→2：两个独立位置';
    '1to3', [-1,1; 0,1; 1,1], '1→3：三点线目标';
    '1to4', [-1,-1; 1,-1; -1,1; 1,1], '1→4：2×2二维目标';
    '1to5', [0,0; -1,0; 1,0; 0,-1; 0,1], '1→5：十字/五点目标';
    '1to9', makeCartesianOrders(-1:1, -1:1), '1→9：3×3二维目标';
    '1to16', makeCartesianOrders(-1.5:1:1.5, -1.5:1:1.5), ...
    '1→16：4×4二维目标'};

single_summary = table('Size',[size(single_cases,1),5], ...
    'VariableTypes',{'string','double','double','double','double'}, ...
    'VariableNames',{'case_name','target_count','amplitude_each', ...
    'amplitude_each_db','power_sum_fraction'});

for case_index = 1:size(single_cases,1)
    case_tag = single_cases{case_index,1};
    order_pairs = single_cases{case_index,2};
    case_title = single_cases{case_index,3};
    target_positions = order_pairs*grid_spacing_m;
    target_count = size(target_positions,1);
    target_amplitude = eta_2d/target_count;
    target_weights = target_amplitude*ones(target_count,1);
    source_positions = [0,0];

    scene_amplitude = synthesizeTemplateScene(template_amplitude, ...
        template_x_m, template_y_m, scene_axis_m, scene_axis_m, ...
        target_positions, target_weights);

    fig = createWideFigure();
    tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
    nexttile;
    plotChannelMap(order_pairs, target_count);
    title(sprintf('%s的通道分配', case_title));
    nexttile;
    plotSarScene(scene_amplitude, scene_axis_m, scene_axis_m, ...
        display_floor_db, source_positions, target_positions);
    title(sprintf('%s｜每个目标 %.3f（%.1f dB）', ...
        case_title, target_amplitude, 20*log10(target_amplitude)));
    sgtitle('单架真实飞机通过多通道2-bit时空编码生成可编程假目标');
    exportgraphics(fig, fullfile(output_dir, ...
        sprintf('single_%s_pair.png', case_tag)), 'Resolution', 200);
    close(fig);

    fig = createWideFigure();
    plotSarScene(scene_amplitude, scene_axis_m, scene_axis_m, ...
        display_floor_db, source_positions, target_positions);
    title(sprintf('%s｜每个目标 %.3f（%.1f dB）｜浅蓝框=真实飞机', ...
        case_title, target_amplitude, 20*log10(target_amplitude)));
    exportgraphics(fig, fullfile(output_dir, ...
        sprintf('single_%s_sar.png', case_tag)), 'Resolution', 200);
    close(fig);

    single_summary.case_name(case_index) = string(case_tag);
    single_summary.target_count(case_index) = target_count;
    single_summary.amplitude_each(case_index) = target_amplitude;
    single_summary.amplitude_each_db(case_index) = ...
        20*log10(target_amplitude);
    single_summary.power_sum_fraction(case_index) = ...
        target_count*target_amplitude^2;
end
writetable(single_summary, fullfile(output_dir, 'single_1toN_budget.csv'));

fig = createWideFigure();
tiledlayout(fig, 2, 4, 'TileSpacing','compact', 'Padding','compact');
for case_index = 1:size(single_cases,1)
    order_pairs = single_cases{case_index,2};
    target_positions = order_pairs*grid_spacing_m;
    target_count = size(target_positions,1);
    target_amplitude = eta_2d/target_count;
    scene_amplitude = synthesizeTemplateScene(template_amplitude, ...
        template_x_m, template_y_m, scene_axis_m, scene_axis_m, ...
        target_positions, target_amplitude*ones(target_count,1));
    nexttile;
    plotSarScene(scene_amplitude, scene_axis_m, scene_axis_m, ...
        display_floor_db, [0,0], target_positions);
    title(sprintf('%s｜单目标 %.1f dB', ...
        single_cases{case_index,3}, 20*log10(target_amplitude)));
end
sgtitle('单架歼-36的1→N假目标自由度（浅蓝框=真实飞机位置）');
exportgraphics(fig, fullfile(output_dir, 'single_1toN_overview.png'), ...
    'Resolution', 220);
close(fig);

%% 2. 两架飞机：共享编码、重叠增强、独立编码
source_two = [-4,0; 4,0];
kernel_two = [-1,1; 1,1];
kernel_three = [-1,1; 0,1; 1,1];

fig = createWideFigure();
tiledlayout(fig, 1, 3, 'TileSpacing','compact', 'Padding','compact');

% 共享2目标核：2×2=4个像
positions_a = minkowskiPositions(source_two, kernel_two*grid_spacing_m);
weights_a = (eta_2d/2)*ones(size(positions_a,1),1);
scene_a = synthesizeTemplateScene(template_amplitude, template_x_m, ...
    template_y_m, scene_axis_m, scene_axis_m, positions_a, weights_a);
nexttile;
plotSarScene(scene_a, scene_axis_m, scene_axis_m, display_floor_db, ...
    source_two, positions_a);
title('共享2通道核：2架→4个像');

% 共享3目标核：位置重叠，中心像相干增强
[positions_b, weights_b] = accumulateCoincidentTargets(source_two, ...
    kernel_three*grid_spacing_m, eta_2d/3);
scene_b = synthesizeTemplateScene(template_amplitude, template_x_m, ...
    template_y_m, scene_axis_m, scene_axis_m, positions_b, weights_b);
nexttile;
plotSarScene(scene_b, scene_axis_m, scene_axis_m, display_floor_db, ...
    source_two, positions_b);
title('共享3通道核：重叠位置相干增强');

% 独立编码：两架飞机分别拥有不同的通道集合
offsets_1 = [-1,1; 0,1; 1,1]*grid_spacing_m;
offsets_2 = [-1,-1; 0,-1; 1,-1]*grid_spacing_m;
positions_c = [source_two(1,:)+offsets_1; source_two(2,:)+offsets_2];
weights_c = (eta_2d/3)*ones(size(positions_c,1),1);
scene_c = synthesizeTemplateScene(template_amplitude, template_x_m, ...
    template_y_m, scene_axis_m, scene_axis_m, positions_c, weights_c);
nexttile;
plotSarScene(scene_c, scene_axis_m, scene_axis_m, display_floor_db, ...
    source_two, positions_c);
title('独立控制：两套核可生成非对称编队');

sgtitle('两架真实飞机（线目标）的自由度：平移卷积 + 重叠相干 + 独立码本');
exportgraphics(fig, fullfile(output_dir, 'two_aircraft_line_freedom.png'), ...
    'Resolution', 220);
close(fig);

%% 3. 四角四架飞机：7×7整数面积形成4×4目标群
source_four = [-12,-12; 12,-12; -12,12; 12,12];
kernel_four = [0,0; grid_spacing_m,0; 0,grid_spacing_m; ...
    grid_spacing_m,grid_spacing_m];
target_four = minkowskiPositions(source_four, kernel_four);

w0_7 = 3/7;
w1_7 = 4/7;
h0_7 = w0_7;
h1_7 = w1_7*eta_1d;
kernel_weights_7 = [h0_7*h0_7; h1_7*h0_7; ...
    h0_7*h1_7; h1_7*h1_7];
weights_four = repmat(kernel_weights_7, size(source_four,1), 1);
scene_four = synthesizeTemplateScene(template_amplitude, template_x_m, ...
    template_y_m, scene_axis_m, scene_axis_m, target_four, weights_four);

fig = createWideFigure();
tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
nexttile;
plotPhysicalSupercell(7, delay_fraction);
title('7×7整数控制超单元：3个DC组 + 4个时延组/维');
nexttile;
plotSarScene(scene_four, scene_axis_m, scene_axis_m, display_floor_db, ...
    source_four, target_four);
title(sprintf('四角4架→4×4共16架｜幅度差仅 %.2f dB', ...
    20*log10(max(kernel_weights_7)/min(kernel_weights_7))));
sgtitle('可投版构型：7×7局部控制超单元重复铺设于四架飞机表面');
exportgraphics(fig, fullfile(output_dir, ...
    'four_aircraft_7x7_to16_pair.png'), 'Resolution', 220);
close(fig);

%% 4. 4×4、5×5、7×7物理超单元及量化误差
array_sizes = [4,5,7];
array_summary = table('Size',[3,9], ...
    'VariableTypes',repmat({'double'},1,9), ...
    'VariableNames',{'N','dc_count_1d','mod_count_1d','H0','H1', ...
    'A00','A01','A11','max_imbalance_db'});

for index = 1:numel(array_sizes)
    N = array_sizes(index);
    if N == 4
        dc_count = 0;
    elseif N == 5
        dc_count = 1;
    else
        dc_count = 3;
    end
    mod_count = N-dc_count;
    h0 = dc_count/N;
    h1 = (mod_count/N)*eta_1d;
    A = [h0*h0, h0*h1; h1*h0, h1*h1];
    positive_A = A(A>0);
    if isempty(positive_A)
        imbalance_db = NaN;
    else
        imbalance_db = 20*log10(max(positive_A)/min(positive_A));
    end
    array_summary{index,:} = [N,dc_count,mod_count,h0,h1, ...
        A(1,1),A(1,2),A(2,2),imbalance_db];

    fig = createWideFigure();
    tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
    nexttile;
    plotPhysicalSupercell(N, delay_fraction);
    title(sprintf('%d×%d最小控制超单元', N, N));
    nexttile;
    plotArrayKernelBars(N, h0, h1, A);
    sgtitle(sprintf('%d×%d整数分区的目标核与幅度预算',N,N));
    exportgraphics(fig, fullfile(output_dir, ...
        sprintf('physical_supercell_%dx%d.png',N,N)), 'Resolution', 220);
    close(fig);

    fig = createWideFigure();
    plotPhysicalSupercell(N, delay_fraction);
    title(sprintf('%d×%d最小控制超单元：每格标注距离/方位控制时延',N,N));
    exportgraphics(fig, fullfile(output_dir, ...
        sprintf('physical_array_only_%dx%d.png',N,N)), 'Resolution', 220);
    close(fig);

    kernel_positions = [0,0; grid_spacing_m,0; 0,grid_spacing_m; ...
        grid_spacing_m,grid_spacing_m];
    kernel_values = [A(1,1);A(2,1);A(1,2);A(2,2)];
    active = kernel_values>1e-12;
    kernel_scene = synthesizeTemplateScene(template_amplitude, ...
        template_x_m, template_y_m, scene_axis_m, scene_axis_m, ...
        kernel_positions(active,:), kernel_values(active));
    fig = createWideFigure();
    tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
    nexttile;
    plotPhysicalSupercell(N,delay_fraction);
    title(sprintf('%d×%d：每格继承行d_r和列d_a',N,N));
    nexttile;
    plotSarScene(kernel_scene,scene_axis_m,scene_axis_m, ...
        display_floor_db,[0,0],kernel_positions(active,:));
    title(sprintf('单机目标核：A_{00}=%.3f，A_{01}=%.3f，A_{11}=%.3f', ...
        A(1,1),A(1,2),A(2,2)));
    sgtitle(sprintf('%d×%d整数控制超单元：物理分区与SAR结果一一对应',N,N));
    exportgraphics(fig,fullfile(output_dir, ...
        sprintf('physical_%dx%d_system_pair.png',N,N)), ...
        'Resolution',220);
    close(fig);
end
writetable(array_summary, fullfile(output_dir, ...
    'physical_array_comparison.csv'));

fig = createWideFigure();
tiledlayout(fig, 1, 3, 'TileSpacing','compact', 'Padding','compact');
for index = 1:numel(array_sizes)
    nexttile;
    plotPhysicalSupercell(array_sizes(index), delay_fraction);
    title(sprintf('%d×%d',array_sizes(index),array_sizes(index)));
end
sgtitle('三种可布线整数控制超单元：每格为一组独立偏置总线，不是单个PIN管');
exportgraphics(fig, fullfile(output_dir, 'physical_supercells_compare.png'), ...
    'Resolution', 220);
close(fig);

%% 5. 谐波抑制与自由度总表
orders = (-15:15).';
base_coeff = arrayfun(@twoBitCoefficient, orders);
partition_factor = arrayfun(@(n) mean(exp(-1j*2*pi*n*delay_fraction)), orders);
partition_coeff = base_coeff.*partition_factor;

fig = createWideFigure();
tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
nexttile;
stem(orders, 20*log10(abs(base_coeff)+eps), 'filled', ...
    'Color',[0.15 0.43 0.75], 'LineWidth',1.3);
grid on; ylim([-50,2]); xlim([-15.5,15.5]);
xlabel('谐波阶次 n'); ylabel('幅度/dB');
title('整面同步平衡2-bit：-3、+5等量化副谐波存在');
nexttile;
stem(orders, 20*log10(abs(partition_coeff)+eps), 'filled', ...
    'Color',[0.06 0.61 0.45], 'LineWidth',1.3);
grid on; ylim([-50,2]); xlim([-15.5,15.5]);
xlabel('谐波阶次 n'); ylabel('幅度/dB');
title('四时延分区：-3、+5、+9被相干零陷');
sgtitle('同样是2-bit硬件，空间分区相干叠加决定十字副像是否保留');
exportgraphics(fig, fullfile(output_dir, 'harmonic_suppression_compare.png'), ...
    'Resolution', 220);
close(fig);

freedom_table = table( ...
    [1;1;1;1;1;1;2;4], ...
    [1;2;3;4;5;9;6;16], ...
    [1;2;3;4;5;9;3;4], ...
    [1;1;1;1;1;1;2;4], ...
    [eta_2d;eta_2d/2;eta_2d/3;eta_2d/4;eta_2d/5;eta_2d/9;eta_2d/3;min(kernel_weights_7)], ...
    'VariableNames',{'real_aircraft','visible_targets','waveform_channels', ...
    'independent_controllers','minimum_target_amplitude'});
writetable(freedom_table, fullfile(output_dir, 'freedom_summary.csv'));

save(fullfile(output_dir, 'freedom_study_results.mat'), ...
    'single_summary','array_summary','freedom_table','delay_fraction', ...
    'eta_1d','eta_2d','base_coeff','partition_factor','partition_coeff', ...
    'orders','-v7.3');

fprintf('\n全部自由度图、CSV和MAT结果已保存到：\n%s\n', output_dir);

%% ======================= 局部函数 =======================
function pairs = makeCartesianOrders(range_orders, az_orders)
    [R,A] = meshgrid(range_orders, az_orders);
    pairs = [R(:), A(:)];
end

function [amp_roi,x_roi,y_roi] = extractAircraftTemplate(img,x,y,reference)
    amp = abs(img)/reference;
    if any(diff(x)<0)
        [x,ix] = sort(x);
        amp = amp(:,ix);
    end
    if any(diff(y)<0)
        [y,iy] = sort(y);
        amp = amp(iy,:);
    end
    x_mask = abs(x)<=4.5;
    y_mask = abs(y)<=4.2;
    x_roi = x(x_mask);
    y_roi = y(y_mask);
    amp_roi = amp(y_mask,x_mask);
    amp_roi(amp_roi < 10^(-35/20)) = 0;
end

function scene = synthesizeTemplateScene(template,x_template,y_template, ...
        x_scene,y_scene,target_positions,target_weights)
    [X,Y] = meshgrid(x_scene,y_scene);
    scene = zeros(size(X));
    for index = 1:size(target_positions,1)
        shifted = interp2(x_template,y_template,template, ...
            X-target_positions(index,1),Y-target_positions(index,2), ...
            'linear',0);
        scene = scene + target_weights(index)*shifted;
    end
end

function positions = minkowskiPositions(sources,offsets)
    positions = zeros(size(sources,1)*size(offsets,1),2);
    cursor = 0;
    for source_index = 1:size(sources,1)
        for offset_index = 1:size(offsets,1)
            cursor = cursor+1;
            positions(cursor,:) = sources(source_index,:)+offsets(offset_index,:);
        end
    end
end

function [positions,weights] = accumulateCoincidentTargets(sources,offsets,w)
    raw = minkowskiPositions(sources,offsets);
    rounded = round(raw,6);
    [positions,~,group_index] = unique(rounded,'rows','stable');
    weights = accumarray(group_index,w*ones(size(raw,1),1));
end

function plotSarScene(scene,x_axis,y_axis,floor_db,source_positions,target_positions)
    db = 20*log10(scene+eps);
    imagesc(x_axis,y_axis,db,[floor_db,0]);
    set(gca,'YDir','normal','Color','k');
    axis image; grid on; box on;
    colormap(gca,gray(256));
    xlabel('相对地距向/m'); ylabel('方位向/m');
    hold on;
    for index = 1:size(source_positions,1)
        x0 = source_positions(index,1);
        y0 = source_positions(index,2);
        patch(x0+[-3.2,3.2,3.2,-3.2], y0+[-3,-3,3,3], ...
            [0.45,0.80,1.00], 'FaceAlpha',0.10, ...
            'EdgeColor',[0.45,0.85,1.00], 'LineWidth',1.5);
    end
    scatter(target_positions(:,1),target_positions(:,2),20, ...
        [1.0,0.75,0.18],'o','LineWidth',0.8);
    hold off;
    cb = colorbar; cb.Label.String = '相对未调制单机/dB';
end

function plotChannelMap(order_pairs,target_count)
    colors = lines(max(target_count,2));
    hold on;
    for k = 1:target_count
        scatter(order_pairs(k,1),order_pairs(k,2),180,colors(k,:), ...
            'filled','MarkerEdgeColor','w','LineWidth',1.0);
        text(order_pairs(k,1),order_pairs(k,2),sprintf('  H_%d',k), ...
            'FontWeight','bold','VerticalAlignment','bottom');
    end
    scatter(0,0,130,[0.45 0.80 1.00],'s','LineWidth',2.0);
    hold off;
    axis equal; grid on; box on;
    pad = 0.7;
    xlim([min([-1;order_pairs(:,1)])-pad,max([1;order_pairs(:,1)])+pad]);
    ylim([min([-1;order_pairs(:,2)])-pad,max([1;order_pairs(:,2)])+pad]);
    xticks(-4:4); yticks(-4:4);
    xlabel('距离谐波阶次 n_r'); ylabel('方位谐波阶次 n_a');
    text(0,0,'  原机','Color',[0.15 0.45 0.65], ...
        'VerticalAlignment','top','FontWeight','bold');
end

function plotPhysicalSupercell(N,d)
    if N==4
        groups = {'d_1','d_2','d_3','d_4'};
    elseif N==5
        groups = {'DC','d_1','d_2','d_3','d_4'};
    elseif N==7
        groups = {'DC','DC','DC','d_1','d_2','d_3','d_4'};
    else
        error('仅实现4×4、5×5、7×7。');
    end
    palette = [0.85 0.90 0.96; 0.45 0.68 0.88; 0.97 0.72 0.45; ...
        0.55 0.80 0.61; 0.74 0.61 0.88];
    hold on;
    for row = 1:N
        for col = 1:N
            row_group = groups{row};
            col_group = groups{col};
            if strcmp(row_group,'DC') && strcmp(col_group,'DC')
                color = palette(1,:);
                order_label = '(0,0)';
            elseif strcmp(row_group,'DC')
                color = palette(2,:);
                order_label = '(0,+1)';
            elseif strcmp(col_group,'DC')
                color = palette(3,:);
                order_label = '(+1,0)';
            else
                color = palette(4,:);
                order_label = '(+1,+1)';
            end
            rectangle('Position',[col-1,N-row,1,1], ...
                'FaceColor',color,'EdgeColor',[0.25 0.28 0.32], ...
                'LineWidth',0.8);
            if N<=5
                text(col-0.5,N-row+0.60,order_label, ...
                    'HorizontalAlignment','center','FontSize',8, ...
                    'FontWeight','bold');
                text(col-0.5,N-row+0.28, ...
                    sprintf('%s/%s',row_group,col_group), ...
                    'HorizontalAlignment','center','FontSize',7);
            else
                text(col-0.5,N-row+0.54,sprintf('%s\n%s',row_group,col_group), ...
                    'HorizontalAlignment','center','FontSize',6.5);
            end
        end
    end
    axis equal; axis([0 N 0 N]); box on;
    xticks(0.5:1:N-0.5); xticklabels(groups);
    yticks(0.5:1:N-0.5); yticklabels(fliplr(groups));
    xlabel('方位控制组 d_a'); ylabel('距离控制组 d_r');
    subtitle(sprintf('d=[0, 1/10, 5/6, 14/15]T；每格继承行/列时延'));
    hold off;
end

function plotArrayKernelBars(N,h0,h1,A)
    categories = categorical({'(0,0)','(+1,0)','(0,+1)','(+1,+1)'});
    values = [A(1,1),A(2,1),A(1,2),A(2,2)];
    bar(categories,values,0.65,'FaceColor',[0.12 0.48 0.78]);
    grid on; ylim([0,max([0.4,1.2*max(values)])]);
    ylabel('相对未调制单机幅度');
    title(sprintf('|H_0|=%.3f，|H_{+1}|=%.3f',h0,h1));
    for k=1:numel(values)
        text(k,values(k)+0.015,sprintf('%.3f',values(k)), ...
            'HorizontalAlignment','center','FontWeight','bold');
    end
    if N==4
        subtitle('没有DC组：只保留(+1,+1)，适合1→1');
    elseif N==5
        subtitle('1个DC+4个调制组：四目标幅度明显不等');
    else
        subtitle('3个DC+4个调制组：四目标近似等幅');
    end
end

function coefficient = twoBitCoefficient(order)
    states = exp(1j*(0:3)*pi/2);
    edges = linspace(0,2*pi,5);
    if order==0
        coefficient = mean(states);
        return;
    end
    coefficient = 0;
    for k=1:4
        coefficient = coefficient + states(k)*( ...
            exp(-1j*order*edges(k+1))-exp(-1j*order*edges(k))) ...
            /(-1j*2*pi*order);
    end
end

function fig = createWideFigure()
    fig = figure('Color','w','Position',[60,60,1800,920], ...
        'Visible','off');
end
