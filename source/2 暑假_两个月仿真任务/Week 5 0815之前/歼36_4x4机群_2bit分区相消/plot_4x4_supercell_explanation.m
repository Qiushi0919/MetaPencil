%% 单极化2-bit 4×4局部超单元：结构、时序和相干叠加说明图
clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
output_dir = fullfile(script_dir, 'supercell_explanation');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

delay_fraction = [0, 1/10, 5/6, 14/15];
delay_text = {'0', 'T/10', '5T/6', '14T/15'};
phase_states_deg = [0, 90, 180, 270];
group_colors = lines(4);

%% 1. 导出16种联合控制时序表
cell_id = strings(16,1);
range_group = zeros(16,1);
azimuth_group = zeros(16,1);
range_delay_fraction = zeros(16,1);
azimuth_delay_fraction = zeros(16,1);
amplitude_weight = repmat(1/16,16,1);
allowed_phase_states_deg = repmat("0/90/180/270",16,1);
instantaneous_state_rule = strings(16,1);

row = 0;
for range_index = 1:4
    for azimuth_index = 1:4
        row = row+1;
        cell_id(row) = sprintf('P%d%d', range_index, azimuth_index);
        range_group(row) = range_index;
        azimuth_group(row) = azimuth_index;
        range_delay_fraction(row) = delay_fraction(range_index);
        azimuth_delay_fraction(row) = delay_fraction(azimuth_index);
        instantaneous_state_rule(row) = sprintf( ...
            'mod(q_r(tau-d_%d*T_r)+q_a(eta-d_%d*T_a),4)', ...
            range_index, azimuth_index);
    end
end

control_table = table(cell_id, range_group, azimuth_group, ...
    range_delay_fraction, azimuth_delay_fraction, amplitude_weight, ...
    allowed_phase_states_deg, instantaneous_state_rule);
writetable(control_table, fullfile(output_dir, ...
    'supercell_16_control_combinations.csv'));

%% 2. Figure 1：4×4局部超单元和单元内部处理流程
figure_array = figure('Color','w', 'Position',[80,80,1500,720], ...
    'Name','4×4局部超单元控制说明', 'NumberTitle','off');
tiledlayout(1,2, 'TileSpacing','compact', 'Padding','compact');

nexttile;
hold on;
for range_index = 1:4
    for azimuth_index = 1:4
        x0 = azimuth_index-1;
        y0 = 4-range_index;
        face_color = 0.80 + 0.20*group_colors(range_index,:);
        rectangle('Position',[x0,y0,1,1], ...
            'FaceColor',face_color, 'EdgeColor',[0.20 0.20 0.20], ...
            'LineWidth',1.2);
        text(x0+0.5, y0+0.68, ...
            sprintf('P_{%d%d}',range_index,azimuth_index), ...
            'HorizontalAlignment','center', 'FontWeight','bold', ...
            'FontSize',12, 'Interpreter','tex');
        text(x0+0.5, y0+0.40, ...
            sprintf('d_r=%s',delay_text{range_index}), ...
            'HorizontalAlignment','center', 'FontSize',9, ...
            'Interpreter','tex');
        text(x0+0.5, y0+0.18, ...
            sprintf('d_a=%s',delay_text{azimuth_index}), ...
            'HorizontalAlignment','center', 'FontSize',9, ...
            'Interpreter','tex');
    end
end
hold off;
axis equal;
xlim([0,4]); ylim([0,4]);
set(gca, 'XAxisLocation','top', ...
    'XTick',0.5:1:3.5, 'XTickLabel',{'A_1','A_2','A_3','A_4'}, ...
    'YTick',[0.5,1.5,2.5,3.5], ...
    'YTickLabel',{'R_4','R_3','R_2','R_1'}, ...
    'FontSize',11);
xlabel('方位向时延组 A_j');
ylabel('距离向时延组 R_i');
title({'一个局部4×4超单元：P_{ij}=R_i×A_j', ...
    '每格仍是单极化2-bit四相位单元，不是固定相位块'});

