%% preview_1bit_harmonic_skeleton.m
% 不生成 SAR 原始回波，直接根据 1-bit 周期序列的 DFT 系数
% 预览各块超表面可能产生的主要谐波位置和相对强度。
%
% 这是快速结构预览，不代替 SHIP_false_ship_1bit_layout.m 的完整 RD 成像。

clear; clc; close all;

load('metasurface_ship_layout_1bit.mat', ...
    'panel_centers','panel_names','panel_amp','pss_configs', ...
    'ship_length','ship_width');

%% 与主程序一致的雷达/采样参数
c = 3e8;
fc = 10e9;
lambda = c/fc;
Tp = 3e-6;
Br = 300e6;
Kr = Br/Tp;
H0 = 20000;
beta1 = deg2rad(70);
v_x = 1000;
Y0 = H0*tan(beta1);
R0 = sqrt(H0^2+Y0^2);

azirange = 200;
Ka = -2*v_x^2/(lambda*R0);
Ba = abs(Ka*(azirange/v_x));
PRF = ceil(1.2*Ba);
Tc = (azirange+300)/v_x;
Na = 2^nextpow2(Tc*PRF);
tm = linspace(-Tc/2,Tc/2,Na);
PRF_actual = 1/(tm(2)-tm(1));

%% 取有限阶谐波进行预览
max_slow_order = 7;
max_fast_order = 4;

all_az = [];
all_rg_slant = [];
all_amp = [];
all_panel_id = [];

for g = 1:size(panel_centers,1)
    slow_phase = pss_configs{g,1};
    fast_base_phase = pss_configs{g,2};
    fast_repeat = pss_configs{g,3};

    slow_code = exp(1j*slow_phase);
    fast_base_code = exp(1j*fast_base_phase);

    Ls = numel(slow_code);
    Lb = numel(fast_base_code);

    if Ls == 1
        slow_orders = 0;
        slow_coeff = 1;
        delta_az = 0;
    else
        slow_orders = -max_slow_order:max_slow_order;
        Xs = fft(slow_code)/Ls;
        slow_coeff = zeros(size(slow_orders));
        for q = 1:numel(slow_orders)
            idx = mod(slow_orders(q),Ls)+1;
            slow_coeff(q) = abs(Xs(idx));
        end
        delta_az = lambda*R0*(PRF_actual/Ls)/(2*v_x);
    end

    if numel(unique(fast_base_phase)) == 1
        fast_orders = 0;
        fast_coeff = 1;
        delta_R = 0;
    else
        fast_orders = -max_fast_order:max_fast_order;
        Xf = fft(fast_base_code)/Lb;
        fast_coeff = zeros(size(fast_orders));
        for q = 1:numel(fast_orders)
            idx = mod(fast_orders(q),Lb)+1;
            fast_coeff(q) = abs(Xf(idx));
        end
        delta_R = c*(fast_repeat/Tp)/(2*Kr);
    end

    % 初始地面距离向位置映射为孔径中心的斜距偏移。
    panel_R = sqrt(H0^2+panel_centers(g,1)^2+(Y0+panel_centers(g,2))^2);
    panel_R_rel = panel_R-R0;

    for ia = 1:numel(slow_orders)
        for ir = 1:numel(fast_orders)
            amp_now = panel_amp(g)*slow_coeff(ia)*fast_coeff(ir);

            all_az(end+1,1) = panel_centers(g,1)+slow_orders(ia)*delta_az; %#ok<SAGROW>
            all_rg_slant(end+1,1) = panel_R_rel+fast_orders(ir)*delta_R; %#ok<SAGROW>
            all_amp(end+1,1) = amp_now; %#ok<SAGROW>
            all_panel_id(end+1,1) = g; %#ok<SAGROW>
        end
    end
end

all_db = 20*log10(all_amp/max(all_amp)+eps);
keep = all_db >= -25;

figure('Color','w','Name','1-bit 谐波舰船骨架快速预览');
scatter(all_rg_slant(keep),all_az(keep), ...
    20+100*(all_db(keep)+25)/25,all_panel_id(keep),'filled');
hold on;

% 标出真实初始位置。
initial_R = sqrt(H0^2+panel_centers(:,1).^2+(Y0+panel_centers(:,2)).^2)-R0;
scatter(initial_R,panel_centers(:,1),170,'x','LineWidth',2);

for g = 1:size(panel_centers,1)
    text(initial_R(g)+0.6,panel_centers(g,1),panel_names{g}, ...
        'FontSize',9,'VerticalAlignment','bottom');
end

set(gca,'YDir','normal');
axis equal; grid on; colorbar;
xlabel('相对斜距位置 (m)');
ylabel('相对方位向位置 (m)');
title('1-bit 周期编码主要谐波位置预览（显示 -25 dB 以上）');
xlim([-45,45]);
ylim([-85,85]);

fprintf('快速预览完成：彩色圆点为主要谐波，叉号为真实超表面初始位置。\n');
