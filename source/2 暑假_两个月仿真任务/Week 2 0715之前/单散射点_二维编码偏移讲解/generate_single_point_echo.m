function [raw_base, axes_data] = generate_single_point_echo(cfg)
%GENERATE_SINGLE_POINT_ECHO 生成一个静止点目标的条带 SAR 原始回波。
%
% 输出：
%   raw_base : Na x Nr，未编码的二维复回波
%   axes_data.eta : 慢时间（列向量）
%   axes_data.t   : 快时间（行向量）
%   axes_data.tau : 相对每个脉冲回波中心的时间，Na x Nr
%
% 这一函数对应 SHIP.m 第 8 节中 s_pulse_base 的计算，但这里只保留
% 一个散射点，因此不再需要目标点循环。

c = cfg.c;

% 慢时间采样。Na 直接由合成孔径长度决定，不用 linspace，因而实际
% PRF 就严格等于 cfg.PRF。
Na = round((cfg.az_aperture/cfg.v)*cfg.PRF);
if mod(Na, 2) ~= 0
    Na = Na + 1;
end
eta = ((0:Na-1) - Na/2).' / cfg.PRF;
x_radar = cfg.v*eta;

% 快时间窗口必须容纳完整 Tp 脉冲，同时给中心斜距两侧留出显示范围。
fast_duration = cfg.Tp + 4*cfg.range_half_span/c;
Nr = ceil(fast_duration*cfg.Fs);
if mod(Nr, 2) ~= 0
    Nr = Nr + 1;
end
t = 2*cfg.R0/c + ((0:Nr-1) - Nr/2)/cfg.Fs;

% 每个慢时间位置处，雷达到唯一散射点的瞬时斜距和双程时延。
r_inst = sqrt((cfg.target_az - x_radar).^2 + cfg.Y0^2 + cfg.H0^2);
delay = 2*r_inst/c;

% tau(k,n) = 第 k 个脉冲、第 n 个快时间采样点相对回波中心的时间。
tau = bsxfun(@minus, t, delay);
pulse_gate = abs(tau) <= cfg.Tp/2;

% 线性调频脉冲和传播相位。
range_chirp = exp(1j*pi*cfg.Kr*tau.^2);
carrier_phase = exp(-1j*4*pi*r_inst/cfg.lambda);

raw_base = cfg.target_amp .* pulse_gate .* range_chirp .* ...
    repmat(carrier_phase, 1, Nr);

axes_data.eta = eta;
axes_data.x_radar = x_radar;
axes_data.t = t;
axes_data.tau = tau;

fprintf('原始回波尺寸：Na = %d，Nr = %d\n', Na, Nr);
end

