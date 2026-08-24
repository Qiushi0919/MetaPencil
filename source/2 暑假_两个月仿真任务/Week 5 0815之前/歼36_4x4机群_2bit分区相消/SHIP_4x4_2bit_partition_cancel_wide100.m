%% 单极化2-bit 4×4局部超单元：主要十字谐波相干抵消试验
% 每架歼-36表面周期重复同一套4×4局部超单元。
% 16个P_pq组合由4个距离编码时延和4个方位编码时延的笛卡尔积构成；
% 每个物理子单元仍只使用0/90/180/270度四种单极化反射状态。
%
% 理想候选归一化时延：d=[0, 1/10, 5/6, 14/15]T。
% 对单维分区因子S_n，理论上S_-3=0、S_+5=0，且|S_+1|约0.8236。

clear; clc; close all;

two_bit_state_dwell_fraction = [0.25, 0.25, 0.25, 0.25];
two_bit_partition_delay_fraction = [0, 1/10, 5/6, 14/15];

two_bit_case_tag = '2bit_partition_cancel_wide100';
two_bit_case_title = '单极化2-bit 4×4局部超单元相干抵消';
two_bit_result_description = ...
    '保留中央(+1,+1)的2×2假目标，抑制(-3,+1)/(+5,+1)/(+1,-3)/(+1,+5)十字副像';

two_bit_full_half_width_m = 100;
two_bit_az_resolution_override_m = 0.075;
two_bit_harmonic_max_order = 15;

entry_dir = fileparts(mfilename('fullpath'));
two_bit_output_root_override = fullfile( ...
    entry_dir, 'results_4x4_2bit_partition_cancel_wide100');

core_file = fullfile(entry_dir, '..', '..', ...
    'Week 4 0813之前', '歼36_4x4机群_sar_code_2D', ...
    'SHIP_4x4_ssb_2bit.m');
if ~isfile(core_file)
    error('找不到公共完整SAR核心脚本：%s', core_file);
end

run(core_file);
