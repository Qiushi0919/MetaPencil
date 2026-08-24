%% 2-bit平衡四相位编码：距离/方位各±100 m完整SAR仿真
% 四个反射状态依次为0/90/180/270度，各占一个调制周期的25%。
% 使用长合成孔径重新生成原始回波，并执行完整的距离压缩、
% RCMC和方位压缩，最终显示±100 m、0至-30 dB的SAR结果。

two_bit_state_dwell_fraction = [0.25, 0.25, 0.25, 0.25];
two_bit_case_tag = '2bit_balanced_wide100';
two_bit_case_title = '2-bit平衡四相位SSB编码';
two_bit_result_description = ...
    '距离向和方位向各±100 m，零阶与反向一阶理论抑制';

two_bit_full_half_width_m = 100;
two_bit_az_resolution_override_m = 0.075;
two_bit_harmonic_max_order = 15;

script_dir_balanced_wide100 = fileparts(mfilename('fullpath'));
run(fullfile(script_dir_balanced_wide100, 'SHIP_4x4_ssb_2bit.m'));
