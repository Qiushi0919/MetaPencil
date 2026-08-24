%% Modified geometry: four states and phase difference from 6 to 14 GHz
clear; clc;

scriptDir = fileparts(mfilename('fullpath'));
rawFile = fullfile(scriptDir, 'cst_all_runs_export.txt');
rawText = fileread(rawFile);

targetW2 = 5.5;
targetL1 = 3.1;
targetFmin = 6;
targetFmax = 14;

blocks = regexp(rawText, '(?m)^Curvelabel\s*=\s*', 'split');
blocks = blocks(2:end);
numPattern = '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?';
rowPattern = ['(?m)^\s*(' numPattern ')\s+(' numPattern ')\s+(' ...
    numPattern ')\s+(' numPattern ')\s+(' numPattern ')\s*$'];

states = ["00", "01", "10", "11"];
phaseDeg = cell(1, 4);
complexS = cell(1, 4);
magnitudeDB = cell(1, 4);
frequencyGHz = [];
found = false(1, 4);

for k = 1:numel(blocks)
    block = blocks{k};
    pToken = regexp(block, '(?m)^Parameters\s*=\s*\{([^\r\n]*)\}', ...
        'tokens', 'once');
    if isempty(pToken)
        continue;
    end
    pText = pToken{1};
    W2 = getParameter(pText, 'W2');
    L1 = getParameter(pText, 'L1');
    fmin = getParameter(pText, 'fmin');
    fmax = getParameter(pText, 'fmax');

    if abs(W2-targetW2) > 1e-12 || abs(L1-targetL1) > 1e-12 || ...
            abs(fmin-targetFmin) > 1e-12 || abs(fmax-targetFmax) > 1e-12
        continue;
    end

    Rx = getParameter(pText, 'Rx');
    Ry = getParameter(pText, 'Ry');
    state = string(double(Rx < 5)) + string(double(Ry < 5));
    stateIndex = find(states == state, 1);

    rowTokens = regexp(block, rowPattern, 'tokens');
    data = cellfun(@str2double, vertcat(rowTokens{:}));
    z = data(:, 2) + 1i * data(:, 3);

    if isempty(frequencyGHz)
        frequencyGHz = data(:, 1);
    else
        assert(max(abs(frequencyGHz-data(:, 1))) < 1e-12, ...
            'Selected curves do not have identical frequency samples.');
    end

    complexS{stateIndex} = z;
    phaseDeg{stateIndex} = rad2deg(unwrap(angle(z)));
    magnitudeDB{stateIndex} = 20*log10(abs(z));
    found(stateIndex) = true;
end

assert(all(found), 'Could not find all four modified-geometry states.');

% Compare the two meaningful switching pairs for the displayed Floquet mode.
pairList = [1 2; 3 4]; % 00-01 and 10-11
bestWidth = -Inf;
bestPair = [];
bestDifference = [];
bestBand = [NaN NaN];

for q = 1:size(pairList, 1)
    a = pairList(q, 1);
    b = pairList(q, 2);
    difference = phaseDeg{a} - phaseDeg{b};
    difference = difference + 360*round((-180-median(difference))/360);
    [bandStart, bandStop, bandWidth] = longestContinuousBand( ...
        frequencyGHz, difference >= -210 & difference <= -150);
    fprintf('State %s-%s band: %.3f to %.3f GHz (%.3f GHz)\n', ...
        states(a), states(b), bandStart, bandStop, bandWidth);
    if bandWidth > bestWidth
        bestWidth = bandWidth;
        bestPair = [a b];
        bestDifference = difference;
        bestBand = [bandStart bandStop];
    end
end

fprintf('Selected modified pair: State %s-%s\n', ...
    states(bestPair(1)), states(bestPair(2)));
fprintf('Selected 180 +/- 30 deg bandwidth: %.3f to %.3f GHz (%.3f GHz)\n', ...
    bestBand(1), bestBand(2), bestWidth);

phase00_deg = phaseDeg{1};
phase01_deg = phaseDeg{2};
phase10_deg = phaseDeg{3};
phase11_deg = phaseDeg{4};
phaseDifference_deg = bestDifference;
selectedPair = states(bestPair);
band180_GHz = bestBand;
bandwidth180_GHz = bestWidth;

