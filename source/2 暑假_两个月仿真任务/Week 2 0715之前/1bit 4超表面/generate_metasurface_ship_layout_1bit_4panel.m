%% generate_metasurface_ship_layout_1bit_4panel.m
% 四块 1-bit 超表面初始位置布局：左右舷 + 舰艏 + 舰艉
%
% 核心思路：
% 1) 不采用连续相位；
% 2) 每块超表面只有 0/pi 两种反射相位；
% 3) 左右舷两块通过脉间编码形成方位向点列；
% 4) 舰艉通过脉内编码形成距离向横列；
% 5) 舰艏保留为一个较强尖点；
% 6) 四块的真实位置与谐波复制共同形成最简舰船骨架。
%
% 坐标格式：[方位向位置, 地面距离向位置]，单位 m。

clear; clc; close all;

%% 1. 舰船参考尺寸
ship_length = 110;             % 方位向长度，m
ship_width  = 18;              % 地面距离向宽度，m
heading_deg = 0;               % 舰艏朝方位向正方向

%% 2. 四块超表面的初始相对位置
% 1、2：左右舷种子；3：舰艏强点；4：舰艉横向结构种子。
panel_centers = [
      0,  -8.0;     % 1 左舷
      0,   8.0;     % 2 右舷
     52,   0.0;     % 3 舰艏尖点
    -50,   0.0      % 4 舰艉
];

panel_names = {
    '';
    '';
    '';
    ''
};

% 等效散射幅度：舰艏较强，舰艉次之，左右舷较弱。
panel_amp = [1.00; 1.00; 2.30; 1.50];

%% 3. 严格 1-bit 慢时间编码
% 左右舷：周期 48 个脉冲，采用非 50%% 占空比，使零阶分量不完全消失。
% 在主程序的雷达参数下，方位向基本复制间隔约 9.3 m。
slow_phase_1 = [pi*ones(1,29), zeros(1,19)];
slow_phase_2 = [pi*ones(1,29), zeros(1,19)];

% 舰艏和舰艉不做方位复制，只保留各自初始方位位置。
slow_phase_3 = 0;
slow_phase_4 = 0;

%% 4. 严格 1-bit 快时间编码
% pss_configs 每行：{慢时间相位序列, 快时间基础相位码, 快时间重复次数}
%
% 舰艉基础码 [0,0,0,pi] 在 3 us 脉冲内重复 8 次，
% 对应距离向基本谐波间隔约 4 m（斜距）。
pss_configs = {
    slow_phase_1, [0],          1;    % 左舷：只做方位向点列
    slow_phase_2, [0],          1;    % 右舷：只做方位向点列
    slow_phase_3, [0],          1;    % 舰艏：强单点
    slow_phase_4, [0,0,0,pi],   8     % 舰艉：距离向横列
};

%% 5. 验证所有相位只属于 {0, pi}
for g = 1:size(pss_configs,1)
    slow_phase = pss_configs{g,1};
    fast_phase = pss_configs{g,2};

    valid_slow = all(abs(slow_phase) < 1e-12 | abs(slow_phase-pi) < 1e-12);
    valid_fast = all(abs(fast_phase) < 1e-12 | abs(fast_phase-pi) < 1e-12);

    assert(valid_slow && valid_fast, ...
        '第 %d 块超表面包含非 0/pi 的相位状态。',g);
end

%% 6. 保存配置
save('metasurface_ship_layout_1bit_4panel.mat', ...
    'panel_centers','panel_names','panel_amp','pss_configs', ...
    'ship_length','ship_width','heading_deg');

fprintf('已保存 metasurface_ship_layout_1bit_4panel.mat\n');
fprintf('超表面数量：%d\n',size(panel_centers,1));
fprintf('全部调制状态已检查：仅包含 0 和 pi。\n');

%% 7. 显示四块超表面的真实初始位置
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

figure('Color','w','Name','四块 1-bit 超表面初始布局');
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
title('四块 1-bit 超表面的真实初始相对位置');
set(gca,'YDir','normal');
xlim([-18,18]);
ylim([-65,65]);
