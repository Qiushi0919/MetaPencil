function reexport_4x4_threshold_figures(run_dir)
% 从已有成像MAT文件重新导出不同dB显示下限，无需重复计算原始回波。
    if nargin < 1 || isempty(run_dir)
        error('请传入包含 sar_results_4x4.mat 的结果目录。');
    end

    loaded = load(fullfile(run_dir, 'sar_results_4x4.mat'), ...
        'img_deception_1bit', 'Range_axis_ground', 'Az_axis', ...
        'single_aircraft_reference', 'zero_state_fraction');

    display_half_width_m = 16;
    recommended_threshold_db = 25;
    thresholds_db = [15, 20, 25, 30];

    main_figure = figure('Color','w', 'Visible','off', ...
        'Position',[100 100 780 650]);
    plotSarDbLocal(loaded.img_deception_1bit, ...
        loaded.Range_axis_ground, loaded.Az_axis, ...
        recommended_threshold_db, loaded.single_aircraft_reference, ...
        display_half_width_m);
    title(sprintf(['二维 1-bit 电磁欺骗：0状态 %.0f%% / 1状态 %.0f%%，' ...
        '显示下限 -%g dB'], ...
        100*loaded.zero_state_fraction, ...
        100*(1-loaded.zero_state_fraction), recommended_threshold_db));
    exportgraphics(main_figure, fullfile(run_dir, ...
        'sar_4x4_deception_1bit.png'), 'Resolution',200);
    savefig(main_figure, fullfile(run_dir, ...
        'sar_4x4_deception_1bit.fig'));
    close(main_figure);

    comparison_figure = figure('Color','w', 'Visible','off', ...
        'Position',[100 100 1200 900]);
    tiledlayout(2,2, 'TileSpacing','compact', 'Padding','compact');
    for threshold_index = 1:numel(thresholds_db)
        nexttile;
        threshold_db = thresholds_db(threshold_index);
        plotSarDbLocal(loaded.img_deception_1bit, ...
            loaded.Range_axis_ground, loaded.Az_axis, threshold_db, ...
            loaded.single_aircraft_reference, display_half_width_m);
        title(sprintf('显示下限 -%g dB', threshold_db));
    end
    sgtitle('4×4机群门限对比（未调制单架飞机峰值=0 dB）');
    exportgraphics(comparison_figure, fullfile(run_dir, ...
        'sar_4x4_threshold_comparison.png'), 'Resolution',200);
    savefig(comparison_figure, fullfile(run_dir, ...
        'sar_4x4_threshold_comparison.fig'));
    close(comparison_figure);

    fprintf('门限图已重新导出至：\n%s\n', run_dir);
end

function plotSarDbLocal(img, range_axis, az_axis, dynamic_range_db, ...
    reference_peak, display_half_width_m)
    img_db = 20*log10(abs(img) + eps);
    img_db = img_db - 20*log10(reference_peak);
    imagesc(range_axis, az_axis, img_db, [-dynamic_range_db, 0]);
    set(gca, 'YDir','normal');
    axis image;
    xlim([-display_half_width_m, display_half_width_m]);
    ylim([-display_half_width_m, display_half_width_m]);
    colormap gray;
    colorbar;
    xlabel('相对地距向 (m)');
    ylabel('方位向 (m)');
end
