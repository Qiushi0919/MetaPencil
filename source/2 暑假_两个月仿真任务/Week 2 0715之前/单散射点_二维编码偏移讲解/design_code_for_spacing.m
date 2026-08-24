function [fast_cycles, slow_period_samples, actual] = ...
    design_code_for_spacing(desired_range_spacing, desired_az_spacing, cfg)
%DESIGN_CODE_FOR_SPACING 根据期望的二维间距，反算最接近的整数码参数。
%
% 示例（cfg 与主脚本相同）：
%   [Nfast, Lslow, actual] = design_code_for_spacing(5, 30, cfg)
%
% 输出：
%   Nfast  -> 填入 fast_cycles
%   Lslow  -> 填入 slow_period_samples
%   actual -> 由于码周期必须取整数，实际可以得到的间距
%
% 注意：期望间距不能任意精确实现，因为 fast_cycles 和
% slow_period_samples 最后都必须是整数。

arguments
    desired_range_spacing (1,1) double {mustBePositive}
    desired_az_spacing (1,1) double {mustBePositive}
    cfg (1,1) struct
end

% Delta_R = c*Nfast/(2*Br)
fast_cycles = max(1, round(2*cfg.Br*desired_range_spacing/cfg.c));

% Delta_x = v*PRF/(|Ka|*Lslow)
slow_period_samples = max(3, round( ...
    cfg.v*cfg.PRF/(abs(cfg.Ka)*desired_az_spacing)));

actual.range_spacing = cfg.c*fast_cycles/(2*cfg.Br);
actual.az_spacing = cfg.v*cfg.PRF/(abs(cfg.Ka)*slow_period_samples);

fprintf('期望距离向间距 %.3f m -> fast_cycles = %d -> 实际 %.3f m\n', ...
    desired_range_spacing, fast_cycles, actual.range_spacing);
fprintf('期望方位向间距 %.3f m -> slow_period_samples = %d -> 实际 %.3f m\n', ...
    desired_az_spacing, slow_period_samples, actual.az_spacing);
end

