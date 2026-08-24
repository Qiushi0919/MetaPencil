%% Import CST phase data and reproduce a paper-style 1-bit phase plot
% The CST XY export stores complex S-parameters as frequency, real, imag,
% reference impedance and an auxiliary flag.  Phase must be calculated from
% atan2(imag, real); it is not stored directly as one of the numeric columns.

clear; clc;

scriptDir = fileparts(mfilename('fullpath'));
rawFile = fullfile(scriptDir, 'cst_phase_export.txt');
rawText = fileread(rawFile);

blocks = regexp(rawText, '(?m)^Curvelabel\s*=\s*', 'split');
blocks = blocks(2:end);
nCurves = numel(blocks);
assert(nCurves == 4, 'Expected four CST curves, but found %d.', nCurves);

numPattern = '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?';
rowPattern = ['(?m)^\s*(' numPattern ')\s+(' numPattern ')\s+(' ...
    numPattern ')\s+(' numPattern ')\s+(' numPattern ')\s*$'];

curveLabel = strings(1, nCurves);
state = strings(1, nCurves);
phaseDeg = cell(1, nCurves);
complexS = cell(1, nCurves);
frequencyGHz = [];

for k = 1:nCurves
    block = blocks{k};

    labelToken = regexp(block, '^([^\r\n]+)', 'tokens', 'once');
    curveLabel(k) = strtrim(labelToken{1});

    nToken = regexp(block, '(?m)^Npoints\s*=\s*(\d+)', 'tokens', 'once');
    nExpected = str2double(nToken{1});

    pToken = regexp(block, '(?m)^Parameters\s*=\s*\{([^\r\n]*)\}', ...
        'tokens', 'once');
    pText = pToken{1};
    Rx = str2double(regexp(pText, '(?<!\w)Rx=([^;\}]+)', 'tokens', 'once'));
    Ry = str2double(regexp(pText, '(?<!\w)Ry=([^;\}]+)', 'tokens', 'once'));
    state(k) = string(double(Rx < 5)) + string(double(Ry < 5));

    rowTokens = regexp(block, rowPattern, 'tokens');
    data = cellfun(@str2double, vertcat(rowTokens{:}));
    assert(size(data, 1) == nExpected, ...
        'Curve %s: expected %d points, parsed %d.', ...
        curveLabel(k), nExpected, size(data, 1));

    if isempty(frequencyGHz)
        frequencyGHz = data(:, 1);
    else
        assert(max(abs(frequencyGHz - data(:, 1))) < 1e-12, ...
            'The four curves do not share the same frequency samples.');
    end

    complexS{k} = data(:, 2) + 1i * data(:, 3);
    wrappedPhase = atan2d(imag(complexS{k}), real(complexS{k}));
    phaseDeg{k} = rad2deg(unwrap(deg2rad(wrappedPhase)));
end

% Reorder consistently as 00, 01, 10, 11 for output and plotting.
desiredOrder = ["00", "01", "10", "11"];
order = zeros(1, 4);
for k = 1:4
    order(k) = find(state == desiredOrder(k), 1);
end
state = state(order);
curveLabel = curveLabel(order);
phaseDeg = phaseDeg(order);
complexS = complexS(order);

% Select the physically meaningful one-bit pair with the widest continuous
% 180 +/- 30 degree bandwidth.  Pairs must differ in exactly one state bit.
pairList = [1 2; 1 3; 2 4; 3 4];
bestWidth = -Inf;
bestPair = [];
bestDifference = [];
bestBand = [NaN NaN];

for q = 1:size(pairList, 1)
    a = pairList(q, 1);
    b = pairList(q, 2);
    difference = phaseDeg{a} - phaseDeg{b};
    difference = difference + 360 * round((-180 - median(difference)) / 360);
    inBand = difference >= -210 & difference <= -150;
    [bandStart, bandStop, bandWidth] = longestContinuousBand( ...
        frequencyGHz, inBand);

    if bandWidth > bestWidth
        bestWidth = bandWidth;
        bestPair = [a b];
        bestDifference = difference;
        bestBand = [bandStart bandStop];
    end
end

fprintf('Selected phase-difference pair: State %s - State %s\n', ...
    state(bestPair(1)), state(bestPair(2)));
fprintf('180 +/- 30 deg continuous bandwidth: %.3f to %.3f GHz (%.3f GHz)\n', ...
    bestBand(1), bestBand(2), bestWidth);

