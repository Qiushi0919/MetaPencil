%% 1-bit 时间调制超表面阵列：多目标方向自动编码
% 使用方法：
% 1) 初步理想仿真时，只修改 tar；
% 2) 得到 CST 单元结果后，再把 Gamma0、Gamma1 替换成真实复反射系数；
% 3) 程序自动生成每个单元的 0/1 时间序列、谐波系数和方向图。
%
% tar 每一行格式：
% [theta_deg, phi_deg, relative_amplitude]
% theta：相对阵面法线（broadside）的夹角，0~90 deg
% phi：阵面内方位角，-180~180 deg
% relative_amplitude：目标相对场强权重
%
% 阵面位于 x-y 平面，法线沿 +z；默认优化 +1 阶谐波。

clear; clc; close all;

%% ===================== 用户主要修改区 =====================

% 目标散射方向：[theta(deg), phi(deg), relative amplitude]
% 只改这里即可快速更换目标。
tar = [
    20,   0,   1.00;
    32,  35,   0.75;
    42, -28,   0.55
];

% 工作频率与调制参数
fc = 10e9;                 % 载频 Hz
fm = 100e3;                % 调制频率 Hz
targetHarmonic = +1;       % 重点设计的谐波阶数

% 阵列参数
Nx = 16;                   % x 方向单元数
Ny = 16;                   % y 方向单元数
L  = 16;                   % 一个周期内时间片数量，建议 8/16/32

% 理想/初步单元复反射系数
% 从 CST 得到真实数据后修改这里：
% Gamma0 = |S_ref,0| * exp(1j * phase0_rad)
% Gamma1 = |S_ref,1| * exp(1j * phase1_rad)
Gamma0 = 0.95 * exp(1j * deg2rad(0));
Gamma1 = 0.92 * exp(1j * deg2rad(180));

saveResults = true;

%% ===================== 基本参数 =====================

assert(mod(L,2) == 0, 'L 必须为偶数。');
assert(all(tar(:,1) >= 0 & tar(:,1) <= 90), ...
    'tar 第一列 theta 应在 0~90 deg。');

c0 = 299792458;
lambda0 = c0 / fc;
dx = lambda0 / 2;
dy = lambda0 / 2;
T = 1 / fm;

fn = fc + targetHarmonic * fm;
kn = 2*pi*fn/c0;

x = ((0:Nx-1) - (Nx-1)/2) * dx;
y = ((0:Ny-1) - (Ny-1)/2) * dy;
[X, Y] = meshgrid(x, y);

fprintf('载频 fc             = %.6f GHz\n', fc/1e9);
fprintf('调制频率 fm         = %.3f kHz\n', fm/1e3);
fprintf('调制周期 T          = %.3f us\n', T*1e6);
fprintf('目标谐波            = %+d\n', targetHarmonic);
fprintf('目标谐波频率        = %.9f GHz\n', fn/1e9);
fprintf('阵列规模            = %d x %d\n', Nx, Ny);
fprintf('时间片数量 L        = %d\n\n', L);

%% ===================== 生成候选时间序列 =====================

baseCode = [zeros(1,L/2), ones(1,L/2)];

candidateCode  = zeros(L, L);
candidateCoeff = zeros(L, 1);

for s = 0:L-1
    candidateCode(s+1,:) = circshift(baseCode, [0, s]);
    candidateCoeff(s+1) = harmonicCoefficient( ...
        candidateCode(s+1,:), targetHarmonic, Gamma0, Gamma1);
end

candidatePhase = angle(candidateCoeff);

figure('Name','候选循环移位序列');
imagesc(0:L-1, 0:L-1, candidateCode);
axis xy;
xlabel('时间片 l');
ylabel('循环移位量 s');
title('1-bit 候选时间序列');
colorbar;

figure('Name','候选谐波系数');
polarplot(candidatePhase, abs(candidateCoeff), 'o-','LineWidth',1.2);
title(sprintf('候选序列在 n=%+d 阶谐波上的复系数', targetHarmonic));

%% ===================== 根据 tar 构造期望孔径场 =====================

wDesired = zeros(Ny, Nx);

for q = 1:size(tar,1)
    theta = deg2rad(tar(q,1));
    phi   = deg2rad(tar(q,2));
    amp   = tar(q,3);

    uq = sin(theta) * cos(phi);
    vq = sin(theta) * sin(phi);

    wDesired = wDesired + amp .* exp(-1j * kn .* (X*uq + Y*vq));
end

desiredPhase = angle(wDesired);

%% ===================== 相位量化为循环移位序列 =====================

shiftMap = zeros(Ny, Nx);
code3D   = zeros(Ny, Nx, L);

for iy = 1:Ny
    for ix = 1:Nx
        phaseError = angle(exp(1j * (candidatePhase - desiredPhase(iy,ix))));
        [~, bestIndex] = min(abs(phaseError));

        shiftMap(iy,ix) = bestIndex - 1;
        code3D(iy,ix,:) = candidateCode(bestIndex,:);
    end
end

figure('Name','空间编码：循环移位图');
imagesc(x/lambda0, y/lambda0, shiftMap);
axis image xy;
xlabel('x / \lambda_0');
ylabel('y / \lambda_0');
title(sprintf('空间编码图：每个单元的时间序列循环移位量，L=%d',L));
colorbar;

numSlicesToShow = min(4,L);
figure('Name','不同时刻的空间编码');
tiledlayout(1,numSlicesToShow,'Padding','compact','TileSpacing','compact');
sliceIndex = round(linspace(1,L,numSlicesToShow));
for k = 1:numSlicesToShow
    nexttile;
    imagesc(x/lambda0, y/lambda0, code3D(:,:,sliceIndex(k)));
    axis image xy;
    caxis([0 1]);
    title(sprintf('l = %d',sliceIndex(k)-1));
    xlabel('x/\lambda_0');
    ylabel('y/\lambda_0');
