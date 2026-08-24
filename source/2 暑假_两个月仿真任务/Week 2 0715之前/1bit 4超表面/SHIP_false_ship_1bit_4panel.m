%% SHIP_false_ship_1bit_4panel.m
% 四块超表面初始相对位置 + 严格 1-bit 脉内/脉间编码的舰船假目标仿真
%
% 四块功能：
% 1) 左舷：慢时间 0/pi 编码，产生方位点列；
% 2) 右舷：慢时间 0/pi 编码，产生方位点列；
% 3) 舰艏：强单点；
% 4) 舰艉：快时间 0/pi 编码，产生距离横列。
%
% 运行顺序：
% 1) generate_metasurface_ship_layout_1bit_4panel.m
% 2) preview_1bit_harmonic_skeleton_4panel.m（可选）
% 3) SHIP_false_ship_1bit_4panel.m

clear; clc; close all;

%% 1. 雷达参数
fprintf('正在生成四块 1-bit 超表面舰船假目标回波...\n');

c = 3e8;
fc = 10e9;
lambda = c/fc;

Tp = 3e-6;
Br = 300e6;
Fs_init = 4*Br;
Kr = Br/Tp;

beta1 = deg2rad(70);
H0 = 20000;
v_x = 1000;

%% 2. 场景中心
X0 = 0;
Y0 = H0*tan(beta1);
R0 = sqrt(H0^2+Y0^2);

%% 3. 加载四块超表面布局和编码
load('metasurface_ship_layout_1bit_4panel.mat', ...
    'panel_centers','panel_names','panel_amp','pss_configs', ...
    'ship_length','ship_width','heading_deg');

num_panels = size(panel_centers,1);
assert(num_panels == 4,'本程序要求配置中恰好包含四块超表面。');
assert(num_panels == size(pss_configs,1), ...
    '超表面位置数量与编码模板数量不一致。');

global_panel = [ ...
    X0 + panel_centers(:,1), ...
    Y0 + panel_centers(:,2), ...
    panel_amp];

fprintf('超表面数量：%d\n',num_panels);
fprintf('舰船参考尺寸：长 %.1f m，宽 %.1f m\n',ship_length,ship_width);

%% 4. 慢时间采样
azirange = 200;
Ka = -2*v_x^2/(lambda*R0);
Ba = abs(Ka*(azirange/v_x));
PRF = ceil(1.2*Ba);

Tc = (azirange+300)/v_x;
Na = 2^nextpow2(Tc*PRF);
tm = linspace(-Tc/2,Tc/2,Na);
x_radar = v_x*tm;
PRF_actual = 1/(tm(2)-tm(1));

fprintf('Ka = %.2f Hz/s，Na = %d，实际 PRF = %.2f Hz\n', ...
    Ka,Na,PRF_actual);

%% 5. 快时间采样
R_panel0 = sqrt(H0^2 + global_panel(:,1).^2 + global_panel(:,2).^2);
range_margin = 65;
Rmin = min(R_panel0)-range_margin;
Rmax = max(R_panel0)+range_margin;

Nr = 2^nextpow2(ceil((2*(Rmax-Rmin)/c+Tp)*Fs_init));
t = linspace(2*Rmin/c-Tp/2,2*Rmax/c+Tp/2,Nr);
dt = t(2)-t(1);
Fs = 1/dt;

fprintf('Nr = %d，实际 Fs = %.3f GHz\n',Nr,Fs/1e9);

%% 6. 生成严格 1-bit 调制模板
mod_templates = cell(num_panels,2);

fprintf('\n四块超表面的近似谐波复制间隔：\n');
for g = 1:num_panels
    slow_phase = pss_configs{g,1};
    fast_base_phase = pss_configs{g,2};
    fast_repeat = pss_configs{g,3};

    valid_slow = all(abs(slow_phase)<1e-12 | abs(slow_phase-pi)<1e-12);
    valid_fast = all(abs(fast_base_phase)<1e-12 | abs(fast_base_phase-pi)<1e-12);
    assert(valid_slow && valid_fast, ...
        '第 %d 块超表面存在非 0/pi 相位。',g);

    mod_templates{g,1} = exp(1j*repmat(fast_base_phase,1,fast_repeat));
    mod_templates{g,2} = exp(1j*slow_phase);

    Ls = numel(slow_phase);
    if Ls > 1
        fm_slow = PRF_actual/Ls;
        delta_az = lambda*R0*fm_slow/(2*v_x);
    else
        delta_az = 0;
    end

    if numel(unique(fast_base_phase)) > 1
        fm_fast = fast_repeat/Tp;
        delta_R = c*fm_fast/(2*Kr);
    else
        delta_R = 0;
    end

    fprintf('%d %-8s：方位间隔约 %6.2f m，斜距间隔约 %5.2f m\n', ...
        g,panel_names{g},delta_az,delta_R);
