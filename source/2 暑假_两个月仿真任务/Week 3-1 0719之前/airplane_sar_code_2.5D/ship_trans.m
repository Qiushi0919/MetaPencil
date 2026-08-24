%% ship_trans.m
% 功能：读取飞机 STL 三角网格，按表面积随机采样，
%       保留高度和面元法向，供二维 SAR 成像使用。
% 输出：airplane_scatter_points.mat
% 数据格式：my_data = [方位, 地距, 高度, n_方位, n_地距, n_高度]

clear; clc; close all;

%% 1. 用户参数
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

stl_file = fullfile(script_dir, 'airplane_model.stl');

% 本模型中：模型 Y 轴对应机身长度，模型 X 轴对应翼展
plane_length_m   = 6;   % 机身长度，最终对应方位向尺寸
plane_wingspan_m = 4;   % 翼展，最终对应距离向尺寸
plane_height_m   = 0.9;   % 显式高度，避免高度随长/宽缩放任意变化

% 散射点数量。原 SHIP.m 的计算量较大，建议先用 400~800 点。
num_scatter_points = 600;

% 飞机在二维成像平面内的旋转角。小角度偏航避免与像素轴完全重合。
yaw_deg = 12;

% 固定随机种子，仅用于确保每次表面采样位置一致。
rng(2026);

%% 2. 读取 STL 网格
if ~isfile(stl_file)
    error('找不到模型文件：%s', stl_file);
end

[F, V] = readSTLCompatible(stl_file);

fprintf('读取模型成功：顶点数 = %d，三角面数 = %d\n', ...
    size(V,1), size(F,1));

%% 3. 水平居中、底部对齐地面，并缩放为设定尺寸
bbox_min = min(V, [], 1);
bbox_max = max(V, [], 1);
V(:,1:2) = V(:,1:2) - (bbox_min(1:2) + bbox_max(1:2)) / 2;
V(:,3) = V(:,3) - bbox_min(3);

extent_xyz = max(V, [], 1) - min(V, [], 1);

% 分别缩放到设定的翼展、机身长度和高度
scale_x = plane_wingspan_m / extent_xyz(1);
scale_y = plane_length_m   / extent_xyz(2);
scale_z = plane_height_m / extent_xyz(3);

V(:,1) = V(:,1) * scale_x;
V(:,2) = V(:,2) * scale_y;
V(:,3) = V(:,3) * scale_z;

fprintf('缩放后模型尺寸：翼展 %.3f m，长度 %.3f m，高度 %.3f m\n', ...
    max(V(:,1))-min(V(:,1)), ...
    max(V(:,2))-min(V(:,2)), ...
    max(V(:,3))-min(V(:,3)));

%% 4. 按三角面面积进行表面采样
% 大三角面被抽到的概率更高，小三角面概率更低。
% 这样不会出现“网格越密，散射点越多”的人为偏差。
[P, surface_normal] = sampleMeshSurface(F, V, num_scatter_points);

%% 5. 生成 2.5D SAR 散射点
% SAR 图像纵轴：方位向
% SAR 图像横轴：距离向
% 模型 Y 轴作为方位向，模型 X 轴作为距离向
azimuth = P(:,2);
range_dir = P(:,1);
height = P(:,3);
normal_azimuth = surface_normal(:,2);
normal_range = surface_normal(:,1);
normal_height = surface_normal(:,3);

% 二维平面内旋转
R2 = [cosd(yaw_deg), -sind(yaw_deg); ...
      sind(yaw_deg),  cosd(yaw_deg)];
