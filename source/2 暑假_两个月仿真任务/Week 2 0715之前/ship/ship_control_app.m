function ship_control_app()
%SHIP_CONTROL_APP GUI for positioning and simulating four metasurfaces.

app.cfg = ship_default_config();
app.stopRequested = false;
app.isRunning = false;
app.lastResult = [];

app.fig = uifigure('Name', '四超表面 SAR 仿真控制台', ...
    'Position', [80 60 1440 860], 'Color', [0.96 0.97 0.99], ...
    'CloseRequestFcn', @onClose);
root = uigridlayout(app.fig, [1 2]);
root.ColumnWidth = {570, '1x'};
root.Padding = [12 12 12 12];
root.ColumnSpacing = 12;

leftPanel = uipanel(root, 'Title', '参数与操作', 'Scrollable', 'on');
left = uigridlayout(leftPanel, [11 1]);
left.RowHeight = {28, 210, 26, 116, 26, 116, 26, 72, 82, 28, 34};
left.Padding = [10 8 10 10];

uilabel(left, 'Text', '四块超表面（坐标为缩放前的相对位置）', ...
    'FontWeight', 'bold', 'FontSize', 14);
app.surfaceTable = uitable(left, ...
    'ColumnName', {'调制','名称','方位','距离','慢时π','慢时0','快时相位码','重复'}, ...
    'ColumnEditable', true(1,8), ...
    'ColumnWidth', {44,62,55,55,55,55,100,48}, ...
    'CellEditCallback', @onAnyEdit);

uilabel(left, 'Text', '目标与覆盖参数', 'FontWeight', 'bold');
targetGrid = uigridlayout(left, [2 4]);
targetGrid.ColumnWidth = {'1x','1x','1x','1x'};
targetGrid.RowHeight = {50,50};
app.scale = labeledNumber(targetGrid, '场景缩放', 1);
app.spacing = labeledNumber(targetGrid, '三点间距', 2);
app.radius = labeledNumber(targetGrid, '点半径', 3);
app.points = labeledNumber(targetGrid, '每点散射数', 4);
app.downsample = labeledNumber(targetGrid, '抽样间隔', 5);
app.coverAz = labeledNumber(targetGrid, '方位覆盖半宽', 6);
app.coverRg = labeledNumber(targetGrid, '距离覆盖半宽', 7);
app.seed = labeledNumber(targetGrid, '随机种子', 8);

uilabel(left, 'Text', '采样与资源保护', 'FontWeight', 'bold');
samplingGrid = uigridlayout(left, [2 4]);
samplingGrid.ColumnWidth = {'1x','1x','1x','1x'};
samplingGrid.RowHeight = {50,50};
app.sampleMode = labeledDropDown(samplingGrid, '采样模式', {'manual','auto'}, 1);
app.na = labeledNumber(samplingGrid, '方位点数 Na', 2);
app.nr = labeledNumber(samplingGrid, '距离点数 Nr', 3);
app.memoryLimit = labeledNumber(samplingGrid, '内存上限 GB', 4);
app.dynamicRange = labeledNumber(samplingGrid, '显示动态范围 dB', 5);
app.gamma = labeledNumber(samplingGrid, '亮度 Gamma', 6);
app.sampleMode.ValueChangedFcn = @onSampleModeChanged;

uilabel(left, 'Text', '快捷布局', 'FontWeight', 'bold');
layoutButtons = uigridlayout(left, [1 3]);
layoutButtons.ColumnWidth = {'1x','1x','1x'};
uibutton(layoutButtons, 'Text', '十字对称', 'ButtonPushedFcn', @onCrossLayout);
uibutton(layoutButtons, 'Text', '横向排列', 'ButtonPushedFcn', @onHorizontalLayout);
uibutton(layoutButtons, 'Text', '恢复默认', 'ButtonPushedFcn', @onReset);

actions = uigridlayout(left, [2 4]);
actions.ColumnWidth = {'1x','1x','1x','1x'};
actions.RowHeight = {34,34};
uibutton(actions, 'Text', '刷新预览', 'ButtonPushedFcn', @onPreview);
uibutton(actions, 'Text', '保存配置', 'ButtonPushedFcn', @onSaveConfig);
uibutton(actions, 'Text', '载入配置', 'ButtonPushedFcn', @onLoadConfig);
uibutton(actions, 'Text', '生成目标文件', 'ButtonPushedFcn', @onGenerateTargets);
uibutton(actions, 'Text', '生成 MATLAB 代码', 'ButtonPushedFcn', @onGenerateCode);
app.runButton = uibutton(actions, 'Text', '运行 RD 仿真', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.18 0.55 0.88], ...
    'FontColor', 'white', 'ButtonPushedFcn', @onRun);
