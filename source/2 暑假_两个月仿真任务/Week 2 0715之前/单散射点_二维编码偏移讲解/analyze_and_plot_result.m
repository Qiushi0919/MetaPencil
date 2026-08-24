function analyze_and_plot_result(img, image_axes, cfg, one_case, info, result_dir)
%ANALYZE_AND_PLOT_RESULT 显示二维结果以及距离向、方位向最大投影。
%
% 最大投影比只截取中心行/列更稳健：二维编码后，不同谐波的峰可能
% 同时在距离和方位两个方向移动，中心行不一定穿过所有复制点。

range_keep = abs(image_axes.range_offset) <= cfg.range_half_span;
az_keep = abs(image_axes.azimuth - cfg.target_az) <= 70;

img_show = abs(img(az_keep, range_keep));
img_show = img_show/(max(img_show(:)) + eps);
img_db = 20*log10(img_show + eps);

range_axis = image_axes.range_offset(range_keep);
az_axis = image_axes.azimuth(az_keep);

range_projection = max(img_show, [], 1);
az_projection = max(img_show, [], 2);

fig = figure('Color', 'w', 'Name', one_case.name, ...
    'Position', [80, 80, 1250, 760]);

subplot(2,2,[1,3]);
imagesc(range_axis, az_axis, img_db, [-22, 0]);
axis xy;
xlabel('距离向（斜距）偏移 / m');
ylabel('方位向位置 / m');
title(strrep(one_case.name, '_', '\_'));
colormap turbo;
colorbar;
grid on;

subplot(2,2,2);
plot(range_axis, 20*log10(range_projection + eps), 'LineWidth', 1.2);
grid on; ylim([-35, 1]); xlim([-cfg.range_half_span, cfg.range_half_span]);
xlabel('距离向（斜距）偏移 / m'); ylabel('最大投影 / dB');
if info.range_spacing > 0
    title(sprintf('距离向理论间距 %.2f m', info.range_spacing));
else
    title('距离向：未编码');
end

subplot(2,2,4);
plot(az_axis, 20*log10(az_projection + eps), 'LineWidth', 1.2);
grid on; ylim([-35, 1]); xlim([-70, 70]);
xlabel('方位向位置 / m'); ylabel('最大投影 / dB');
if info.az_spacing > 0
    title(sprintf('方位向理论间距 %.2f m', info.az_spacing));
else
    title('方位向：未编码');
end

drawnow;
saveas(fig, fullfile(result_dir, [one_case.name, '.png']));
end

