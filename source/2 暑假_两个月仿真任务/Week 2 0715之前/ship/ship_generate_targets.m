function [my_data, group_index] = ship_generate_targets(cfg, saveFiles)
%SHIP_GENERATE_TARGETS Generate four groups of three-dot scatter targets.
%   [DATA, GROUP] = SHIP_GENERATE_TARGETS(CFG) uses the four positions in
%   CFG.metasurfaces. Coordinates are unscaled; scaling happens only in the
%   simulator so the GUI and exported point files remain easy to inspect.

if nargin < 2
    saveFiles = false;
end
[cfg, ~] = ship_validate_config(cfg);

rng(cfg.target.randomSeed, 'twister');
nPerDot = cfg.target.pointsPerDot;
nTotal = 4 * 3 * nPerDot;
my_data = zeros(nTotal, 3);
group_index = zeros(nTotal, 1, 'uint8');
cursor = 1;

for g = 1:4
    azCenter = cfg.metasurfaces(g).azimuth;
    rgCenter = cfg.metasurfaces(g).range;
    dotAz = azCenter + [-1, 0, 1] * cfg.target.pointSpacing;

    for dot = 1:3
        theta = 2*pi*rand(nPerDot, 1);
        radius = cfg.target.dotRadius * sqrt(rand(nPerDot, 1));
        rows = cursor:(cursor+nPerDot-1);
        my_data(rows, 1) = dotAz(dot) + radius .* cos(theta);
        my_data(rows, 2) = rgCenter + radius .* sin(theta);
        my_data(rows, 3) = cfg.target.amplitude;
        group_index(rows) = g;
        cursor = cursor + nPerDot;
    end
end

if saveFiles
    writematrix(my_data, 'four_group_scatter_points.txt', 'Delimiter', 'tab');
    save('four_group_scatter_points.mat', 'my_data', 'group_index', 'cfg');
end
end
