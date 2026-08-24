%% 2-bit 30/70非平衡编码：距离/方位各±100 m视场
% 四状态对应0/90/180/270度，两个控制位均满足
% P(0)=30%、P(1)=70%，所以驻留比例为9%/21%/21%/49%。

two_bit_state_dwell_fraction = [0.09, 0.21, 0.21, 0.49];
two_bit_case_tag = '2bit_30_70_wide100';
two_bit_case_title = '2-bit 30/70非平衡四相位编码';
two_bit_result_description = ...
    '距离向和方位向各±100 m，观察更高阶谐波假目标';

% 原版方位轴约为±50 m。将理论方位分辨率从0.15 m提高到
% 0.075 m，使合成孔径长度翻倍，从而得到约±100 m的实际方位数据。
two_bit_full_half_width_m = 100;
two_bit_az_resolution_override_m = 0.075;
two_bit_harmonic_max_order = 15;

script_dir_wide100 = fileparts(mfilename('fullpath'));
run(fullfile(script_dir_wide100, 'SHIP_4x4_ssb_2bit.m'));
