function [cfg, info] = ship_validate_config(cfg)
%SHIP_VALIDATE_CONFIG Validate configuration and estimate run size.

mustBeStructWithFields(cfg, {'radar','scene','target','coverage', ...
    'metasurfaces','sampling','execution','display'});

if numel(cfg.metasurfaces) ~= 4
    error('ship:InvalidConfig', 'Exactly four metasurfaces are required.');
end

positiveFields = {
    cfg.radar.c, 'radar.c';
    cfg.radar.fc, 'radar.fc';
    cfg.radar.pulseWidth, 'radar.pulseWidth';
    cfg.radar.bandwidth, 'radar.bandwidth';
    cfg.radar.altitude, 'radar.altitude';
    cfg.radar.velocity, 'radar.velocity';
    cfg.scene.scale, 'scene.scale';
    cfg.scene.azimuthSpan, 'scene.azimuthSpan';
    cfg.target.pointSpacing, 'target.pointSpacing';
    cfg.target.pointsPerDot, 'target.pointsPerDot';
    cfg.target.dotRadius, 'target.dotRadius';
    cfg.target.downsampleRate, 'target.downsampleRate';
    cfg.coverage.azimuthHalfWidth, 'coverage.azimuthHalfWidth';
    cfg.coverage.rangeHalfWidth, 'coverage.rangeHalfWidth';
    cfg.execution.maxMemoryGB, 'execution.maxMemoryGB';
    cfg.display.dynamicRangeDB, 'display.dynamicRangeDB';
    cfg.display.gamma, 'display.gamma'};

for k = 1:size(positiveFields, 1)
    value = positiveFields{k, 1};
    label = positiveFields{k, 2};
    if ~(isnumeric(value) && isscalar(value) && isfinite(value) && value > 0)
        error('ship:InvalidConfig', '%s must be a finite positive scalar.', label);
    end
end

integerFields = {'pointsPerDot','downsampleRate','randomSeed'};
for k = 1:numel(integerFields)
    f = integerFields{k};
    value = cfg.target.(f);
    if ~(isscalar(value) && isfinite(value) && value >= 1 && value == floor(value))
        error('ship:InvalidConfig', 'target.%s must be a positive integer.', f);
    end
end

for k = 1:4
    s = cfg.metasurfaces(k);
    values = [s.azimuth, s.range, s.slowPiCount, s.slowZeroCount, s.fastRepeats];
    if any(~isfinite(values)) || any(values(3:5) < 1) || any(values(3:5) ~= floor(values(3:5)))
        error('ship:InvalidConfig', 'Metasurface %d contains invalid position or code counts.', k);
    end
    if isempty(s.fastPhaseCode) || ~isnumeric(s.fastPhaseCode) || any(~isfinite(s.fastPhaseCode))
        error('ship:InvalidConfig', 'Metasurface %d fast phase code is invalid.', k);
    end
    cfg.metasurfaces(k).enabled = logical(s.enabled);
    cfg.metasurfaces(k).fastPhaseCode = reshape(s.fastPhaseCode, 1, []);
end

c = cfg.radar.c;
lambda = c / cfg.radar.fc;
lookAngle = deg2rad(cfg.radar.lookAngleDeg);
sceneCenterRange = cfg.radar.altitude * tan(lookAngle);
slantRange = hypot(cfg.radar.altitude, sceneCenterRange);
ka = -2 * cfg.radar.velocity^2 / (lambda * slantRange);
ba = abs(ka * cfg.scene.azimuthSpan / cfg.radar.velocity);
prf = ceil(1.2 * ba);
apertureTime = (cfg.scene.azimuthSpan + 300) / cfg.radar.velocity;

if strcmpi(cfg.sampling.mode, 'auto')
    na = 2^nextpow2(apertureTime * prf);
    fsInitial = cfg.radar.initialSamplingFactor * cfg.radar.bandwidth;
    duration = 4 * cfg.scene.rangeSpan / c + cfg.radar.pulseWidth;
    nr = 2^nextpow2(max(2, ceil(duration * fsInitial)));
elseif strcmpi(cfg.sampling.mode, 'manual')
    na = validateSampleCount(cfg.sampling.azimuthSamples, 'azimuthSamples');
    nr = validateSampleCount(cfg.sampling.rangeSamples, 'rangeSamples');
else
    error('ship:InvalidConfig', 'sampling.mode must be manual or auto.');
end

rawTargetCount = 4 * 3 * cfg.target.pointsPerDot;
usedTargetCount = ceil(rawTargetCount / cfg.target.downsampleRate);

% sr_total, working echo matrix, and several RD matrices coexist. This is
% intentionally conservative so the GUI can warn before MATLAB swaps.
estimatedMemoryGB = double(na) * double(nr) * 16 * 8 / 1024^3;

warnings = {};
if estimatedMemoryGB > cfg.execution.maxMemoryGB
    warnings{end+1} = sprintf( ...
        'Estimated peak memory %.2f GB exceeds the configured %.2f GB limit.', ...
        estimatedMemoryGB, cfg.execution.maxMemoryGB); %#ok<AGROW>
end

centers = [[cfg.metasurfaces.azimuth].', [cfg.metasurfaces.range].'];
for a = 1:3
    for b = (a+1):4
        if abs(centers(a,1)-centers(b,1)) < 2*cfg.coverage.azimuthHalfWidth && ...
                abs(centers(a,2)-centers(b,2)) < 2*cfg.coverage.rangeHalfWidth
            warnings{end+1} = sprintf('Coverage areas %d and %d overlap.', a, b); %#ok<AGROW>
        end
    end
end

info = struct('lambda', lambda, 'sceneCenterRange', sceneCenterRange, ...
    'slantRange', slantRange, 'ka', ka, 'bandwidthAzimuth', ba, ...
    'derivedPRF', prf, 'apertureTime', apertureTime, 'na', na, 'nr', nr, ...
    'rawTargetCount', rawTargetCount, 'usedTargetCount', usedTargetCount, ...
    'estimatedMemoryGB', estimatedMemoryGB, 'warnings', {warnings});
end

function value = validateSampleCount(value, name)
if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
        value >= 16 && value == floor(value))
    error('ship:InvalidConfig', 'sampling.%s must be an integer >= 16.', name);
end
end

function mustBeStructWithFields(value, fieldNames)
if ~isstruct(value)
    error('ship:InvalidConfig', 'Configuration must be a structure.');
end
for k = 1:numel(fieldNames)
    if ~isfield(value, fieldNames{k})
        error('ship:InvalidConfig', 'Missing configuration section: %s.', fieldNames{k});
    end
end
end
