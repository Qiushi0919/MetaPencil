%% MetaPencil 最小烟雾测试
% 验证三个低计算量但代表当前核心逻辑的环节：
% 1) 平衡2-bit四相位序列的傅里叶系数；
% 2) 4时延分区对-3/+5阶的复相量零陷；
% 3) 单机1->2的整数宏格面积分配与距离/方位偏移频率映射。
% 本测试不运行700点完整原始回波，因此不是论文图的重算。

clear; clc; close all;
test_start = tic;
script_dir = fileparts(mfilename('fullpath'));
handoff_root = fileparts(script_dir);
log_dir = fullfile(handoff_root,'logs');
output_dir = fullfile(handoff_root,'outputs','latest');
if ~exist(log_dir,'dir'), mkdir(log_dir); end
if ~exist(output_dir,'dir'), mkdir(output_dir); end

orders = (-15:15).';
states = exp(1j*(0:3)*pi/2);
edges = linspace(0,2*pi,5);
base_coeff = arrayfun(@(n) steppedCoefficient(n,states,edges),orders);
delays = [0,1/10,5/6,14/15];
partition_factor = arrayfun(@(n) mean(exp(-1j*2*pi*n*delays)),orders);
final_coeff = base_coeff.*partition_factor;

C1 = base_coeff(orders==1);
S1 = partition_factor(orders==1);
Sm3 = partition_factor(orders==-3);
Sp5 = partition_factor(orders==5);
eta_1d = abs(C1*S1);
eta_2d = eta_1d^2;

assert(abs(abs(C1)-2*sqrt(2)/pi)<1e-12,'2-bit +1阶系数不符。');
assert(abs(Sm3)<1e-12,'-3阶未形成数值零陷。');
assert(abs(Sp5)<1e-12,'+5阶未形成数值零陷。');
assert(abs(abs(S1)-0.823639103546332)<1e-12,'+1阶分区因子不符。');

% 单机1->2：4×4外层宏格按蛇形交织分成两个等面积通道。
tile_map = [1 2 1 2;2 1 2 1;1 2 1 2;2 1 2 1];
counts = [nnz(tile_map==1),nnz(tile_map==2)];
weights = counts/numel(tile_map);
assert(all(counts==8) && max(abs(weights-0.5))<eps,'1->2面积分配不平衡。');
target_amplitude = eta_2d*weights;

% 使用当前完整入口的默认参数验证(+/-8 m,+/-8 m)的频率映射。
c = 3e8; fc = 10e9; lambda = c/fc; Tp = 1e-6;
beta = deg2rad(60); H0 = 500; v = 80; R0 = hypot(H0,H0*tan(beta));
ground_resolution = 0.25;
Br = c/(2*ground_resolution*sin(beta));
Kr = Br/Tp;
Ka = -2*v^2/(lambda*R0);
offsets = [-8,8;8,8];
range_frequency_hz = -2*Kr*(offsets(:,1)*sin(beta))/c;
azimuth_frequency_hz = -Ka*offsets(:,2)/v;
assert(max(abs(abs(range_frequency_hz)-32e6))<1e-6,'距离频移映射不符。');
assert(max(abs(azimuth_frequency_hz-42.6666666666667))<1e-9,'方位频移映射不符。');

result_table = table(orders,abs(base_coeff),abs(partition_factor),abs(final_coeff), ...
    20*log10(abs(final_coeff)+eps), ...
    'VariableNames',{'order','base_amplitude','partition_amplitude', ...
    'final_amplitude','final_amplitude_db'});
writetable(result_table,fullfile(log_dir,'smoke_harmonic_coefficients.csv'));

fig = figure('Color','w','Visible','off','Position',[100,100,1100,430]);
tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
nexttile;
stem(orders,20*log10(abs(base_coeff)+eps),'filled','LineWidth',1.1);
grid on;xlim([-15.5,15.5]);ylim([-50,2]);
xlabel('谐波阶次 n');ylabel('幅度 / dB');title('平衡2-bit基线');
nexttile;
stem(orders,20*log10(abs(final_coeff)+eps),'filled','LineWidth',1.1);
grid on;xlim([-15.5,15.5]);ylim([-50,2]);
xlabel('谐波阶次 n');ylabel('幅度 / dB');title('4时延分区相消后');
exportgraphics(fig,fullfile(output_dir,'smoke_harmonic_suppression.png'), ...
    'Resolution',160);
close(fig);

elapsed = toc(test_start);
fprintf('SMOKE_TEST_STATUS=PASS\n');
fprintf('MATLAB_VERSION=%s\n',version);
fprintf('|C+1|=%.12f\n',abs(C1));
fprintf('|S+1|=%.12f\n',abs(S1));
fprintf('|S-3|=%.3e\n',abs(Sm3));
fprintf('|S+5|=%.3e\n',abs(Sp5));
fprintf('|A(+1,+1)|=%.12f (%.3f dB)\n',eta_2d,20*log10(eta_2d));
fprintf('1to2_each_amplitude=[%.12f %.12f]\n',target_amplitude);
fprintf('range_frequency_hz=[%.3f %.3f]\n',range_frequency_hz);
fprintf('azimuth_frequency_hz=[%.6f %.6f]\n',azimuth_frequency_hz);
fprintf('ELAPSED_SECONDS=%.6f\n',elapsed);

function coefficient = steppedCoefficient(order,states,edges)
    if order==0
        coefficient=mean(states);
        return;
    end
    coefficient=0;
    for state_index=1:4
        slot_integral=(exp(-1j*order*edges(state_index+1))- ...
            exp(-1j*order*edges(state_index)))/(-1j*order);
        coefficient=coefficient+states(state_index)*slot_integral/(2*pi);
    end
end