end

%% 7. 生成四块超表面的原始回波
sr_total = complex(zeros(Na,Nr));

for g = 1:num_panels
    xg = global_panel(g,1);
    yg = global_panel(g,2);
    sigma_g = global_panel(g,3);

    fast_template = mod_templates{g,1};
    slow_template = mod_templates{g,2};
    Lf = numel(fast_template);
    Ls = numel(slow_template);

    for k = 1:Na
        Rg = sqrt((xg-x_radar(k))^2+yg^2+H0^2);
        tau_g = 2*Rg/c;

        tau_rel = t-tau_g;
        pulse_gate = abs(tau_rel)<=Tp/2;

        s_base = sigma_g .* pulse_gate .* ...
            exp(1j*pi*Kr*tau_rel.^2) .* ...
            exp(-1j*4*pi*Rg/lambda);

        % 脉间 1-bit 相位状态。
        m_slow = slow_template(mod(k-1,Ls)+1);

        % 脉内 1-bit 相位状态。
        m_fast = ones(1,Nr);
        if Lf > 1 && any(pulse_gate)
            t_inside = tau_rel(pulse_gate)+Tp/2;
            fast_idx = floor(t_inside/Tp*Lf)+1;
            fast_idx(fast_idx<1) = 1;
            fast_idx(fast_idx>Lf) = Lf;
            m_fast(pulse_gate) = fast_template(fast_idx);
        end

        sr_total(k,:) = sr_total(k,:) + m_slow.*m_fast.*s_base;
    end

    fprintf('已完成超表面 %d/%d：%s\n',g,num_panels,panel_names{g});
end

%% 8. RD 成像
fprintf('\n开始执行 RD 成像...\n');

% 距离压缩
t_ref = (-(Nr/2):(Nr/2-1))*dt;
h_ref = exp(1j*pi*Kr*t_ref.^2).*(abs(t_ref)<=Tp/2);
H_range = conj(fft(fftshift(h_ref)));

S_range = fft(sr_total,[],2).*repmat(H_range,Na,1);
s_rc = ifft(S_range,[],2);

% 方位 FFT
S_az = fft(s_rc,[],1);
fa = (0:Na-1)/Na*PRF_actual;
fa(fa>PRF_actual/2) = fa(fa>PRF_actual/2)-PRF_actual;
fa = fa.';

% 距离徙动校正
R_axis = t*c/2;
s_rcmc = complex(zeros(size(S_az)));
for k = 1:Na
    move_factor = lambda^2*fa(k)^2/(8*v_x^2);
    shift_R = R_axis*move_factor;
    s_rcmc(k,:) = interp1(R_axis,S_az(k,:), ...
        R_axis+shift_R,'spline',0);
end

% 方位压缩
H_az = exp(1j*pi*fa.^2/Ka);
S_foc = s_rcmc.*repmat(H_az,1,Nr);
img = ifft(S_foc,[],1);

%% 9. 显示结果
R_relative = R_axis-R0;
az_axis = tm*v_x;

img_abs = abs(img);
img_db = 20*log10(img_abs/max(img_abs(:))+eps);

figure('Color','w','Name','四块 1-bit 超表面舰船假目标');
imagesc(R_relative,az_axis,img_db,[-25,0]);
set(gca,'YDir','normal');
axis image; colormap turbo; colorbar;
xlabel('相对斜距位置 (m)');
ylabel('相对方位向位置 (m)');
title('四块初始位置 + 1-bit 脉内/脉间编码的舰船假目标');
xlim([-45,45]);
ylim([-80,80]);

%% 10. 显示四块真实初始位置
panel_R_relative = R_panel0-R0;

figure('Color','w','Name','四块物理超表面初始位置');
scatter(panel_R_relative,panel_centers(:,1), ...
    100+50*panel_amp,'filled','MarkerEdgeColor','k');
hold on;
for g = 1:num_panels
    text(panel_R_relative(g)+0.8,panel_centers(g,1), ...
        sprintf('%d %s',g,panel_names{g}), ...
        'FontSize',10,'VerticalAlignment','middle');
end
axis equal; grid on;
xlabel('相对斜距位置 (m)');
ylabel('相对方位向位置 (m)');
title('四块超表面的真实初始位置');
set(gca,'YDir','normal');
xlim([-20,20]);
ylim([-65,65]);

%% 11. 保存数据，方便后续对比和调参
save('SHIP_false_ship_1bit_4panel_result.mat', ...
    'img','img_db','R_relative','az_axis','sr_total', ...
    'panel_centers','panel_names','panel_amp','pss_configs', ...
    'fc','lambda','Tp','Br','Kr','H0','v_x','R0','PRF_actual');

fprintf('仿真完成，结果已保存为 SHIP_false_ship_1bit_4panel_result.mat。\n');
fprintf('所有时间编码状态均严格为 0/pi。\n');
