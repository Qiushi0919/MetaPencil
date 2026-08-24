function [raw_coded, info] = apply_2d_1bit_code( ...
    raw_base, tau, cfg, fast_cycles, slow_period_samples)
%APPLY_2D_1BIT_CODE 对单点回波施加快时间和慢时间二维 0/pi 相位编码。
%
% fast_cycles：
%   [0,0,pi] 在一个 Tp 内完整重复的次数。次数越多，快时间基频越高，
%   距离压缩后复制点之间的距离向间距越大。
%
% slow_period_samples：
%   一个慢时间码周期包含的脉冲数。周期越短，慢时间基频越高，方位
%   压缩后复制点之间的方位向间距越大。
%
% 两个编码都只有 exp(j*0)=+1 和 exp(j*pi)=-1，是真正的 1-bit 相位码。

[Na, Nr] = size(raw_base);

if fast_cycles <= 0 || slow_period_samples <= 0
    raw_coded = raw_base;
    info.fast_f0 = 0;
    info.slow_f0 = 0;
    info.range_spacing = 0;
    info.az_spacing = 0;
    return;
end

%% 1. 快时间周期码
% 一个基础周期分成 3 个 chip：[0, 0, pi]。
base_fast_phase = [0, 0, pi];
chips_per_period = numel(base_fast_phase);
chip_width = cfg.Tp/(fast_cycles*chips_per_period);

% 把 tau=-Tp/2 映射到脉冲内位置 0，再判断它属于哪一个 chip。
pulse_position = tau + cfg.Tp/2;
inside_pulse = (pulse_position >= 0) & (pulse_position <= cfg.Tp);

fast_mod = ones(Na, Nr);
chip_number = floor(pulse_position(inside_pulse)/chip_width);
chip_number(chip_number >= fast_cycles*chips_per_period) = ...
    fast_cycles*chips_per_period - 1;
base_index = mod(chip_number, chips_per_period) + 1;
fast_mod(inside_pulse) = exp(1j*base_fast_phase(base_index));

%% 2. 慢时间周期码
% 每个周期前 2/3 为 0 相位，后 1/3 为 pi 相位。
slow_index = mod(0:Na-1, slow_period_samples);
n_zero = round(2*slow_period_samples/3);
slow_phase = pi*(slow_index >= n_zero);
slow_mod = exp(1j*slow_phase).';

%% 3. 二维编码
raw_coded = raw_base .* fast_mod .* repmat(slow_mod, 1, Nr);

%% 4. 由码周期直接预报图像中的复制间距
info.fast_f0 = fast_cycles/cfg.Tp;
info.range_spacing = cfg.c*info.fast_f0/(2*abs(cfg.Kr));

info.slow_f0 = cfg.PRF/slow_period_samples;
info.az_spacing = cfg.v*info.slow_f0/abs(cfg.Ka);
end

