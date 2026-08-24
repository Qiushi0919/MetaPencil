clearvars; clc; close all;

%% 各次谐波幅度
% 与 SHIP_4x4.m 使用相同参数。此脚本只计算编码的理论傅里叶系数，
% 不生成飞机回波，因此可以快速、独立运行。
% 统一参考：未加超表面的单架飞机回波幅度 A=1，对应 0 dB。
% 这里仅研究理想1-bit编码的谐波分配，不乘超表面反射效率。
zero_state_fraction = 0.30;
grid_spacing_m = 8.0;
maximum_harmonic_order = 5;

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

harmonic_orders = (-maximum_harmonic_order:maximum_harmonic_order).';
harmonic_coefficients = arrayfun( ...
    @(order) oneBitFourierCoefficient(order, zero_state_fraction), ...
    harmonic_orders);
harmonic_amplitude = abs(harmonic_coefficients);
harmonic_amplitude_db = 20*log10(harmonic_amplitude + eps);
harmonic_offset_m = harmonic_orders * grid_spacing_m;

harmonic_table = table(harmonic_orders, harmonic_offset_m, ...
    real(harmonic_coefficients), imag(harmonic_coefficients), ...
    harmonic_amplitude, harmonic_amplitude_db, ...
    'VariableNames', {'harmonic_order','spatial_offset_m', ...
    'coefficient_real','coefficient_imag','amplitude','amplitude_db'});

figure_harmonics = figure('Color','w', ...
    'Name','各次谐波幅度', 'NumberTitle','off', ...
    'Position',[100 100 820 760]);
tiledlayout(2,1, 'TileSpacing','compact', 'Padding','compact');
sgtitle('各次谐波幅度');

nexttile;
plotHarmonics(harmonic_offset_m, harmonic_orders, ...
    harmonic_amplitude_db, grid_spacing_m, '距离向');

nexttile;
plotHarmonics(harmonic_offset_m, harmonic_orders, ...
    harmonic_amplitude_db, grid_spacing_m, '方位向');

png_file = fullfile(script_dir, 'one_bit_harmonic_amplitudes.png');
fig_file = fullfile(script_dir, 'one_bit_harmonic_amplitudes.fig');
csv_file = fullfile(script_dir, 'one_bit_harmonic_amplitudes.csv');

exportgraphics(figure_harmonics, png_file, 'Resolution', 200);
savefig(figure_harmonics, fig_file);
writetable(harmonic_table, csv_file);

disp(harmonic_table);
fprintf('\n已保存：\n%s\n%s\n%s\n', png_file, fig_file, csv_file);

function coefficient = oneBitFourierCoefficient(order, zero_fraction)
    if order == 0
        coefficient = 2*zero_fraction - 1;
    else
        coefficient = 2*sin(pi*order*zero_fraction)/(pi*order) * ...
            exp(-1j*pi*order*zero_fraction);
    end
end

function plotHarmonics(offset_m, orders, amplitude_db, spacing_m, direction)
    stem(offset_m, amplitude_db, 'filled', ...
        'LineWidth',1.4, 'MarkerSize',5);
    hold on;
    yline(0, '--k', '未加超表面：A=1（0 dB）', ...
        'LabelHorizontalAlignment','left');
    hold off;
    grid on;
    xlim([min(offset_m)-spacing_m/2, max(offset_m)+spacing_m/2]);
    ylim([-25, 2]);
    xticks(offset_m);
    xlabel(sprintf('%s偏移 / m', direction));
    ylabel('相对未调制单机幅度 / dB');
    title(sprintf('%s（理论间距 %.1f m）', direction, spacing_m));
    for index = 1:numel(orders)
        text(offset_m(index), amplitude_db(index)+1.0, ...
            sprintf('n=%+d', orders(index)), ...
            'HorizontalAlignment','center', 'FontSize',8);
    end
end