save(fullfile(scriptDir, 'modified_phase_data_6_14.mat'), ...
    'frequencyGHz', 'phase00_deg', 'phase01_deg', 'phase10_deg', ...
    'phase11_deg', 'phaseDifference_deg', 'selectedPair', ...
    'band180_GHz', 'bandwidth180_GHz', 'complexS', 'magnitudeDB');

outputTable = table(frequencyGHz, phase00_deg, phase01_deg, ...
    phase10_deg, phase11_deg, phaseDifference_deg, ...
    'VariableNames', {'Frequency_GHz', 'Phase00_deg', 'Phase01_deg', ...
    'Phase10_deg', 'Phase11_deg', 'SelectedPhaseDifference_deg'});
writetable(outputTable, fullfile(scriptDir, 'modified_phase_data_6_14.csv'));

%% Four state phases plus the selected phase difference
fig = figure('Color', 'w', 'Position', [100 100 1000 620]);
hold on;
colors = [0.00 0.35 0.80; 0.85 0.20 0.15; ...
          0.10 0.60 0.25; 0.65 0.15 0.75];
for k = 1:4
    plot(frequencyGHz, phaseDeg{k}, 'LineWidth', 1.6, ...
        'Color', colors(k, :), 'DisplayName', "State " + states(k));
end

yline(-150, '--', '-150 deg', 'Color', [0.25 0.25 0.25], ...
    'LineWidth', 1.3, 'HandleVisibility', 'off', ...
    'LabelHorizontalAlignment', 'left');
yline(-210, '--', '-210 deg', 'Color', [0.25 0.25 0.25], ...
    'LineWidth', 1.3, 'HandleVisibility', 'off', ...
    'LabelHorizontalAlignment', 'left');
xline(bestBand(1), ':', 'Color', [0.45 0.45 0.45], ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');
xline(bestBand(2), ':', 'Color', [0.45 0.45 0.45], ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');

hDifference = plot(frequencyGHz, bestDifference, 'k-', ...
    'LineWidth', 2.7, 'DisplayName', ...
    "Phase difference " + states(bestPair(1)) + "-" + states(bestPair(2)));
highlight = bestDifference;
highlight(bestDifference < -210 | bestDifference > -150) = NaN;
hHighlight = plot(frequencyGHz, highlight, '-', ...
    'Color', [1.00 0.48 0.00], 'LineWidth', 4.2, ...
    'HandleVisibility', 'off');
uistack(hDifference, 'top');
uistack(hHighlight, 'top');

grid on; box on;
xlim([6 14]);
xlabel('Frequency (GHz)');
ylabel('Reflection phase / phase difference (deg)');
title(sprintf(['Modified W_2=5.5 mm, L_1=3.1 mm; ' ...
    '180%c%c30%c band: %.3f-%.3f GHz'], char(176), char(177), ...
    char(176), bestBand(1), bestBand(2)));
legend('Location', 'southwest');
set(gca, 'FontName', 'Arial', 'FontSize', 11, 'LineWidth', 1);

savefig(fig, fullfile(scriptDir, 'modified_four_states_phase_6_14.fig'));
exportgraphics(fig, fullfile(scriptDir, ...
    'modified_four_states_phase_6_14.png'), 'Resolution', 300);

%% Local functions
function value = getParameter(text, name)
    token = regexp(text, ['(?<!\w)' name '=([^;\}]+)'], ...
        'tokens', 'once');
    value = str2double(token{1});
end

function [bandStart, bandStop, bandWidth] = longestContinuousBand(f, mask)
    edge = diff([false; mask(:); false]);
    starts = find(edge == 1);
    stops = find(edge == -1)-1;
    if isempty(starts)
        bandStart = NaN;
        bandStop = NaN;
        bandWidth = 0;
        return;
    end
    widths = f(stops)-f(starts);
    [bandWidth, idx] = max(widths);
    bandStart = f(starts(idx));
    bandStop = f(stops(idx));
end
