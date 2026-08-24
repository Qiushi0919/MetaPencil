clear all; clc; close all;

%% 1. 雷达参数
fprintf('正在生成弹载 SAR 原始回波...\n');

j = sqrt(-1);
c = 3e8;
fc = 10e9;
lambda = c / fc;

Tp = 3e-6;
Br = 50e6 * 6;
Fs_init = 4.0 * Br;
Kr = Br / Tp;

beta1 = 70*pi/180;
theta = 0*pi/180;

H0 = 20000;
v_x = 1000;

D = 10;
rou_a = D / 2;

%% 2. 目标场景与几何计算
Y0 = H0 * tan(beta1);
X0 = 0;

R0 = sqrt(H0^2 + Y0^2);

azirange = 200;
ranrange = 0;

%% 3. 加载四组竖向三联点目标
% 注意：
% four_group_scatter_points.mat 中 my_data 的格式应为：
% my_data = [方位向, 距离向, 幅度]
load('four_group_scatter_points.mat', 'my_data');

target = my_data;

% 抽稀，减少计算量
downsample_rate = 80;
target = target(1:downsample_rate:end, :);

% 只放大坐标，不放大散射强度
scale_size = 10;
target(:,1:2) = scale_size * target(:,1:2);
target(:,3) = 1;

% 四组点中心，格式：[方位向, 距离向]
% 注意：target(:,1) 是方位向，target(:,2) 是距离向
group_centers = [
     0, -1;   % 左侧三连点：距离向偏左
     0,  1;   % 右侧三连点：距离向偏右
    -1,  0;   % 上方三连点：方位向偏上
     1,  0    % 下方三连点：方位向偏下
] * scale_size;

% 加到场景中心
order = target;
order(:,1) = order(:,1) + X0;   % 方位向
order(:,2) = order(:,2) + Y0;   % 距离向

Ntar = size(order, 1);

fprintf('目标点数 = %d\n', Ntar);

%% 4. 采样参数
Ka = -2 * v_x^2 / (lambda * R0);
Ba = abs(Ka * (azirange / v_x));
PRF = ceil(1.2 * Ba);

fprintf('当前实际 Ka 为: %.2f Hz\n', Ka);

% 慢时间轴
Tc1 = (azirange + 300) / v_x;
Na = 2^nextpow2(Tc1 * PRF);

tm = linspace(-Tc1/2, Tc1/2, Na);
x_radar = tm * v_x;

PRF_actual = 1 / (tm(2) - tm(1));

fprintf('当前实际 PRF 为: %.2f Hz\n', PRF_actual);

% 距离向采样
Rmin = R0 - ranrange;
Rmax = R0 + ranrange;

Nr = 2^nextpow2(ceil((2*(Rmax - Rmin)/c + Tp) * Fs_init));

t = linspace(2*Rmin/c - Tp/2, 2*Rmax/c + Tp/2, Nr);
dt = t(2) - t(1);
Fs = 1 / dt;

fprintf('当前实际 Fs 为: %.2f Hz\n', Fs);

%% 5. 四块超表面调制模板
% 每组三连点由一块超表面覆盖
% pss_configs 每一行：{慢时间调制序列, 快时间基础码, 快时间重复次数}

% 超表面1：左侧三连点
N_pi_1 = 60;
N_0_1  = 36;
slow_code1 = exp(1j * [pi*ones(1,N_pi_1), zeros(1,N_0_1)]);

% 超表面2：右侧三连点
N_pi_2 = 43;
N_0_2  = 24;
slow_code2 = exp(1j * [pi*ones(1,N_pi_2), zeros(1,N_0_2)]);

% 超表面3：上方三连点
N_pi_3 = 100;
N_0_3  = 12;
slow_code3 = exp(1j * [pi*ones(1,N_pi_3), zeros(1,N_0_3)]);

% 超表面4：下方三连点
N_pi_4 = 100;
N_0_4  = 12;
slow_code4 = exp(1j * [pi*ones(1,N_pi_4), zeros(1,N_0_4)]);

