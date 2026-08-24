%% 完整代码：生成4组竖向三联散点目标，不含船体
clear; clc; close all;

%% 1. 参数设置

% my_data = [方位向, 距离向, 幅度]
% 第1列：方位向，对应 SAR 图像纵轴
% 第2列：距离向，对应 SAR 图像横轴

% 四组散点的位置
% 格式：[方位向, 距离向]
% 左右两组：距离向不同
% 上下两组：方位向不同
group_left   = [ 0.0, -1.0];
group_right  = [ 0.0,  1.0];
group_top    = [-1.0,  0.0];
group_bottom = [ 1.0,  0.0];

group_centers = [
    group_left;
    group_right;
    group_top;
    group_bottom
];

% 每组内部3个点，沿方位向排列
point_spacing = 0.3;

% 每个散点内部生成小密集点云
points_per_dot = 3000;
dot_radius = 0.035;

% 散射强度
scatter_amp = 1;

%% 2. 生成4组竖向三联点

my_data = [];

for g = 1:size(group_centers, 1)

    az_c = group_centers(g, 1);   % 方位向中心
    rg_c = group_centers(g, 2);   % 距离向中心

    % 每组三个点沿方位向排列
    dot_centers = [
        az_c - point_spacing, rg_c;
        az_c,                 rg_c;
        az_c + point_spacing, rg_c
    ];

    for k = 1:3

        az0 = dot_centers(k, 1);
        rg0 = dot_centers(k, 2);

        % 在一个小圆内随机生成密集散射点
        theta = 2*pi*rand(points_per_dot, 1);
        r = dot_radius * sqrt(rand(points_per_dot, 1));

        az_dot = az0 + r .* cos(theta);
        rg_dot = rg0 + r .* sin(theta);

        dot_data = [az_dot, rg_dot, scatter_amp * ones(points_per_dot, 1)];

        my_data = [my_data; dot_data];
    end
end

fprintf('最终散点数量 = %d\n', size(my_data, 1));
fprintf('方位向范围：%.3f ~ %.3f m\n', min(my_data(:,1)), max(my_data(:,1)));
fprintf('距离向范围：%.3f ~ %.3f m\n', min(my_data(:,2)), max(my_data(:,2)));

%% 3. 显示散点结果
% 为了和 SAR 成像图保持一致：
% 横轴画距离向，即第2列
% 纵轴画方位向，即第1列

figure('Color', 'w', 'Name', '四组竖向三联散点目标');

scatter(my_data(:,2), my_data(:,1), 5, 'filled', ...
    'MarkerFaceAlpha', 0.45);

axis equal;
grid on;

xlim([-1.8, 1.8]);
ylim([-1.8, 1.8]);

xlabel('距离向 (m)');
ylabel('方位向 (m)');
title(['四组竖向三联散点目标，点数: ', num2str(size(my_data, 1))]);

%% 4. 保存数据

save_choice = questdlg( ...
    '对结果满意吗？是否保存数据？', ...
    '保存确认', ...
    '保存', '取消', '保存');

if strcmp(save_choice, '保存')
    writematrix(my_data, 'four_group_scatter_points.txt', 'Delimiter', 'tab');
    save('four_group_scatter_points.mat', 'my_data');

    msgbox('数据已成功保存至 four_group_scatter_points.txt 和 four_group_scatter_points.mat');
    fprintf('数据已保存。\n');
else
    fprintf('用户取消保存。\n');
end