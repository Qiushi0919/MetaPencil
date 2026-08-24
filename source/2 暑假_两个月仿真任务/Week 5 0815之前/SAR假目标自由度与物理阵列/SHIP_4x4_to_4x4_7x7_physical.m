%% 四角4架歼-36 -> 7×7整数控制超单元 -> 4×4共16架目标群
% 7×7最小控制超单元在距离和方位两个维度均采用：
%   [DC, DC, DC, d1, d2, d3, d4]
% 因而未调制面积比例为3/7，2-bit分区调制面积比例为4/7。
% 这不是连续的“42.58%面积”近似，而是可以直接布线的49组整数分区。

clear; clc; close all;

two_bit_state_dwell_fraction = [0.25, 0.25, 0.25, 0.25];
two_bit_partition_delay_fraction = [0, 1/10, 5/6, 14/15];
two_bit_dc_branch_fraction = 3/7;

two_bit_case_tag = '2bit_7x7_physical_4x4_group_cancel_wide100';
two_bit_case_title = '7×7整数超单元：等幅4×4目标群与主要十字谐波相消';
two_bit_result_description = [ ...
    '每维3个DC组+4个循环时延组；四角4架形成16架目标，' ...
    '同时抑制(-3,+1)/(+5,+1)/(+1,-3)/(+1,+5)十字副像'];

two_bit_full_half_width_m = 100;
two_bit_az_resolution_override_m = 0.075;
two_bit_harmonic_max_order = 15;

entry_dir = fileparts(mfilename('fullpath'));
two_bit_output_root_override = fullfile(entry_dir, ...
    'results_full_rd_7x7_physical');

base_plus1_amplitude = 2*sqrt(2)/pi;
partition_plus1_amplitude = abs(mean(exp( ...
    -1j*2*pi*two_bit_partition_delay_fraction)));
effective_plus1 = (4/7)*base_plus1_amplitude*partition_plus1_amplitude;

fprintf('7×7整数面积：DC=3/7=%.6f，调制=4/7=%.6f\n', ...
    two_bit_dc_branch_fraction, 1-two_bit_dc_branch_fraction);
fprintf('一维：|H0|=%.6f，|H+1|=%.6f，幅度差=%.3f dB\n', ...
    two_bit_dc_branch_fraction, effective_plus1, ...
    20*log10(effective_plus1/two_bit_dc_branch_fraction));
fprintf('二维：A00=%.6f，A01=A10=%.6f，A11=%.6f\n', ...
    two_bit_dc_branch_fraction^2, ...
    two_bit_dc_branch_fraction*effective_plus1, effective_plus1^2);

core_file = fullfile(entry_dir, '..', '..', ...
    'Week 4 0813之前', '歼36_4x4机群_sar_code_2D', ...
    'SHIP_4x4_ssb_2bit.m');
if ~isfile(core_file)
    error('找不到公共完整SAR核心脚本：%s', core_file);
end

run(core_file);