end

%% ===================== 计算各阶谐波孔径系数 =====================

harmonicsToPlot = unique([0, targetHarmonic, -targetHarmonic]);
coeffMaps = cell(size(harmonicsToPlot));

for hIdx = 1:numel(harmonicsToPlot)
    nh = harmonicsToPlot(hIdx);
    coeffMap = zeros(Ny,Nx);

    for iy = 1:Ny
        for ix = 1:Nx
            seq = squeeze(code3D(iy,ix,:)).';
            coeffMap(iy,ix) = harmonicCoefficient(seq, nh, Gamma0, Gamma1);
        end
    end

    coeffMaps{hIdx} = coeffMap;
end

%% ===================== 二维方向余弦域方向图 =====================

uAxis = linspace(-1,1,241);
vAxis = linspace(-1,1,241);
[U,V] = meshgrid(uAxis,vAxis);
visibleMask = (U.^2 + V.^2) <= 1;

for hIdx = 1:numel(harmonicsToPlot)
    nh = harmonicsToPlot(hIdx);
    fh = fc + nh*fm;
    kh = 2*pi*fh/c0;
    coeffMap = coeffMaps{hIdx};

    E = zeros(size(U));

    for iy = 1:Ny
        for ix = 1:Nx
            E = E + coeffMap(iy,ix) .* ...
                exp(1j*kh*(X(iy,ix)*U + Y(iy,ix)*V));
        end
    end

    E(~visibleMask) = NaN;
    Eabs = abs(E);
    normValue = max(Eabs(~isnan(Eabs)));
    Edb = 20*log10(Eabs / normValue + 1e-12);
    Edb(Edb < -40) = -40;

    figure('Name',sprintf('n=%+d 阶谐波方向图',nh));
    imagesc(uAxis,vAxis,Edb);
    axis image xy;
    caxis([-40 0]);
    colorbar;
    xlabel('u = sin\theta cos\phi');
    ylabel('v = sin\theta sin\phi');
    title(sprintf('n=%+d 阶谐波归一化方向图 / dB',nh));
    hold on;

    if nh == targetHarmonic
        for q = 1:size(tar,1)
            theta = deg2rad(tar(q,1));
            phi   = deg2rad(tar(q,2));
            uq = sin(theta)*cos(phi);
            vq = sin(theta)*sin(phi);
            plot(uq,vq,'wx','MarkerSize',10,'LineWidth',2);
            text(uq+0.025,vq,sprintf('T%d',q), ...
                'Color','w','FontWeight','bold');
        end
    end
end

%% ===================== 目标方向处场强评估 =====================

targetField = zeros(size(tar,1),1);
targetCoeffMap = coeffMaps{harmonicsToPlot == targetHarmonic};

for q = 1:size(tar,1)
    theta = deg2rad(tar(q,1));
    phi   = deg2rad(tar(q,2));
    uq = sin(theta)*cos(phi);
    vq = sin(theta)*sin(phi);

    targetField(q) = sum(targetCoeffMap(:) .* ...
        exp(1j*kn*(X(:)*uq + Y(:)*vq)));
end

targetFieldNorm = abs(targetField) / max(abs(targetField));

fprintf('目标方向计算结果：\n');
fprintf('编号    theta(deg)   phi(deg)   设定权重   归一化场强\n');
for q = 1:size(tar,1)
    fprintf('%2d      %8.2f   %8.2f     %7.3f      %7.3f\n', ...
        q,tar(q,1),tar(q,2),tar(q,3),targetFieldNorm(q));
end

%% ===================== 保存结果 =====================

if saveResults
    resultFolder = 'time_modulated_array_result';
    if ~exist(resultFolder,'dir')
        mkdir(resultFolder);
    end

    timeCodeMatrix = reshape(code3D, Ny*Nx, L);

    writematrix(shiftMap, fullfile(resultFolder,'shift_map.csv'));
    writematrix(timeCodeMatrix, fullfile(resultFolder,'time_codes.csv'));
    writematrix(tar, fullfile(resultFolder,'targets_tar.csv'));

    targetAmpMap = abs(targetCoeffMap);
    targetPhaseMapDeg = rad2deg(angle(targetCoeffMap));
    writematrix(targetAmpMap, ...
        fullfile(resultFolder,sprintf('harmonic_%+d_amplitude.csv',targetHarmonic)));
    writematrix(targetPhaseMapDeg, ...
        fullfile(resultFolder,sprintf('harmonic_%+d_phase_deg.csv',targetHarmonic)));

    save(fullfile(resultFolder,'coding_result.mat'), ...
        'tar','fc','fm','T','targetHarmonic','Nx','Ny','L', ...
        'Gamma0','Gamma1','x','y','X','Y', ...
        'baseCode','candidateCode','candidateCoeff', ...
        'shiftMap','code3D','coeffMaps','harmonicsToPlot', ...
        'targetField','targetFieldNorm');

    fprintf('\n结果已保存到文件夹：%s\n',resultFolder);
end

%% ===================== 局部函数 =====================

function an = harmonicCoefficient(binarySequence, n, Gamma0, Gamma1)
% 计算等长时间片、分段常值反射系数的傅里叶级数系数

    L = numel(binarySequence);

    gammaSequence = Gamma0 * ones(1,L);
    gammaSequence(binarySequence == 1) = Gamma1;

    if n == 0
        an = mean(gammaSequence);
        return;
    end

    l = 0:L-1;
    sincTerm = sin(pi*n/L) / (pi*n/L);

    an = (sincTerm/L) * sum( ...
        gammaSequence .* exp(-1j*2*pi*n*(l+0.5)/L) );
end
