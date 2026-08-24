%% ideal_1bit_phase_harmonic_demo.m
% 理想 1-bit 时间相位编码：谐波产生与等效多普勒演示
%
% 目的：
% 1) 假设两个理想反射状态等幅，且相位差严格为 180°：
%       Gamma0 = 1∠0° = +1
%       Gamma1 = 1∠180° = -1
% 2) 按 50% 占空比周期切换，形成零均值方波反射系数 Gamma(t)
% 3) 计算 Gamma(t) 的傅里叶级数/FFT，观察载波抑制与谐波分布
% 4) 说明谐波 k*f0 对应反射波频率 fc+k*f0，即等效多普勒
%
% 不需要任何额外工具箱。
% 运行后会在 output_figures 文件夹中生成 4 张图片。

clear; clc; close all;

%% 1. 基本参数
c  = 299792458;             % 光速，m/s
fc = 5.661e9;               % 示例载频，Hz（可改成你的工作频率）
f0 = 200;                   % 时间调制频率，Hz
T0 = 1/f0;                  % 时间调制周期，s

Gamma0 = 1.0 * exp(1j*0);   % 状态 0：幅度 1，相位 0°
Gamma1 = 1.0 * exp(1j*pi);  % 状态 1：幅度 1，相位 180°

% 为保证 FFT 谐波正好落在频率栅格上，每个周期取整数个采样点
samplesPerPeriod = 1024;
numPeriods       = 32;
fs               = f0 * samplesPerPeriod;
N                = samplesPerPeriod * numPeriods;
t                = (0:N-1)/fs;

%% 2. 构造理想 1-bit 周期相位编码
% 每个周期前半段为 Gamma0=+1，后半段为 Gamma1=-1
phaseInPeriod = mod(t, T0);
bitCode = phaseInPeriod >= T0/2;      % 前半周期 0，后半周期 1

Gamma = Gamma0 * ones(size(t));
Gamma(bitCode) = Gamma1;

% 反射系数公式：
% Gamma(t) = +1, 0 <= mod(t,T0) < T0/2
%          = -1, T0/2 <= mod(t,T0) < T0

%% 3. 理论傅里叶级数系数
% Gamma(t) = sum_k a_k exp(j*2*pi*k*f0*t)
% 对于该 50% 占空比、±1 方波：
% a_0 = 0
% a_k = [1-(-1)^k]/(j*pi*k), k ~= 0
%
% 因此：
% - 零阶谐波为 0（载波抑制）
% - 偶数阶为 0
% - 只有奇数阶非零
% - 正负一阶各占总功率 4/pi^2 ≈ 40.53%
% - 正负一阶合计占总功率 8/pi^2 ≈ 81.06%

Kmax = 11;
k = -Kmax:Kmax;
akTheory = zeros(size(k));

for ii = 1:numel(k)
    if k(ii) == 0
        akTheory(ii) = 0;
    else
        akTheory(ii) = (1 - (-1)^k(ii)) / (1j*pi*k(ii));
    end
end

%% 4. 数值 FFT 验证
G = fftshift(fft(Gamma))/N;
f = ((-N/2):(N/2-1))*(fs/N);

% 从 FFT 中读取各个整数阶谐波 k*f0
akFFT = zeros(size(k));
for ii = 1:numel(k)
    [~, idx] = min(abs(f - k(ii)*f0));
    akFFT(ii) = G(idx);
end

%% 5. 功率统计
powerTheory = abs(akTheory).^2;
firstOrderEach = 4/pi^2 * 100;
firstOrderPair = 8/pi^2 * 100;

lambda = c/fc;
equivVelocity = lambda*(k*f0)/2;   % 单基地雷达：fd = 2v/lambda

