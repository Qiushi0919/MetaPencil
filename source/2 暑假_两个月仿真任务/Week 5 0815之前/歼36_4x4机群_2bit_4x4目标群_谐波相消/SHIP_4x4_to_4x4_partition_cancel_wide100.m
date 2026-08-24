%% 四角4架歼-36 -> 4×4共16架目标群，同时抑制主要十字谐波
% 一维同时保留n=0和n=+1：
%   1) 未调制空间支路产生n=0；
%   2) 平衡2-bit四相位支路产生n=+1；
%   3) 调制支路再使用4个循环时延，使n=-3和n=+5相干抵消。
% 距离、方位两维的{0,+1}做笛卡尔积，每架真实飞机产生
% (0,0)/(0,1)/(1,0)/(1,1)四个像，四架合计为4×4=16架。

clear; clc; close all;

two_bit_state_dwell_fraction = [0.25, 0.25, 0.25, 0.25];
two_bit_partition_delay_fraction = [0, 1/10, 5/6, 14/15];

% 平衡2-bit四相位阶梯的理论|C+1|，以及四时延分区的|S+1|。
% 选择w0=w1*|C+1*S+1|，使一维0阶和+1阶幅度相同。
base_plus1_amplitude = 2*sqrt(2)/pi;
partition_plus1_amplitude = abs(mean(exp( ...
    -1j*2*pi*two_bit_partition_delay_fraction)));
modulated_plus1_efficiency = ...
    base_plus1_amplitude*partition_plus1_amplitude;
two_bit_dc_branch_fraction = modulated_plus1_efficiency / ...
    (1+modulated_plus1_efficiency);

two_bit_case_tag = '2bit_4x4_target_group_partition_cancel_wide100';
two_bit_case_title = '2-bit等幅4×4目标群与主要十字谐波相消';
two_bit_result_description = [ ...
    '四角4架通过0/+1阶组合形成4×4共16架目标，' ...
    '同时抑制(-3,+1)/(+5,+1)/(+1,-3)/(+1,+5)主要十字副像'];

two_bit_full_half_width_m = 100;
two_bit_az_resolution_override_m = 0.075;
two_bit_harmonic_max_order = 15;

entry_dir = fileparts(mfilename('fullpath'));
two_bit_output_root_override = fullfile(entry_dir, ...
    'results_4x4_target_group_partition_cancel_wide100');

fprintf('等幅面积分配：未调制支路 %.4f，分区调制支路 %.4f\n', ...
    two_bit_dc_branch_fraction, 1-two_bit_dc_branch_fraction);
fprintf('理论一维0/+1阶幅度均为 %.6f\n', ...
    two_bit_dc_branch_fraction);
fprintf('理论二维四种目标组合幅度均为 %.6f（相对未调制单机 %.2f dB）\n', ...
    two_bit_dc_branch_fraction^2, ...
    20*log10(two_bit_dc_branch_fraction^2));

core_file = fullfile(entry_dir, '..', '..', ...
    'Week 4 0813之前', '歼36_4x4机群_sar_code_2D', ...
    'SHIP_4x4_ssb_2bit.m');
if ~isfile(core_file)
    error('找不到公共完整SAR核心脚本：%s', core_file);
end

run(core_file);
