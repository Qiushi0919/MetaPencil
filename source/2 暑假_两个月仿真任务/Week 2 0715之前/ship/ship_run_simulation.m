function result = ship_run_simulation(cfg, progressFcn)
%SHIP_RUN_SIMULATION Run echo generation and RD imaging from one config.
%   RESULT = SHIP_RUN_SIMULATION(CFG, PROGRESSFCN) calls PROGRESSFCN with
%   (fraction, message). Returning false cancels the simulation.

if nargin < 2
    progressFcn = [];
end
[cfg, info] = ship_validate_config(cfg);
if info.estimatedMemoryGB > cfg.execution.maxMemoryGB
    error('ship:MemoryLimit', ['Estimated peak memory is %.2f GB, above the ' ...
        'configured limit of %.2f GB. Reduce Na/Nr or increase the limit.'], ...
        info.estimatedMemoryGB, cfg.execution.maxMemoryGB);
end
reportProgress(0, 'Generating scatter targets...');

[target, ~] = ship_generate_targets(cfg, false);
target = target(1:cfg.target.downsampleRate:end, :);
target(:, 1:2) = cfg.scene.scale * target(:, 1:2);
centers = cfg.scene.scale * [[cfg.metasurfaces.azimuth].', ...
    [cfg.metasurfaces.range].'];
coverAz = cfg.scene.scale * cfg.coverage.azimuthHalfWidth;
coverRg = cfg.scene.scale * cfg.coverage.rangeHalfWidth;

c = cfg.radar.c;
lambda = info.lambda;
tp = cfg.radar.pulseWidth;
kr = cfg.radar.bandwidth / tp;
y0 = info.sceneCenterRange;
x0 = cfg.scene.centerAzimuth;
na = info.na;
nr = info.nr;

tc = info.apertureTime;
tm = linspace(-tc/2, tc/2, na).';
xRadar = tm * cfg.radar.velocity;
prfActual = 1 / (tm(2)-tm(1));

rMin = info.slantRange - cfg.scene.rangeSpan;
rMax = info.slantRange + cfg.scene.rangeSpan;
t = linspace(2*rMin/c-tp/2, 2*rMax/c+tp/2, nr);
dt = t(2)-t(1);
fsActual = 1/dt;

modTemplates = cell(4, 2);
for g = 1:4
    s = cfg.metasurfaces(g);
    slowPhases = [pi*ones(1, s.slowPiCount), zeros(1, s.slowZeroCount)];
    modTemplates{g, 1} = exp(1j * repmat(s.fastPhaseCode, 1, s.fastRepeats));
    modTemplates{g, 2} = exp(1j * slowPhases);
end

srTotal = complex(zeros(na, nr));
coverCount = zeros(4, 1);
nTarget = size(target, 1);
reportProgress(0.02, sprintf('Generating echoes for %d targets...', nTarget));

for i = 1:nTarget
    xi = target(i, 1);
    zi = target(i, 2);
    idx = 0;
    for g = 1:4
        if abs(xi-centers(g,1)) < coverAz && abs(zi-centers(g,2)) < coverRg
            idx = g;
            break
        end
    end
    if idx > 0
        coverCount(idx) = coverCount(idx) + 1;
    end

    orderAz = xi + x0;
    orderRg = zi + y0;
    rInst = sqrt((orderAz-xRadar).^2 + orderRg.^2 + cfg.radar.altitude^2);
    delay = 2*rInst/c;
    tau = t - delay;
    pulseMask = abs(tau) <= tp/2;
    pulse = target(i,3) .* pulseMask .* exp(1j*pi*kr*tau.^2) .* ...
        exp(-1j*4*pi*rInst/lambda);

    if idx > 0 && cfg.metasurfaces(idx).enabled
        fastTemplate = modTemplates{idx, 1};
        slowTemplate = modTemplates{idx, 2};
        slowIndex = mod((0:na-1).', numel(slowTemplate)) + 1;
        % MATLAB preserves the row shape of a row-vector source during
        % vector indexing, so force this modulation sequence to Na-by-1.
        slowMod = reshape(slowTemplate(slowIndex), [], 1);

        tRel = tau + tp/2;
        fastIndex = floor((tRel/tp) * (numel(fastTemplate)-1)) + 1;
        fastIndex = min(max(fastIndex, 1), numel(fastTemplate));
        fastMod = fastTemplate(fastIndex);
        fastMod(~pulseMask) = 1;
        pulse = slowMod .* fastMod .* pulse;
    end
    srTotal = srTotal + pulse;

    if mod(i, max(1, floor(nTarget/100))) == 0 || i == nTarget
        reportProgress(0.02 + 0.70*i/nTarget, ...
            sprintf('Echo generation: %d / %d targets', i, nTarget));
    end
end

reportProgress(0.74, 'Range compression...');
tRef = (-(nr/2):(nr/2-1)) * dt;
hRef = exp(1j*pi*kr*tRef.^2) .* (abs(tRef) <= tp/2);
hRange = conj(fft(fftshift(hRef)));
sRange = fft(srTotal, [], 2) .* hRange;
sRC = ifft(sRange, [], 2);

reportProgress(0.80, 'Azimuth FFT and RCMC...');
sAz = fft(sRC, [], 1);
fa = (0:na-1).' / na * prfActual;
fa(fa > prfActual/2) = fa(fa > prfActual/2) - prfActual;
rAxis = t*c/2;
sRCMC = complex(zeros(size(sAz)));
for k = 1:na
    moveFactor = lambda^2 * fa(k)^2 / (8*cfg.radar.velocity^2);
    shiftR = rAxis * moveFactor;
    sRCMC(k,:) = interp1(rAxis, sAz(k,:), rAxis+shiftR, 'spline', 0);
    if mod(k, max(1, floor(na/20))) == 0
        reportProgress(0.80 + 0.12*k/na, sprintf('RCMC: %d / %d lines', k, na));
    end
end

reportProgress(0.94, 'Azimuth compression...');
hAz = exp(1j*pi*fa.^2/info.ka);
img = ifft(sRCMC .* hAz, [], 1);
imgAbs = abs(img);
imgDB = 20*log10(imgAbs + eps);
imgDB = imgDB - max(imgDB(:));

result = struct('config', cfg, 'info', info, 'image', img, ...
    'imageDB', imgDB, 'rangeAxis', rAxis, ...
    'azimuthAxis', tm*cfg.radar.velocity, 'coverCount', coverCount, ...
    'samplingFrequencyActual', fsActual, 'prfActual', prfActual, ...
    'targetCount', nTarget);
reportProgress(1, 'Simulation complete.');

    function reportProgress(fraction, message)
        if isempty(progressFcn)
            return
        end
        keepGoing = progressFcn(fraction, message);
        if isequal(keepGoing, false)
            error('ship:Cancelled', 'Simulation cancelled by user.');
        end
    end
end
