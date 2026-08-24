function [img, image_axes] = rd_focus_single_point(raw, axes_data, cfg)
%RD_FOCUS_SINGLE_POINT 用 RD 算法对编码后的单点回波成像。
%
% 处理顺序与 SHIP.m 相同：
%   距离匹配滤波 -> 方位 FFT -> RCMC -> 方位匹配滤波 -> 方位 IFFT

[Na, Nr] = size(raw);

%% 1. 距离压缩
t_ref = ((0:Nr-1) - Nr/2)/cfg.Fs;
h_range = exp(1j*pi*cfg.Kr*t_ref.^2) .* (abs(t_ref) <= cfg.Tp/2);

% ifftshift 把参考信号的零时刻放到数组第一个元素，相关峰才能落回
% 原回波中心所对应的距离单元。
H_range = conj(fft(ifftshift(h_range)));
s_rc = ifft(fft(raw, [], 2) .* repmat(H_range, Na, 1), [], 2);

%% 2. 方位 FFT
S_az = fftshift(fft(ifftshift(s_rc, 1), [], 1), 1);
fa = ((0:Na-1) - Na/2).' * (cfg.PRF/Na);

R_axis = axes_data.t*cfg.c/2;

%% 3. 距离徙动校正 RCMC
s_rcmc = zeros(size(S_az));
for k = 1:Na
    move_factor = cfg.lambda^2*fa(k)^2/(8*cfg.v^2);
    shift_R = R_axis*move_factor;
    s_rcmc(k,:) = interp1(R_axis, S_az(k,:), ...
        R_axis + shift_R, 'linear', 0);
end

%% 4. 方位压缩
H_az = exp(1j*pi*fa.^2/cfg.Ka);
S_focused = s_rcmc .* repmat(H_az, 1, Nr);
img = fftshift(ifft(ifftshift(S_focused, 1), [], 1), 1);

image_axes.range_offset = R_axis - cfg.R0;
image_axes.azimuth = axes_data.x_radar;
end

