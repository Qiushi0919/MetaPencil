%% generate_metasurface_ship_layout_1bit.m
% 多块 1-bit 超表面初始位置布局：用“物理位置 + 0/pi 周期编码”拼出舰船骨架
%
% 核心思路：
% 1) 不采用连续相位，也不直接生成理想虚拟舰船回波；
% 2) 每块超表面在真实场景中具有不同的初始相对位置；
% 3) 每块超表面仅使用 0/pi 两种反射相位；
% 4) 脉间编码产生方位向谐波复制，脉内编码产生距离向谐波复制；
% 5) 多块超表面的本体位置及其复制点共同构成粗略舰船轮廓。
%
% 数据坐标格式均为：[方位向位置, 地面距离向位置]，单位 m。

clear; clc; close all;

%% 1. 期望的粗略舰船尺寸（仅用于布局参考）
ship_length = 110;             % 方位向长度
ship_width  = 18;              % 地面距离向宽度
heading_deg = 0;               % 当前代码按舰艏朝方位向正方向设计

%% 2. 七块超表面的初始相对位置
% 说明：
% - 左右舷位于距离向两侧，依靠慢时间编码生成纵向点列；
% - 舰艏位于前端并保留为强尖点；
% - 舰艉依靠快时间编码生成平直横列；
% - 前甲板使用较密的快时间编码形成舰艏肩部；
% - 上层建筑使用二维编码产生局部点阵；
% - 桅杆作为强散射中心，默认不切换，仅保持 0 相位状态。
%
% 列：[方位向, 地面距离向]
panel_centers = [
      0,  -8.0;     % 1 左舷种子
      0,   8.0;     % 2 右舷种子
     52,   0.0;     % 3 舰艏尖点
    -50,   0.0;     % 4 舰艉种子
    -12,   0.0;     % 5 上层建筑种子
      8,   0.0;     % 6 桅杆/强中心
     30,   0.0      % 7 前甲板/舰艏肩部
];

panel_names = {
    '';
    '';
    '';
    '';
    '';
    '';
    ''
};

% 每块超表面的等效散射幅度。
% 这里只描述不同部件的强弱，不包含连续相位。
panel_amp = [1.00; 1.00; 2.20; 1.45; 1.80; 2.50; 1.25];

%% 3. 严格 1-bit 慢时间编码：相位只能取 0 或 pi
% 左右舷：周期 48 个脉冲，非 50%% 占空比以保留中心载频分量。
% 在原雷达参数下，慢时间基频对应约 9~10 m 的方位向复制间隔。
slow_phase_1 = [pi*ones(1,29), zeros(1,19)];
slow_phase_2 = [pi*ones(1,29), zeros(1,19)];

% 舰艏、舰艉：慢时间不切换，只保留其初始方位位置。
slow_phase_3 = 0;
slow_phase_4 = 0;

% 上层建筑：较长周期，生成较密的方位向局部点列。
slow_phase_5 = [pi*ones(1,36), zeros(1,24)];

% 桅杆：不切换，保留强中心点。
slow_phase_6 = 0;

% 前甲板：不做慢时间复制，只在本身方位位置形成横向肩部。
slow_phase_7 = 0;

%% 4. 严格 1-bit 快时间编码
% pss_configs 每行：{慢时间相位序列, 快时间基础相位码, 快时间重复次数}
%
% 快时间码在一个 3 us LFM 脉冲内重复：
% - 重复 8 次时，距离向基准复制间隔约 4 m（斜距）；
% - 重复 10 次时，距离向基准复制间隔约 5 m（斜距）。
%
% [0] 表示一直处于 0 相位状态，并没有采用连续相位。
pss_configs = {
    slow_phase_1, [0],           1;    % 1 左舷：只做方位向点列
    slow_phase_2, [0],           1;    % 2 右舷：只做方位向点列
    slow_phase_3, [0],           1;    % 3 舰艏：保留单个强尖点
    slow_phase_4, [0,0,0,pi],    8;    % 4 舰艉：距离向平直横列
    slow_phase_5, [0,0,pi],     10;    % 5 上层建筑：二维局部点阵
    slow_phase_6, [0],           1;    % 6 桅杆：强中心点
    slow_phase_7, [0,0,0,pi],    4     % 7 前甲板：较窄的距离向肩部
};

%% 5. 检查所有相位状态是否严格属于 {0, pi}
for g = 1:size(pss_configs,1)
    slow_phase = pss_configs{g,1};
    fast_phase = pss_configs{g,2};

    valid_slow = all(abs(slow_phase) < 1e-12 | abs(slow_phase-pi) < 1e-12);
    valid_fast = all(abs(fast_phase) < 1e-12 | abs(fast_phase-pi) < 1e-12);

    assert(valid_slow && valid_fast, ...
        '第 %d 块超表面包含非 0/pi 的相位状态。', g);
end

%% 6. 保存布局
save('metasurface_ship_layout_1bit.mat', ...
    'panel_centers','panel_names','panel_amp','pss_configs', ...
    'ship_length','ship_width','heading_deg');

fprintf('已保存 metasurface_ship_layout_1bit.mat\n');
fprintf('超表面数量：%d\n',size(panel_centers,1));
fprintf('全部调制状态已检查：仅包含 0 和 pi。\n');

%% 7. 显示物理超表面初始布局
% 参考舰船外轮廓，仅用于观察初始位置是否合理。
L = ship_length;
W = ship_width;
hull_ref = [
    -0.50*L, -0.45*W;
    -0.50*L,  0.45*W;
     0.28*L,  0.50*W;
     0.43*L,  0.28*W;
     0.50*L,  0.00*W;
     0.43*L, -0.28*W;
     0.28*L, -0.50*W;
    -0.50*L, -0.45*W
];

figure('Color','w','Name','1-bit 超表面舰船初始布局');
plot(hull_ref(:,2),hull_ref(:,1),'--','LineWidth',1.2); hold on;
scatter(panel_centers(:,2),panel_centers(:,1), ...
    90+45*panel_amp,'filled','MarkerEdgeColor','k');

for g = 1:size(panel_centers,1)
    text(panel_centers(g,2)+0.8,panel_centers(g,1), ...
        sprintf('%d %s',g,panel_names{g}), ...
        'FontSize',10,'VerticalAlignment','middle');
end

axis equal; grid on;
xlabel('地面距离向相对位置 (m)');
ylabel('方位向相对位置 (m)');
title('七块 1-bit 超表面的初始相对位置');
set(gca,'YDir','normal');
xlim([-18,18]);
ylim([-65,65]);