nexttile;
axis([0,1,0,1]); axis off; hold on;
drawBox(gca, [0.08,0.84,0.84,0.10], ...
    '入射SAR回波  s_{in}(\tau,\eta)', [0.94 0.94 0.94]);
drawArrow(gca, [0.50,0.84], [0.50,0.77]);

drawBox(gca, [0.05,0.61,0.42,0.15], ...
    {'距离快时间编码', 'q_r(\tau-d_iT_r)'}, [0.86 0.92 1.00]);
drawBox(gca, [0.53,0.61,0.42,0.15], ...
    {'方位慢时间编码', 'q_a(\eta-d_jT_a)'}, [1.00 0.91 0.83]);
drawArrow(gca, [0.26,0.61], [0.43,0.52]);
drawArrow(gca, [0.74,0.61], [0.57,0.52]);

drawBox(gca, [0.20,0.40,0.60,0.12], ...
    {'P_{ij}当前状态', 's_{ij}=mod(q_r+q_a,4)'}, [0.90 0.96 0.88]);
drawArrow(gca, [0.50,0.40], [0.50,0.33]);
drawBox(gca, [0.14,0.20,0.72,0.13], ...
    {'单极化2-bit反射', ...
    '\Gamma_{ij}=exp(j\pi s_{ij}/2) \in {0^\circ,90^\circ,180^\circ,270^\circ}'}, ...
    [0.96 0.90 0.96]);
drawArrow(gca, [0.50,0.20], [0.50,0.13]);
drawBox(gca, [0.07,0.02,0.86,0.11], ...
    {'16个共址子单元相干平均', ...
    '\Gamma_{eff}=(1/16)\Sigma_i\Sigma_j\Gamma_{ij}'}, ...
    [0.91 0.91 0.91]);
title({'任意一个P_{ij}在做什么', ...
    '下标i选择距离时延，下标j选择方位时延'});
hold off;

sgtitle('单极化2-bit 4×4局部超单元：16种时序怎样组成一个等效反射系数', ...
    'FontWeight','bold');
saveFigurePair(figure_array, output_dir, '01_supercell_array_and_cell_operation');

%% 3. Figure 2：四个延迟组的2-bit切换序列
normalized_time = linspace(0,1,1601);
figure_timing = figure('Color','w', 'Position',[120,80,1180,900], ...
    'Name','四组2-bit延迟序列', 'NumberTitle','off');
tiledlayout(4,1, 'TileSpacing','compact', 'Padding','compact');

for group_index = 1:4
    nexttile;
    shifted_time = mod(normalized_time-delay_fraction(group_index),1);
    state_index = min(floor(4*shifted_time),3);
    stairs(normalized_time, phase_states_deg(state_index+1), ...
        'Color',group_colors(group_index,:), 'LineWidth',2.0);
    grid on;
    xlim([0,1]); ylim([-15,285]);
    yticks(phase_states_deg);
    ylabel('相位/°');
    title(sprintf('组%d：d_%d=%s，同一条2-bit四相位阶梯仅做循环平移', ...
        group_index, group_index, delay_text{group_index}));
end
xlabel('归一化时间  t/T');
sgtitle({'四个距离组和四个方位组使用相同的延迟集合', ...
    '一个P_{ij}同时选取第i条距离序列和第j条方位序列'});
saveFigurePair(figure_timing, output_dir, '02_four_delayed_2bit_sequences');

%% 4. Figure 3：四个分区相量如何保留+1并抵消-3/+5
orders_to_show = [1,-3,5];
figure_phasor = figure('Color','w', 'Position',[100,100,1500,560], ...
    'Name','谐波相量相干叠加', 'NumberTitle','off');
tiledlayout(1,3, 'TileSpacing','compact', 'Padding','compact');

for plot_index = 1:numel(orders_to_show)
    nexttile;
    plotPhasorChain(orders_to_show(plot_index), delay_fraction, ...
        group_colors);
end
sgtitle({'距离向或方位向的四组相量首尾叠加', ...
    '同一套延迟使+1阶保持非零，而-3和+5阶闭合为零'});
saveFigurePair(figure_phasor, output_dir, '03_harmonic_phasor_coherent_sum');