rotated_xy = (R2 * [azimuth, range_dir].').';
rotated_normal_xy = (R2 * [normal_azimuth, normal_range].').';

azimuth = rotated_xy(:,1);
range_dir = rotated_xy(:,2);
normal_azimuth = rotated_normal_xy(:,1);
normal_range = rotated_normal_xy(:,2);

my_data = [azimuth, range_dir, height, ...
    normal_azimuth, normal_range, normal_height];

fprintf('最终二维散射点数量 = %d\n', size(my_data,1));
fprintf('方位向范围：%.3f ~ %.3f m\n', ...
    min(my_data(:,1)), max(my_data(:,1)));
fprintf('距离向范围：%.3f ~ %.3f m\n', ...
    min(my_data(:,2)), max(my_data(:,2)));
fprintf('高度范围：%.3f ~ %.3f m\n', ...
    min(my_data(:,3)), max(my_data(:,3)));

%% 6. 显示模型俯视图与二维散射点
figure_mesh = figure('Color','w','Name','飞机三角网格俯视图');
patch('Faces', F, 'Vertices', V, ...
    'FaceColor', [0.75, 0.82, 0.90], ...
    'EdgeColor', [0.30, 0.35, 0.40], ...
    'LineWidth', 0.15);
view(2);
axis equal;
grid on;
xlabel('模型 X / 翼展方向 (m)');
ylabel('模型 Y / 机身方向 (m)');
title(sprintf('飞机三角网格俯视图：%d 个三角面', size(F,1)));

figure_scatter = figure('Color','w','Name','飞机二维散射点');
scatter(my_data(:,2), my_data(:,1), 16, [0.25, 0.25, 0.25], 'filled');
axis equal;
grid on;
xlabel('距离向 (m)');
ylabel('方位向 (m)');
title(sprintf('飞机 2.5D 散射点分布：%d 点，尺寸约 %.1f m × %.1f m', ...
    size(my_data,1), plane_wingspan_m, plane_length_m));

%% 7. 自动保存
mat_file = fullfile(script_dir, 'airplane_scatter_points.mat');
txt_file = fullfile(script_dir, 'airplane_scatter_points.txt');
preview_file = fullfile(script_dir, 'airplane_scatter_preview.png');
mesh_preview_file = fullfile(script_dir, 'airplane_mesh_preview.png');

scatter_metadata = struct( ...
    'format', '[azimuth, ground_range, height, n_azimuth, n_range, n_height]', ...
    'plane_length_m', plane_length_m, ...
    'plane_wingspan_m', plane_wingspan_m, ...
    'plane_height_m', plane_height_m, ...
    'yaw_deg', yaw_deg);

save(mat_file, 'my_data', 'scatter_metadata');
writematrix(my_data, txt_file, 'Delimiter', 'tab');

if exist('exportgraphics', 'file') == 2
    exportgraphics(figure_scatter, preview_file, 'Resolution', 180);
    exportgraphics(figure_mesh, mesh_preview_file, 'Resolution', 180);
else
    saveas(figure_scatter, preview_file);
    saveas(figure_mesh, mesh_preview_file);
end

fprintf('\n已保存：\n%s\n%s\n%s\n%s\n', ...
    mat_file, txt_file, preview_file, mesh_preview_file);

%% ====================== 局部函数 ======================
function [P, selected_normal] = sampleMeshSurface(F, V, N)
% 按三角形面积抽取面，再在面内做均匀重心采样

    v1 = V(F(:,1),:);
    v2 = V(F(:,2),:);
    v3 = V(F(:,3),:);

    cross_vec = cross(v2-v1, v3-v1, 2);
    twice_area = sqrt(sum(cross_vec.^2, 2));
    face_area = 0.5 * twice_area;

    valid = isfinite(face_area) & face_area > eps;
    F_valid = F(valid,:);
    face_area = face_area(valid);
    face_normal = cross_vec(valid,:) ./ twice_area(valid);

    % 尽量将法向统一为朝外。对封闭/近似封闭飞机网格这个判断足够稳定。
    model_center = mean(V, 1);
    face_center = (v1(valid,:) + v2(valid,:) + v3(valid,:)) / 3;
    flip_mask = sum(face_normal .* (face_center-model_center), 2) < 0;
    face_normal(flip_mask,:) = -face_normal(flip_mask,:);

    if isempty(face_area)
        error('模型中没有有效三角面。');
    end

    cdf = cumsum(face_area) / sum(face_area);
    u = rand(N,1);
    selected_face = zeros(N,1);

    % N 通常只有几百，循环查找足够稳定，也不依赖额外工具箱
    for n = 1:N
        selected_face(n) = find(cdf >= u(n), 1, 'first');
    end

    chosen = F_valid(selected_face,:);
    selected_normal = face_normal(selected_face,:);
    a = V(chosen(:,1),:);
    b = V(chosen(:,2),:);
    c = V(chosen(:,3),:);

    % 三角形内部均匀随机采样
    r1 = sqrt(rand(N,1));
    r2 = rand(N,1);

    P = (1-r1).*a + r1.*(1-r2).*b + r1.*r2.*c;
end

function [F, V] = readSTLCompatible(filename)
% 优先使用 MATLAB 自带 stlread；若版本不兼容，则读取本项目的二进制 STL。

    try
        TR = stlread(filename);

        if isa(TR, 'triangulation')
            F = TR.ConnectivityList;
            V = TR.Points;
            return;
        end

        if isstruct(TR)
            if isfield(TR, 'ConnectivityList') && isfield(TR, 'Points')
                F = TR.ConnectivityList;
                V = TR.Points;
                return;
            elseif isfield(TR, 'faces') && isfield(TR, 'vertices')
                F = TR.faces;
                V = TR.vertices;
                return;
            end
        end
    catch
        % 进入下方二进制 STL 读取器
    end

    [F, V] = readBinarySTL(filename);
end

function [F, V] = readBinarySTL(filename)
% 简单二进制 STL 读取器，不需要额外工具箱

    fid = fopen(filename, 'rb');
    if fid < 0
        error('无法打开 STL 文件：%s', filename);
    end
    cleanup_obj = onCleanup(@() fclose(fid));

    fseek(fid, 80, 'bof');
    num_faces = fread(fid, 1, 'uint32=>double');

    if isempty(num_faces) || num_faces <= 0
        error('STL 文件格式无法识别。');
    end

    V = zeros(num_faces*3, 3);
    F = reshape(1:num_faces*3, 3, []).';

    for i = 1:num_faces
        fread(fid, 3, 'float32');                % 法向量，当前不使用
        tri = fread(fid, [3,3], 'float32').';    % 3 个顶点
        fread(fid, 1, 'uint16');                 % attribute byte count

        row = (i-1)*3 + (1:3);
        V(row,:) = tri;
    end
end