% Save MATLAB-ready numerical data.
phase00_deg = phaseDeg{state == "00"};
phase01_deg = phaseDeg{state == "01"};
phase10_deg = phaseDeg{state == "10"};
phase11_deg = phaseDeg{state == "11"};
phaseDifference_deg = bestDifference;
selectedPair = state(bestPair);
band180_GHz = bestBand;
bandwidth180_GHz = bestWidth;

save(fullfile(scriptDir, 'phase_data.mat'), ...
    'frequencyGHz', 'phase00_deg', 'phase01_deg', 'phase10_deg', ...
    'phase11_deg', 'phaseDifference_deg', 'selectedPair', ...
    'band180_GHz', 'bandwidth180_GHz', 'complexS', 'curveLabel');

outputTable = table(frequencyGHz, phase00_deg, phase01_deg, phase10_deg, ...
    phase11_deg, phaseDifference_deg, ...
    'VariableNames', {'Frequency_GHz', 'Phase00_deg', 'Phase01_deg', ...
    'Phase10_deg', 'Phase11_deg', 'SelectedPhaseDifference_deg'});
writetable(outputTable, fullfile(scriptDir, 'phase_data.csv'));

% Plot four state phases and the selected phase difference in one axes.
fig = figure('Color', 'w', 'Position', [100 100 960 600]);
hold on;
colors = [0.00 0.35 0.80; 0.85 0.20 0.15; ...
          0.10 0.60 0.25; 0.65 0.15 0.75];
for k = 1:4
    plot(frequencyGHz, phaseDeg{k}, 'LineWidth', 1.6, ...
        'Color', colors(k, :), 'DisplayName', "State " + state(k));
end

% Draw the tolerance limits first so the phase-difference curve remains on
% top.  The part inside -210 to -150 deg is highlighted in a bright color;
% the part outside the tolerance band remains solid black.
yline(-150, '--', '-150 deg', 'Color', [0.25 0.25 0.25], ...
    'LineWidth', 1.3, ...
    'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left');
yline(-210, '--', '-210 deg', 'Color', [0.25 0.25 0.25], ...
    'LineWidth', 1.3, ...
    'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left');
xline(bestBand(1), ':', 'Color', [0.5 0.5 0.5], ...
    'HandleVisibility', 'off');
xline(bestBand(2), ':', 'Color', [0.5 0.5 0.5], ...
    'HandleVisibility', 'off');

hDifference = plot(frequencyGHz, bestDifference, '-', ...
    'Color', [0 0 0], 'LineWidth', 2.6, ...
    'DisplayName', "Phase difference " + state(bestPair(1)) + ...
    "-" + state(bestPair(2)));
highlightDifference = bestDifference;
highlightDifference(bestDifference < -210 | bestDifference > -150) = NaN;
hHighlight = plot(frequencyGHz, highlightDifference, '-', ...
    'Color', [1.00 0.48 0.00], 'LineWidth', 4.2, ...
    'HandleVisibility', 'off');
uistack(hDifference, 'top');
uistack(hHighlight, 'top');

grid on; box on;
xlim([frequencyGHz(1), frequencyGHz(end)]);
xlabel('Frequency (GHz)');
ylabel('Reflection phase / phase difference (deg)');
title(sprintf('Four 1-bit states and phase difference; 180%c%c30%c band: %.3f-%.3f GHz', ...
    char(176), char(177), char(176), bestBand(1), bestBand(2)));
legend('Location', 'southwest');
set(gca, 'FontName', 'Arial', 'FontSize', 11, 'LineWidth', 1);

savefig(fig, fullfile(scriptDir, 'phase_1bit_four_states.fig'));
exportgraphics(fig, fullfile(scriptDir, 'phase_1bit_four_states.png'), ...
    'Resolution', 300);

%% Local function
function [bandStart, bandStop, bandWidth] = longestContinuousBand(f, mask)
    edge = diff([false; mask(:); false]);
    starts = find(edge == 1);
    stops = find(edge == -1) - 1;
    if isempty(starts)
        bandStart = NaN;
        bandStop = NaN;
        bandWidth = 0;
        return;
    end
    widths = f(stops) - f(starts);
    [bandWidth, idx] = max(widths);
    bandStart = f(starts(idx));
    bandStop = f(stops(idx));
end
