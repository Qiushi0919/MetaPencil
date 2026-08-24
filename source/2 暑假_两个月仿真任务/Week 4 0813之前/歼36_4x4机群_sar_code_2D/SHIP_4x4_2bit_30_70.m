%% 2-bit 30/70非平衡四相位编码入口
% 将四相位状态按二进制标记为00/01/10/11。若两个控制位都满足
% P(0)=30%、P(1)=70%，并按独立位组合，则单维四状态驻留比例为：
%   00: 0.3*0.3 = 9%
%   01: 0.3*0.7 = 21%
%   10: 0.7*0.3 = 21%
%   11: 0.7*0.7 = 49%
% 对应复反射相位依次为0/90/180/270度。

two_bit_state_dwell_fraction = [0.09, 0.21, 0.21, 0.49];
two_bit_case_tag = '2bit_30_70';
two_bit_case_title = '2-bit 30/70非平衡四相位编码';
two_bit_result_description = ...
    '两控制位均0/1=30%/70%，零阶和反向谐波不再完全抑制';

script_dir_30_70 = fileparts(mfilename('fullpath'));
run(fullfile(script_dir_30_70, 'SHIP_4x4_ssb_2bit.m'));