app.stopButton = uibutton(actions, 'Text', '停止', 'Enable', 'off', ...
    'ButtonPushedFcn', @onStop);
uibutton(actions, 'Text', '导出成像结果', 'ButtonPushedFcn', @onExportResult);

app.estimateLabel = uilabel(left, 'Text', '', 'FontColor', [0.20 0.25 0.35]);
app.gauge = uigauge(left, 'linear', 'Limits', [0 100], 'Value', 0);

rightPanel = uipanel(root, 'BorderType', 'none');
right = uigridlayout(rightPanel, [2 1]);
right.RowHeight = {'1x', 145};
tabs = uitabgroup(right);
previewTab = uitab(tabs, 'Title', '布局预览');
resultTab = uitab(tabs, 'Title', 'RD 成像');
app.previewAxes = uiaxes(previewTab, 'Position', [20 20 800 620]);
app.resultAxes = uiaxes(resultTab, 'Position', [20 20 800 620]);
app.log = uitextarea(right, 'Editable', 'off', 'Value', {'准备就绪。'});

syncControlsFromConfig();
refreshPreview();

    function field = labeledNumber(parent, labelText, position)
        cellGrid = uigridlayout(parent, [2 1]);
        cellGrid.Layout.Row = ceil(position/4);
        cellGrid.Layout.Column = mod(position-1,4)+1;
        cellGrid.RowHeight = {18,26};
        cellGrid.Padding = [2 0 2 0];
        uilabel(cellGrid, 'Text', labelText, 'FontSize', 11);
        field = uieditfield(cellGrid, 'numeric', 'ValueChangedFcn', @onAnyEdit);
    end

    function field = labeledDropDown(parent, labelText, items, position)
        cellGrid = uigridlayout(parent, [2 1]);
        cellGrid.Layout.Row = ceil(position/4);
        cellGrid.Layout.Column = mod(position-1,4)+1;
        cellGrid.RowHeight = {18,26};
        cellGrid.Padding = [2 0 2 0];
        uilabel(cellGrid, 'Text', labelText, 'FontSize', 11);
        field = uidropdown(cellGrid, 'Items', items);
    end

    function syncControlsFromConfig()
        cfg = app.cfg;
        data = cell(4,8);
        for g = 1:4
            s = cfg.metasurfaces(g);
            data(g,:) = {s.enabled, s.name, s.azimuth, s.range, ...
                s.slowPiCount, s.slowZeroCount, phaseCodeText(s.fastPhaseCode), s.fastRepeats};
        end
        app.surfaceTable.Data = data;
        app.scale.Value = cfg.scene.scale;
        app.spacing.Value = cfg.target.pointSpacing;
        app.radius.Value = cfg.target.dotRadius;
        app.points.Value = cfg.target.pointsPerDot;
        app.downsample.Value = cfg.target.downsampleRate;
        app.coverAz.Value = cfg.coverage.azimuthHalfWidth;
        app.coverRg.Value = cfg.coverage.rangeHalfWidth;
        app.seed.Value = cfg.target.randomSeed;
        app.sampleMode.Value = cfg.sampling.mode;
        app.na.Value = cfg.sampling.azimuthSamples;
        app.nr.Value = cfg.sampling.rangeSamples;
        app.memoryLimit.Value = cfg.execution.maxMemoryGB;
        app.dynamicRange.Value = cfg.display.dynamicRangeDB;
        app.gamma.Value = cfg.display.gamma;
        updateSamplingEnable();
        updateEstimate();
    end

    function cfg = readConfigFromControls()
        cfg = app.cfg;
        data = app.surfaceTable.Data;
        for g = 1:4
            cfg.metasurfaces(g).enabled = logical(data{g,1});
            cfg.metasurfaces(g).name = char(string(data{g,2}));
            cfg.metasurfaces(g).azimuth = numericCell(data{g,3}, '方位位置');
            cfg.metasurfaces(g).range = numericCell(data{g,4}, '距离位置');
            cfg.metasurfaces(g).slowPiCount = numericCell(data{g,5}, '慢时 π 个数');
            cfg.metasurfaces(g).slowZeroCount = numericCell(data{g,6}, '慢时 0 个数');
            cfg.metasurfaces(g).fastPhaseCode = parsePhaseCode(data{g,7});
            cfg.metasurfaces(g).fastRepeats = numericCell(data{g,8}, '快时重复次数');
        end
        cfg.scene.scale = app.scale.Value;
        cfg.target.pointSpacing = app.spacing.Value;
        cfg.target.dotRadius = app.radius.Value;
        cfg.target.pointsPerDot = app.points.Value;
        cfg.target.downsampleRate = app.downsample.Value;
        cfg.coverage.azimuthHalfWidth = app.coverAz.Value;
        cfg.coverage.rangeHalfWidth = app.coverRg.Value;
        cfg.target.randomSeed = app.seed.Value;
        cfg.sampling.mode = app.sampleMode.Value;
        cfg.sampling.azimuthSamples = app.na.Value;
        cfg.sampling.rangeSamples = app.nr.Value;
        cfg.execution.maxMemoryGB = app.memoryLimit.Value;
        cfg.display.dynamicRangeDB = app.dynamicRange.Value;
        cfg.display.gamma = app.gamma.Value;
        [cfg, ~] = ship_validate_config(cfg);
    end

    function onAnyEdit(~,~)
        updateEstimate();
    end

    function updateEstimate()
        try
            cfg = readConfigFromControls();
            [~, info] = ship_validate_config(cfg);
            app.estimateLabel.Text = sprintf('预计：目标 %d，Na × Nr = %d × %d，峰值内存约 %.2f GB', ...
                info.usedTargetCount, info.na, info.nr, info.estimatedMemoryGB);
            if isempty(info.warnings)
                app.estimateLabel.FontColor = [0.10 0.45 0.20];
            else
                app.estimateLabel.FontColor = [0.85 0.33 0.10];
            end
        catch ME
            app.estimateLabel.Text = ['参数待修正：' ME.message];
            app.estimateLabel.FontColor = [0.85 0.15 0.15];
        end
    end

    function refreshPreview()
        try
            app.cfg = readConfigFromControls();
            [points, group] = ship_generate_targets(app.cfg, false);
            cla(app.previewAxes);
            hold(app.previewAxes, 'on');
            colors = lines(4);
            stride = max(1, floor(size(points,1)/4000));
            for g = 1:4
                pick = find(group == g);
                pick = pick(1:stride:end);
                scatter(app.previewAxes, points(pick,2), points(pick,1), 7, ...
                    colors(g,:), 'filled', 'MarkerFaceAlpha', 0.35, ...
                    'DisplayName', app.cfg.metasurfaces(g).name);
                s = app.cfg.metasurfaces(g);
                x = s.range + app.coverRg.Value*[-1 1 1 -1 -1];
                y = s.azimuth + app.coverAz.Value*[-1 -1 1 1 -1];
                plot(app.previewAxes, x, y, '-', 'Color', colors(g,:), ...
                    'LineWidth', 1.8, 'HandleVisibility', 'off');
                text(app.previewAxes, s.range, s.azimuth, ['  ' s.name], ...
                    'Color', colors(g,:), 'FontWeight', 'bold', ...
                    'HandleVisibility', 'off');
            end
            hold(app.previewAxes, 'off');
            axis(app.previewAxes, 'equal');
            grid(app.previewAxes, 'on');
            xlabel(app.previewAxes, '距离向相对位置 (m)');
            ylabel(app.previewAxes, '方位向相对位置 (m)');
            title(app.previewAxes, '四块超表面、三联点目标与覆盖范围');
            legend(app.previewAxes, 'show', 'Location', 'bestoutside');
            updateEstimate();
        catch ME
            showError(ME);
        end
    end

    function onPreview(~,~)
        refreshPreview();
        appendLog('布局预览已刷新。');
    end

    function onCrossLayout(~,~)
        d = app.surfaceTable.Data;
        centers = [0 -1; 0 1; -1 0; 1 0];
        for g = 1:4
            d{g,3} = centers(g,1);
            d{g,4} = centers(g,2);
        end
        app.surfaceTable.Data = d;
        refreshPreview();
    end

    function onHorizontalLayout(~,~)
        d = app.surfaceTable.Data;
        ranges = [-1.5 -0.5 0.5 1.5];
        for g = 1:4
            d{g,3} = 0;
            d{g,4} = ranges(g);
        end
        app.surfaceTable.Data = d;
        refreshPreview();
    end

    function onReset(~,~)
        app.cfg = ship_default_config();
        syncControlsFromConfig();
        refreshPreview();
        appendLog('已恢复默认参数。');
    end

    function onSampleModeChanged(~,~)
        updateSamplingEnable();
        updateEstimate();
    end

    function updateSamplingEnable()
        manual = strcmp(app.sampleMode.Value, 'manual');
        app.na.Enable = onOff(manual);
        app.nr.Enable = onOff(manual);
    end

    function onSaveConfig(~,~)
        try
            app.cfg = readConfigFromControls();
            [file,path] = uiputfile({'*.mat','MAT 配置';'*.json','JSON 配置'}, ...
                '保存配置', 'ship_config.mat');
            if isequal(file,0), return; end
            fullName = fullfile(path,file);
            cfg = app.cfg; %#ok<NASGU>
            if endsWith(file, '.json', 'IgnoreCase', true)
                fid = fopen(fullName, 'w', 'n', 'UTF-8');
                if fid < 0, error('ship:FileWrite','无法写入配置文件。'); end
                clean = onCleanup(@() fclose(fid)); %#ok<NASGU>
                fwrite(fid, jsonencode(cfg, 'PrettyPrint', true), 'char');
            else
                save(fullName, 'cfg');
            end
            appendLog(['配置已保存：' fullName]);
        catch ME
            showError(ME);
        end
    end

    function onLoadConfig(~,~)
        try
            [file,path] = uigetfile({'*.mat;*.json','配置文件 (*.mat, *.json)'}, '载入配置');
            if isequal(file,0), return; end
            fullName = fullfile(path,file);
            if endsWith(file, '.json', 'IgnoreCase', true)
                cfg = jsondecode(fileread(fullName));
            else
                loaded = load(fullName, 'cfg');
                cfg = loaded.cfg;
            end
            [cfg, ~] = ship_validate_config(cfg);
            app.cfg = cfg;
            syncControlsFromConfig();
            refreshPreview();
            appendLog(['配置已载入：' fullName]);
        catch ME
            showError(ME);
        end
    end

    function onGenerateTargets(~,~)
        try
            app.cfg = readConfigFromControls();
            folder = uigetdir(pwd, '选择目标文件保存目录');
            if isequal(folder,0), return; end
            old = pwd;
            clean = onCleanup(@() cd(old)); %#ok<NASGU>
            cd(folder);
            [points,~] = ship_generate_targets(app.cfg, true);
            appendLog(sprintf('已生成 %d 个散射点：%s', size(points,1), folder));
        catch ME
            showError(ME);
        end
    end

    function onGenerateCode(~,~)
        try
            app.cfg = readConfigFromControls();
            [file,path] = uiputfile('*.m', '生成可运行 MATLAB 代码', 'run_ship_generated.m');
            if isequal(file,0), return; end
            ship_export_script(app.cfg, fullfile(path,file));
            appendLog(['已生成代码：' fullfile(path,file)]);
        catch ME
            showError(ME);
        end
    end

    function onRun(~,~)
        if app.isRunning, return; end
        try
            app.cfg = readConfigFromControls();
            [~, info] = ship_validate_config(app.cfg);
            if ~isempty(info.warnings)
                answer = uiconfirm(app.fig, strjoin(info.warnings, newline), ...
                    '运行前提示', 'Options', {'继续','取消'}, 'DefaultOption', 2, 'CancelOption', 2);
                if strcmp(answer, '取消'), return; end
            end
            app.isRunning = true;
            app.stopRequested = false;
            app.runButton.Enable = 'off';
            app.stopButton.Enable = 'on';
            app.gauge.Value = 0;
            appendLog('开始运行 RD 仿真。');
            app.lastResult = ship_run_simulation(app.cfg, @progressUpdate);
            drawResult(app.lastResult);
            appendLog(sprintf('仿真完成。覆盖点数：[ %s]', num2str(app.lastResult.coverCount.')));
        catch ME
            if strcmp(ME.identifier, 'ship:Cancelled')
                appendLog('仿真已由用户停止。');
            else
                showError(ME);
            end
        end
        app.isRunning = false;
        app.runButton.Enable = 'on';
        app.stopButton.Enable = 'off';
    end

    function keepGoing = progressUpdate(fraction, message)
        if ~isvalid(app.fig)
            keepGoing = false;
            return
        end
        app.gauge.Value = max(0, min(100, 100*fraction));
        app.estimateLabel.Text = message;
        drawnow limitrate;
        keepGoing = ~app.stopRequested;
    end

    function onStop(~,~)
        app.stopRequested = true;
        app.stopButton.Enable = 'off';
        appendLog('正在安全停止……');
    end

    function drawResult(result)
        imagesc(app.resultAxes, result.rangeAxis, result.azimuthAxis, result.imageDB);
        app.resultAxes.YDir = 'normal';
        axis(app.resultAxes, 'image');
        colormap(app.resultAxes, jet);
        colorbar(app.resultAxes);
        clim(app.resultAxes, [-app.cfg.display.dynamicRangeDB, 0]);
        xlabel(app.resultAxes, '距离向 (m)');
        ylabel(app.resultAxes, '方位向 (m)');
        title(app.resultAxes, '四超表面调制 RD 成像结果 (dB)');
    end

    function onExportResult(~,~)
        if isempty(app.lastResult)
            uialert(app.fig, '请先完成一次仿真。', '暂无结果');
            return
        end
        [file,path] = uiputfile('*.mat', '导出仿真结果', 'ship_result.mat');
        if isequal(file,0), return; end
        result = app.lastResult; %#ok<NASGU>
        save(fullfile(path,file), 'result', '-v7.3');
        appendLog(['结果已导出：' fullfile(path,file)]);
    end

    function onClose(~,~)
        if app.isRunning
            app.stopRequested = true;
            return
        end
        delete(app.fig);
    end

    function showError(ME)
        appendLog(['错误：' ME.message]);
        uialert(app.fig, ME.message, '操作失败');
    end

    function appendLog(message)
        stamp = char(datetime('now','Format','HH:mm:ss'));
        values = app.log.Value;
        if ischar(values), values = {values}; end
        values{end+1} = sprintf('[%s] %s', stamp, message);
        if numel(values) > 150, values = values(end-149:end); end
        app.log.Value = values;
        scroll(app.log, 'bottom');
    end
end

function value = numericCell(value, label)
if ischar(value) || isstring(value)
    value = str2double(value);
end
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    error('ship:InvalidInput', '%s 必须是有效数字。', label);
end
end

function code = parsePhaseCode(value)
if isnumeric(value)
    code = reshape(value, 1, []);
    return
end
text = lower(strtrim(char(string(value))));
text = strrep(text, '[', '');
text = strrep(text, ']', '');
tokens = regexp(text, '[,;\s]+', 'split');
tokens = tokens(~cellfun('isempty', tokens));
code = zeros(1, numel(tokens));
for k = 1:numel(tokens)
    token = tokens{k};
    number = str2double(token);
    if isfinite(number)
        code(k) = number;
        continue
    end
    match = regexp(token, '^([+-]?)(?:(\d+(?:\.\d+)?)\*)?pi(?:/(\d+(?:\.\d+)?))?$', 'tokens', 'once');
    if isempty(match)
        error('ship:InvalidInput', '无法识别相位码“%s”。可输入 pi、-pi、pi/2 或数字。', token);
    end
    signValue = 1;
    if strcmp(match{1}, '-'), signValue = -1; end
    multiplier = 1;
    % REGEXP may omit unmatched trailing token groups. For a plain "pi"
    % token MATCH can therefore contain only the sign group.
    if numel(match) >= 2 && ~isempty(match{2})
        multiplier = str2double(match{2});
    end
    divisor = 1;
    if numel(match) >= 3 && ~isempty(match{3}), divisor = str2double(match{3}); end
    code(k) = signValue * multiplier * pi / divisor;
end
if isempty(code)
    error('ship:InvalidInput', '快时相位码不能为空。');
end
end

function text = phaseCodeText(code)
parts = arrayfun(@formatPhase, code, 'UniformOutput', false);
text = strjoin(parts, ' ');
end

function text = formatPhase(value)
if abs(value) < 1e-12
    text = '0';
elseif abs(value-pi) < 1e-12
    text = 'pi';
elseif abs(value+pi) < 1e-12
    text = '-pi';
else
    text = sprintf('%.6g', value);
end
end

function value = onOff(tf)
if tf, value = 'on'; else, value = 'off'; end
end