% 四块超表面分别使用调制模板
pss_configs = {
    slow_code1, [pi, pi, 0], 10;     % 左侧三连点
    slow_code2, [0,0], 10;     % 右侧三连点
    slow_code3, [pi, pi,0], 10;     % 上方三连点
    slow_code4, [pi, pi,0],10;      % 下方三连点
};

num_groups = size(pss_configs, 1);
fprintf('共定义了 %d 组二维调制模板。\n', num_groups);



%% 6. 生成四块超表面对应的调制模板
fprintf('正在执行四块超表面分别调制四组三连点的回波生成...\n');

sr_total = zeros(Na, Nr);

mod_templates = cell(num_groups, 2);

for g = 1:num_groups
    s_temp = pss_configs{g, 1};
    base_f = pss_configs{g, 2};
    n_rep  = pss_configs{g, 3};

    % 快时间模板
    mod_templates{g, 1} = exp(1j * repmat(base_f, 1, n_rep));

    % 慢时间模板
    mod_templates{g, 2} = s_temp;
end

%% 7. 四组三连点覆盖区域设置
% target(:,1) 是方位向
% target(:,2) 是距离向
% 当前三连点沿方位向排列，所以方位向覆盖范围要大一些

cover_radius_az = 4.0;   % 方位向覆盖半宽
cover_radius_rg = 1.2;   % 距离向覆盖半宽

% 用于统计每块超表面覆盖了多少点
cover_count = zeros(num_groups, 1);

%% 8. 生成原始回波
for i = 1:Ntar

    xi = target(i, 1);   % 方位向
    zi = target(i, 2);   % 距离向

    % 四组三连点分别由四块超表面覆盖
    is_group_left   = (abs(xi - group_centers(1,1)) < cover_radius_az) && ...
                      (abs(zi - group_centers(1,2)) < cover_radius_rg);

    is_group_right  = (abs(xi - group_centers(2,1)) < cover_radius_az) && ...
                      (abs(zi - group_centers(2,2)) < cover_radius_rg);

    is_group_top    = (abs(xi - group_centers(3,1)) < cover_radius_az) && ...
                      (abs(zi - group_centers(3,2)) < cover_radius_rg);

    is_group_bottom = (abs(xi - group_centers(4,1)) < cover_radius_az) && ...
                      (abs(zi - group_centers(4,2)) < cover_radius_rg);

    % 确定当前点属于哪块超表面
    idx = 0;

    if is_group_left
        idx = 1;
    elseif is_group_right
        idx = 2;
    elseif is_group_top
        idx = 3;
    elseif is_group_bottom
        idx = 4;
    end

    if idx > 0
        cover_count(idx) = cover_count(idx) + 1;
    end

    for k = 1:Na

        r_inst = sqrt((order(i,1) - x_radar(k))^2 + order(i,2)^2 + H0^2);
        tr_delay = 2 * r_inst / c;

        % 基础回波
        s_pulse_base = order(i,3) * rectpuls(t - tr_delay, Tp) .* ...
                       exp(1j*pi*Kr*(t - tr_delay).^2) .* ...
                       exp(-1j*4*pi*r_inst/lambda);

        if idx > 0
            % 使用对应超表面模板进行调制
            curr_f_temp = mod_templates{idx, 1};
            curr_s_temp = mod_templates{idx, 2};

            L_f = length(curr_f_temp);
            L_s = length(curr_s_temp);

            % 慢时间调制
            m_slow = curr_s_temp(mod(k-1, L_s) + 1);

            % 快时间调制
            t_rel = t - (tr_delay - Tp/2);
            mask = (t_rel >= 0) & (t_rel <= Tp);

            m_fast = ones(1, Nr);

            if any(mask)
                fast_idx = floor((t_rel(mask) / Tp) * (L_f - 1)) + 1;
                m_fast(mask) = curr_f_temp(fast_idx);
            end

            sr_total(k, :) = sr_total(k, :) + m_slow * m_fast .* s_pulse_base;

        else
            % 未覆盖区域，普通散射
            sr_total(k, :) = sr_total(k, :) + s_pulse_base;
        end
    end

    if mod(i, 500) == 0
        fprintf('已处理点数: %d/%d\n', i, Ntar);
    end