fprintf('\n========== 理想 1-bit 相位编码结果 ==========\n');
fprintf('载频 fc              = %.6f GHz\n', fc/1e9);
fprintf('调制频率 f0          = %.3f Hz\n', f0);
fprintf('调制周期 T0          = %.6f ms\n', T0*1e3);
fprintf('Gamma0               = %.2f ∠ %.1f°\n', abs(Gamma0), angle(Gamma0)*180/pi);
fprintf('Gamma1               = %.2f ∠ %.1f°\n', abs(Gamma1), angle(Gamma1)*180/pi);
fprintf('零阶谐波功率          = %.6f %%\n', 100*abs(akTheory(k==0))^2);
fprintf('正一阶谐波功率        = %.2f %%\n', firstOrderEach);
fprintf('负一阶谐波功率        = %.2f %%\n', firstOrderEach);
fprintf('正负一阶合计功率      = %.2f %%\n', firstOrderPair);
fprintf('±f0 对应等效径向速度 = ±%.3f m/s\n', lambda*f0/2);
fprintf('=============================================\n\n');

%% 6. 输出目录
outDir = fullfile(fileparts(mfilename('fullpath')), 'output_figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 图 1：两个理想 1-bit 反射状态
fig1 = figure('Color','w','Position',[100 100 1100 500]);

subplot(1,2,1);
th = linspace(0,2*pi,500);
plot(cos(th),sin(th),'k--','LineWidth',1); hold on;
quiver(0,0,real(Gamma0),imag(Gamma0),0,'LineWidth',2.5,'MaxHeadSize',0.15);
quiver(0,0,real(Gamma1),imag(Gamma1),0,'LineWidth',2.5,'MaxHeadSize',0.15);
plot(real(Gamma0),imag(Gamma0),'o','MarkerSize',8,'LineWidth',2);
plot(real(Gamma1),imag(Gamma1),'s','MarkerSize',8,'LineWidth',2);
axis equal; grid on;
xlim([-1.25 1.25]); ylim([-1.25 1.25]);
xlabel('Re\{\Gamma\}'); ylabel('Im\{\Gamma\}');
title('理想 1-bit 反射状态（复平面）');
legend('单位圆','\Gamma_0','\Gamma_1','状态 0','状态 1','Location','best');

subplot(1,2,2);
axis off;
text(0.02,0.88,'理想反射系数','FontSize',16,'FontWeight','bold');
text(0.02,0.68,'\Gamma_0 = 1e^{j0^\circ} = +1','FontSize',17,'Interpreter','tex');
text(0.02,0.52,'\Gamma_1 = 1e^{j180^\circ} = -1','FontSize',17,'Interpreter','tex');
text(0.02,0.34,'|\Gamma_0| = |\Gamma_1| = 1','FontSize',16,'Interpreter','tex');
text(0.02,0.18,'\angle\Gamma_1-\angle\Gamma_0 = 180^\circ','FontSize',16,'Interpreter','tex');
text(0.02,0.04,'结论：这是等幅度的 1-bit 相位调制。','FontSize',15);

saveas(fig1, fullfile(outDir,'01_ideal_1bit_states.png'));

%% 图 2：反射系数的时域编码
showPeriods = 3;
showN = showPeriods*samplesPerPeriod;
tShow = t(1:showN)*1e3;

fig2 = figure('Color','w','Position',[100 100 1200 850]);

subplot(4,1,1);
stairs(tShow, double(bitCode(1:showN)),'LineWidth',1.8);
ylim([-0.2 1.2]); grid on;
ylabel('编码位');
title('理想 1-bit 时间相位编码');
yticks([0 1]);

subplot(4,1,2);
plot(tShow, abs(Gamma(1:showN)),'LineWidth',1.8);
ylim([0 1.2]); grid on;
ylabel('|\Gamma(t)|');
title('幅度始终保持为 1');

subplot(4,1,3);
phaseDeg = mod(angle(Gamma(1:showN))*180/pi,360);
stairs(tShow, phaseDeg,'LineWidth',1.8);
ylim([-20 200]); grid on;
yticks([0 180]);
ylabel('相位 / °');
title('相位在 0° 与 180° 之间切换');

subplot(4,1,4);
stairs(tShow, real(Gamma(1:showN)),'LineWidth',1.8);
ylim([-1.3 1.3]); grid on;
ylabel('Re\{\Gamma(t)\}');
xlabel('时间 / ms');
title('\Gamma(t)=+1/-1 的零均值周期方波');

saveas(fig2, fullfile(outDir,'02_time_domain_phase_code.png'));

%% 图 3：谐波幅度与功率
fig3 = figure('Color','w','Position',[100 100 1200 600]);

subplot(1,2,1);
stem(k,abs(akTheory),'filled','LineWidth',1.5); hold on;
plot(k,abs(akFFT),'o','LineWidth',1.2,'MarkerSize',6);
grid on;
xlabel('谐波阶数 k');
ylabel('|a_k|');
title('反射系数的谐波幅度');
legend('理论傅里叶级数','数值 FFT','Location','best');
xticks(k);

subplot(1,2,2);
stem(k,100*powerTheory,'filled','LineWidth',1.5);
grid on;
xlabel('谐波阶数 k');
ylabel('功率占比 / %');
title('各阶谐波功率分布');
xticks(k);
ylim([0 45]);

annotation(fig3,'textbox',[0.34 0.01 0.34 0.10],...
    'String',sprintf(['零阶谐波 = 0；偶数阶 = 0；\n',...
    '±1 阶各占 %.2f%%，合计 %.2f%%'],firstOrderEach,firstOrderPair),...
    'HorizontalAlignment','center','EdgeColor','none','FontSize',12);

saveas(fig3, fullfile(outDir,'03_harmonic_spectrum.png'));

%% 图 4：频率搬移与等效多普勒
fig4 = figure('Color','w','Position',[100 100 1200 650]);

subplot(2,1,1);
stem(0,1,'filled','LineWidth',2); grid on;
xlim([-Kmax*f0-100, Kmax*f0+100]);
ylim([0 1.2]);
xlabel('相对载频的频率偏移 / Hz');
ylabel('归一化幅度');
title(sprintf('入射单频波：E_i(t)=E_0e^{j2\\pi f_ct}，仅位于 f_c（偏移 0 Hz）'));

subplot(2,1,2);
stem(k*f0,abs(akTheory),'filled','LineWidth',1.6);
grid on;
xlabel('相对载频的频率偏移 kf_0 / Hz');
ylabel('|a_k|');
title('反射波频率：f_c+kf_0；非零谐波可解释为等效多普勒');
xlim([-Kmax*f0-100, Kmax*f0+100]);

% 标注正负一阶
hold on;
plot([f0 f0],[0 abs(akTheory(k==1))],'--','LineWidth',1);
plot([-f0 -f0],[0 abs(akTheory(k==-1))],'--','LineWidth',1);
text(f0,abs(akTheory(k==1))+0.05,...
    sprintf('+f_0 = +%.0f Hz\\n等效速度 +%.2f m/s',f0,lambda*f0/2),...
    'HorizontalAlignment','left');
text(-f0,abs(akTheory(k==-1))+0.05,...
    sprintf('-f_0 = -%.0f Hz\\n等效速度 -%.2f m/s',f0,lambda*f0/2),...
    'HorizontalAlignment','right');

saveas(fig4, fullfile(outDir,'04_frequency_shift_and_doppler.png'));

%% 7. 保存关键结果表
resultTable = table(k(:), abs(akTheory(:)), 100*powerTheory(:), ...
    (k(:)*f0), equivVelocity(:), ...
    'VariableNames',{'HarmonicOrder_k','Magnitude_abs_ak',...
    'PowerPercent','FrequencyOffset_Hz','EquivalentVelocity_mps'});

writetable(resultTable, fullfile(outDir,'harmonic_results.csv'));

fprintf('运行完成。结果已保存到：\n%s\n', outDir);
fprintf('生成文件：\n');
fprintf('  01_ideal_1bit_states.png\n');
fprintf('  02_time_domain_phase_code.png\n');
fprintf('  03_harmonic_spectrum.png\n');
fprintf('  04_frequency_shift_and_doppler.png\n');
fprintf('  harmonic_results.csv\n');
