function cfg = ship_default_config()
%SHIP_DEFAULT_CONFIG Return the unified configuration used by the GUI.

cfg.version = 1;

% Radar and flight parameters (kept consistent with the original SHIP.m).
cfg.radar.c = 3e8;
cfg.radar.fc = 10e9;
cfg.radar.pulseWidth = 3e-6;
cfg.radar.bandwidth = 300e6;
cfg.radar.initialSamplingFactor = 4.0;
cfg.radar.lookAngleDeg = 70;
cfg.radar.altitude = 20000;
cfg.radar.velocity = 1000;
cfg.radar.antennaLength = 10;

cfg.scene.centerAzimuth = 0;
cfg.scene.azimuthSpan = 200;
cfg.scene.rangeSpan = 0;
cfg.scene.scale = 10;

% Point-target generator.
cfg.target.pointSpacing = 0.3;
cfg.target.pointsPerDot = 3000;
cfg.target.dotRadius = 0.035;
cfg.target.amplitude = 1;
cfg.target.randomSeed = 20260710;
cfg.target.downsampleRate = 160;

% Coverage window around each metasurface center, before scene scaling.
cfg.coverage.azimuthHalfWidth = 0.40;
cfg.coverage.rangeHalfWidth = 0.12;

names = {'Left', 'Right', 'Top', 'Bottom'};
centers = [0, -1; 0, 1; -1, 0; 1, 0];
nPi = [60, 43, 100, 100];
nZero = [36, 24, 12, 12];
fastCodes = {[pi, pi, 0], [0, 0], [pi, pi, 0], [pi, pi, 0]};

cfg.metasurfaces = repmat(struct( ...
    'name', '', ...
    'enabled', true, ...
    'azimuth', 0, ...
    'range', 0, ...
    'slowPiCount', 0, ...
    'slowZeroCount', 0, ...
    'fastPhaseCode', [], ...
    'fastRepeats', 10), 1, 4);

for k = 1:4
    cfg.metasurfaces(k).name = names{k};
    cfg.metasurfaces(k).azimuth = centers(k, 1);
    cfg.metasurfaces(k).range = centers(k, 2);
    cfg.metasurfaces(k).slowPiCount = nPi(k);
    cfg.metasurfaces(k).slowZeroCount = nZero(k);
    cfg.metasurfaces(k).fastPhaseCode = fastCodes{k};
end

% Manual sampling is deliberately safe for interactive use. Set mode to
% "auto" when a physically derived PRF/size is required and enough memory
% is available.
cfg.sampling.mode = 'manual';
cfg.sampling.azimuthSamples = 256;
cfg.sampling.rangeSamples = 512;
cfg.execution.maxMemoryGB = 4;

cfg.display.dynamicRangeDB = 13;
cfg.display.gamma = 0.45;
end