end

fprintf('四块超表面覆盖点数统计：\n');
fprintf('左侧三连点覆盖点数: %d\n', cover_count(1));
fprintf('右侧三连点覆盖点数: %d\n', cover_count(2));
fprintf('上方三连点覆盖点数: %d\n', cover_count(3));
fprintf('下方三连点覆盖点数: %d\n', cover_count(4));

%% 9. RD 算法成像
fprintf('开始 RD 算法处理...\n');

% 距离压缩参考信号
t_ref = (-(Nr/2):(Nr/2-1)) * dt;
h_ref = exp(1j * pi * Kr * t_ref.^2) .* rectpuls(t_ref, Tp);

H_range = conj(fft(fftshift(h_ref)));

% 距离向匹配滤波
S_range = fft(sr_total, [], 2) .* repmat(H_range, Na, 1);
s_rc = ifft(S_range, [], 2);

% 方位向 FFT
S_az = fft(s_rc, [], 1);

fa = (0:Na-1)/Na * PRF_actual;
fa(fa > PRF_actual/2) = fa(fa > PRF_actual/2) - PRF_actual;
fa = fa.';

fprintf('执行 RCMC 插值...\n');

R_axis = t * c / 2;
s_rcmc = zeros(size(S_az));

for k = 1:Na

    move_factor = (lambda^2 * fa(k)^2) / (8 * v_x^2);
    shift_R = R_axis * move_factor;

    s_rcmc(k,:) = interp1(R_axis, S_az(k,:), R_axis + shift_R, 'spline', 0);
end

% 方位压缩
H_az = exp(1j * pi * fa.^2 / Ka);
S_foc = s_rcmc .* repmat(H_az, 1, Nr);
img = ifft(S_foc, [], 1);

%% 10. 绘图：线性幅度图
figure('Color', 'w');

img_plot = abs(img);
max_img_val = max(img_plot(:));

fprintf('图像最大幅度: %.4f\n', max_img_val);

img_plot_normalized = img_plot / max_img_val;

imagesc(R_axis, tm * v_x, img_plot_normalized);
axis image;
colormap jet;

xlabel('距离向 (m)');
ylabel('方位向 (m)');
title('RD算法处理结果');

%% 11. 绘图：dB 图
img_abs = abs(img);
img_db = 20 * log10(img_abs + eps);
img_db = img_db - max(img_db(:));

figure('Color', 'w');

imagesc(R_axis, tm * v_x, img_db, [-13, 0]);

axis image;
colormap jet;
colorbar;

xlabel('距离向 (m)');
ylabel('方位向 (m)');
title('四块超表面调制结果 (dB)');


%% 11. 绘图：dB 图（增强 -13 dB 以上亮度）
img_abs = abs(img);
img_db = 20 * log10(img_abs + eps);
img_db = img_db - max(img_db(:));   % 最大值归一化到 0 dB

% ===============================
% 亮度增强参数
% ===============================
db_min = -13;          % 只重点显示 -13 dB 以上
db_max = 0;
gamma_val = 0.45;     % 小于1会让中低强度点更亮；可调 0.35~0.7

% 截断到 [-13, 0]
img_db_clip = img_db;
img_db_clip(img_db_clip < db_min) = db_min;
img_db_clip(img_db_clip > db_max) = db_max;

% 归一化到 [0,1]
img_norm = (img_db_clip - db_min) / (db_max - db_min);

% Gamma 增强，让 -13 dB 以上的点整体更亮
img_bright = img_norm .^ gamma_val;

figure('Color', 'w');

imagesc(R_axis, tm * v_x, img_bright, [0, 1]);

axis image;
colormap jet;
colorbar;

xlabel('距离向 (m)');
ylabel('方位向 (m)');
title('四块超表面调制结果（-13 dB以上亮度增强）');