%% 5. Figure 4：二维乘积如何只保留中央(1,1)
selected_orders = [-3,1,5];
partition_factor = arrayfun(@(n) mean(exp( ...
    -1j*2*pi*n*delay_fraction)), selected_orders);
factor_2d = abs(partition_factor(:)*partition_factor(:).');

figure_2d = figure('Color','w', 'Position',[160,100,760,680], ...
    'Name','二维谐波分区因子', 'NumberTitle','off');
imagesc(selected_orders, selected_orders, factor_2d, [0,1]);
set(gca,'YDir','normal', 'FontSize',12);
axis image;
colormap(parula);
colorbar;
xticks(selected_orders); yticks(selected_orders);
xlabel('距离谐波阶次 n_r');
ylabel('方位谐波阶次 n_a');
title({'二维分区因子 |S_{n_r}S_{n_a}|', ...
    '行列任一方向落在-3或+5阶，乘积都会变为0'});
for row_index = 1:3
    for column_index = 1:3
        text(selected_orders(column_index), selected_orders(row_index), ...
            sprintf('%.4f',factor_2d(row_index,column_index)), ...
            'HorizontalAlignment','center', 'FontWeight','bold', ...
            'Color','w', 'FontSize',12);
    end
end
saveFigurePair(figure_2d, output_dir, '04_two_dimensional_partition_factor');

fprintf('4×4局部超单元说明图和控制表已保存至：\n%s\n', output_dir);

%% ====================== 局部函数 ======================
function drawBox(ax, position, label_text, face_color)
    rectangle(ax, 'Position',position, 'Curvature',0.06, ...
        'FaceColor',face_color, 'EdgeColor',[0.25 0.25 0.25], ...
        'LineWidth',1.2);
    text(ax, position(1)+position(3)/2, position(2)+position(4)/2, ...
        label_text, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', 'FontSize',11, ...
        'Interpreter','tex');
end

function drawArrow(ax, start_point, end_point)
    direction = end_point-start_point;
    quiver(ax, start_point(1), start_point(2), ...
        direction(1), direction(2), 0, 'k', ...
        'LineWidth',1.4, 'MaxHeadSize',0.8);
end

function plotPhasorChain(order, delay_fraction, group_colors)
    vectors = exp(-1j*2*pi*order*delay_fraction);
    chain = [0, cumsum(vectors)];
    hold on;
    for index = 1:4
        plot(real(chain(index:index+1)), imag(chain(index:index+1)), ...
            '-o', 'Color',group_colors(index,:), 'LineWidth',2.5, ...
            'MarkerFaceColor',group_colors(index,:), ...
            'DisplayName',sprintf('组%d',index));
        midpoint = (chain(index)+chain(index+1))/2;
        text(real(midpoint), imag(midpoint), sprintf('  P_%d',index), ...
            'Color',group_colors(index,:), 'FontWeight','bold');
    end
    plot([0,real(chain(end))], [0,imag(chain(end))], '--k', ...
        'LineWidth',1.8, 'DisplayName','合成相量');
    scatter(0,0,55,'k','x','LineWidth',2,'HandleVisibility','off');
    grid on; axis equal;
    all_x = real(chain); all_y = imag(chain);
    span = max([range(all_x), range(all_y), 2]);
    xlim([min(all_x)-0.25*span, max(all_x)+0.25*span]);
    ylim([min(all_y)-0.25*span, max(all_y)+0.25*span]);
    xlabel('实部'); ylabel('虚部');
    sum_factor = mean(vectors);
    title(sprintf('n=%+d：|S_{%+d}|=%.6f', ...
        order, order, abs(sum_factor)));
    if order == 1
        legend('Location','best');
    end
    hold off;
end

function saveFigurePair(fig, output_dir, base_name)
    png_file = fullfile(output_dir, [base_name,'.png']);
    fig_file = fullfile(output_dir, [base_name,'.fig']);
    if exist('exportgraphics','file') == 2
        exportgraphics(fig, png_file, 'Resolution',200);
    else
        saveas(fig, png_file);
    end
    savefig(fig, fig_file);
end
