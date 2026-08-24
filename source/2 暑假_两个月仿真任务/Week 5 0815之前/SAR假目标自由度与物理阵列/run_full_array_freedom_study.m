%% 物理逻辑阵列驱动的SAR假目标自由度完整仿真
% 所有结果均经过：
%   最终整数控制阵列 -> 单极化2-bit四态时序 -> 原始LFM回波 -> RD成像
% 不在成像后复制、平移或粘贴飞机图像。
%
% 两级阵列结构：
%   外层 M×M 逻辑通道超单元：每个宏格指定一个目标通道H_k；
%   内层 4×4 时延子单元：每个H_k都使用(d_r,d_a)笛卡尔积，
%       d=[0,1/10,5/6,14/15]T，抑制-3/+5主要量化副谐波。
% 外层与内层的整数分配直接进入回波调制矩阵，因此图中的控制阵列
% 与仿真采用的是同一份配置。

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
output_dir = fullfile(script_dir, 'results_full_array_exact');
control_dir = fullfile(output_dir, 'control_tables');
input_dir = fullfile(script_dir, 'phone_sketch_input');
if ~exist(output_dir,'dir'), mkdir(output_dir); end
if ~exist(control_dir,'dir'), mkdir(control_dir); end
if ~exist(input_dir,'dir'), mkdir(input_dir); end

set(groot,'defaultAxesFontName','PingFang SC');
set(groot,'defaultTextFontName','PingFang SC');
set(groot,'defaultAxesFontSize',11);

%% 1. 雷达与成像参数：降低散射点数量，但保留完整原始回波链路
c = 3e8;
fc = 10e9;
lambda = c/fc;
Tp = 1e-6;
beta = deg2rad(60);
H0 = 500;
v_x = 80;
Y0 = H0*tan(beta);
R0 = hypot(H0,Y0);

% 0.25 m使8 m网格恰好对应整数个距离/方位调制周期，减少有限
% 脉冲和有限孔径截断造成的零阶泄漏，同时仍能快速跑完全部案例。
desired_ground_range_resolution = 0.25;
desired_az_resolution = 0.25;
max_scatter_points = 700;
display_half_width_m = 29;
display_floor_db = -36;

desired_slant_range_resolution = ...
    desired_ground_range_resolution*sin(beta);
Br = c/(2*desired_slant_range_resolution);
Kr = Br/Tp;
Fs = 1.20*Br;

synthetic_aperture_length = lambda*R0/(2*desired_az_resolution);
aperture_time = synthetic_aperture_length/v_x;
Ka = -2*v_x^2/(lambda*R0);
Ba = abs(Ka)*aperture_time;
PRF = ceil(1.20*Ba);
Na = ceil(aperture_time*PRF);
if mod(Na,2)~=0, Na=Na+1; end
tm = ((-Na/2):(Na/2-1))/PRF;
x_radar = tm*v_x;

range_margin_m = 48;
fast_time_span = Tp + 4*range_margin_m/c;
Nr = 2^nextpow2(ceil(fast_time_span*Fs));
t = 2*R0/c + ((-Nr/2):(Nr/2-1))/Fs;
dt = 1/Fs;
fast_time_relative = t-2*R0/c;

fprintf('完整回波配置：散射点<=%d，Na=%d，Nr=%d\n', ...
    max_scatter_points,Na,Nr);
fprintf('地距/方位分辨率：%.3f/%.3f m\n', ...
    desired_ground_range_resolution,desired_az_resolution);

%% 2. 加载歼-36散射点并只计算一次中心单机原始回波
scatter_file = fullfile(script_dir,'..','..','Week 4 0813之前', ...
    '歼36_4x4机群_sar_code_2D','airplane_scatter_points.mat');
if ~isfile(scatter_file)
    error('找不到歼-36散射点：%s',scatter_file);
end
loaded = load(scatter_file,'my_data');
target_all = loaded.my_data;
if size(target_all,1)>max_scatter_points
    keep_index = round(linspace(1,size(target_all,1),max_scatter_points));
    target = target_all(keep_index,:);
else
    target = target_all;
end
target_azimuth = target(:,1);
target_ground_range = target(:,2)+Y0;
Ntar = size(target,1);

sr_center = complex(zeros(Na,Nr));
fprintf('生成中心歼-36原始LFM回波：%d个散射点...\n',Ntar);
for point_index = 1:Ntar
    for slow_index = 1:Na
        delta_azimuth = x_radar(slow_index)-target_azimuth(point_index);
        r_inst = sqrt(delta_azimuth^2 + ...
            target_ground_range(point_index)^2 + H0^2);
        scatter_amplitude = (R0/r_inst)^2;
        tau = t-2*r_inst/c;
        pulse_mask = abs(tau)<=Tp/2;
        sr_center(slow_index,:) = sr_center(slow_index,:) + ...
            scatter_amplitude.*pulse_mask.*exp(1j*pi*Kr*tau.^2).* ...
            exp(-1j*4*pi*r_inst/lambda);
    end
    if mod(point_index,100)==0 || point_index==Ntar
        fprintf('  散射点 %d/%d\n',point_index,Ntar);
    end
end

[img_reference,R_axis_slant_relative,Az_axis] = rdFocus(sr_center,t,tm,dt, ...
    c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
Range_axis_ground = R_axis_slant_relative/sin(beta);
reference_peak = max(abs(img_reference(:)))+eps;

%% 3. 物理2-bit阵列参数
state_response = exp(1j*deg2rad([0,90,180,270]));
state_dwell_fraction = [0.25,0.25,0.25,0.25];
inner_delay_fraction = [0,1/10,5/6,14/15];

physics = struct('c',c,'Kr',Kr,'Ka',Ka,'beta',beta,'v_x',v_x, ...
    'fast_time_relative',fast_time_relative,'tm',tm, ...
    'state_response',state_response, ...
    'state_dwell_fraction',state_dwell_fraction, ...
    'inner_delay_fraction',inner_delay_fraction);

grid_spacing_m = 8;
single_defs = {
    '1to1',4,[1,1],'1→1：单个指定假目标';
    '1to2',4,[-1,1;1,1],'1→2：两个独立位置';
    '1to3',5,[-1,1;0,1;1,1],'1→3：三点线目标';
    '1to4',4,[-1,-1;1,-1;-1,1;1,1],'1→4：2×2二维目标';
    '1to5',5,[0,0;-1,0;1,0;0,-1;0,1],'1→5：十字五点目标';
    '1to9',7,cartesianPairs(-1:1,-1:1),'1→9：3×3二维目标';
    '1to16',4,cartesianPairs(-1.5:1:1.5,-1.5:1:1.5), ...
    '1→16：4×4二维目标'};

single_images = cell(size(single_defs,1),1);
single_configs = cell(size(single_defs,1),1);

%% 4. 单架飞机1→N：每个案例都从原始回波重新调制并RD成像
for case_index = 1:size(single_defs,1)
    tag = single_defs{case_index,1};
    outer_N = single_defs{case_index,2};
    order_pairs = single_defs{case_index,3};
    case_title = single_defs{case_index,4};
    offsets = order_pairs*grid_spacing_m;
    tile_map = balancedTileMap(outer_N,size(offsets,1));
    [response,channel_table,tile_table] = compilePhysicalResponse( ...
        offsets,tile_map,physics);
    sr_meta = sr_center.*response;
    [img,~,~] = rdFocus(sr_meta,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
    target_positions = offsets;

    writetable(channel_table,fullfile(control_dir, ...
        sprintf('single_%s_channels.csv',tag)));
    writetable(tile_table,fullfile(control_dir, ...
        sprintf('single_%s_outer_%dx%d_tiles.csv',tag,outer_N,outer_N)));

    fig = pairedPhysicalResultFigure(tile_map,offsets,img, ...
        Range_axis_ground,Az_axis,reference_peak,display_floor_db, ...
        [0,0],target_positions,case_title,inner_delay_fraction);
    exportgraphics(fig,fullfile(output_dir,sprintf('single_%s_pair.png',tag)), ...
        'Resolution',220);
    close(fig);

    fig = createWideFigure();
    plotSarDbWithSources(img,Range_axis_ground,Az_axis,reference_peak, ...
        display_floor_db,display_half_width_m,[0,0],target_positions);
    title(sprintf('%s｜完整原始回波+RD成像',case_title));
    exportgraphics(fig,fullfile(output_dir,sprintf('single_%s_sar.png',tag)), ...
        'Resolution',220);
    close(fig);

    single_images{case_index} = img;
    single_configs{case_index} = struct('tag',tag,'outer_N',outer_N, ...
        'offsets',offsets,'tile_map',tile_map,'channel_table',channel_table);
end

fig = createWideFigure();
tiledlayout(fig,2,4,'TileSpacing','compact','Padding','compact');
for case_index=1:size(single_defs,1)
    nexttile;
    plotSarDbWithSources(single_images{case_index},Range_axis_ground, ...
        Az_axis,reference_peak,display_floor_db,display_half_width_m, ...
        [0,0],single_configs{case_index}.offsets);
    title(sprintf('%s｜外层%d×%d',single_defs{case_index,4}, ...
        single_defs{case_index,2},single_defs{case_index,2}));
end
nexttile; axis off;
text(0.05,0.72,'所有7个案例均使用同一完整链路：', ...
    'FontSize',16,'FontWeight','bold');
text(0.05,0.52,'整数逻辑阵列 → 2-bit四态码', 'FontSize',14);
text(0.05,0.37,'→ 原始LFM回波 → RD成像', 'FontSize',14);
text(0.05,0.17,'没有图像域复制/平移。','FontSize',14,'Color',[0.75 0.10 0.10]);
% 总标题由PPT添加，这里不再使用sgtitle，避免与第一行子图标题重叠。
exportgraphics(fig,fullfile(output_dir,'single_1toN_overview.png'), ...
    'Resolution',220);
close(fig);

%% 5. 两架飞机线目标：共享码本、重叠和独立码本
source_two = [-4,0;4,0];
two_case_defs = {
    '共享2通道核：2架→4个像', ...
    {[-1,1;1,1]*grid_spacing_m,[-1,1;1,1]*grid_spacing_m},4;
    '共享3通道核：重叠位置相干增强', ...
    {[-1,1;0,1;1,1]*grid_spacing_m, ...
     [-1,1;0,1;1,1]*grid_spacing_m},5;
    '独立码本：两架生成非对称编队', ...
    {[-1,1;0,1;1,1]*grid_spacing_m, ...
     [-1,-1;0,-1;1,-1]*grid_spacing_m},5};

two_images = cell(3,1);
two_targets = cell(3,1);
for case_index=1:3
    kernels = two_case_defs{case_index,2};
    outer_N = two_case_defs{case_index,3};
    sr_case = complex(zeros(size(sr_center)));
    target_positions = [];
    for source_index=1:2
        sr_source = shiftEcho(sr_center,source_two(source_index,1), ...
            source_two(source_index,2),t,tm,c,R0,Kr,Ka,beta,v_x);
        tile_map = balancedTileMap(outer_N,size(kernels{source_index},1));
        response = compilePhysicalResponse(kernels{source_index},tile_map,physics);
        sr_case = sr_case + sr_source.*response;
        target_positions = [target_positions; ... %#ok<AGROW>
            source_two(source_index,:)+kernels{source_index}];
    end
    [two_images{case_index},~,~] = rdFocus(sr_case,t,tm,dt,c,R0,Tp,Kr, ...
        lambda,v_x,Ka,PRF);
    two_targets{case_index} = target_positions;
end

fig = createWideFigure();
tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
for case_index=1:3
    nexttile;
    plotSarDbWithSources(two_images{case_index},Range_axis_ground,Az_axis, ...
        reference_peak,display_floor_db,display_half_width_m, ...
        source_two,two_targets{case_index});
    title(two_case_defs{case_index,1});
end
sgtitle('两架真实飞机线目标：所有结果由对应整数控制阵列的原始回波得到');
exportgraphics(fig,fullfile(output_dir,'two_aircraft_line_freedom.png'), ...
    'Resolution',220);
close(fig);

%% 6. 四角四架飞机：每架使用4×4外层阵列的四通道核
source_four = [-12,-12;12,-12;-12,12;12,12];
sr_four = complex(zeros(size(sr_center)));
target_four = [];
tile_map_four = balancedTileMap(4,4);
first_offsets = [];
for source_index=1:4
    source = source_four(source_index,:);
    inward_range = -sign(source(1))*grid_spacing_m;
    inward_az = -sign(source(2))*grid_spacing_m;
    offsets = [0,0;inward_range,0;0,inward_az;inward_range,inward_az];
    if source_index==1, first_offsets=offsets; end
    response = compilePhysicalResponse(offsets,tile_map_four,physics);
    sr_source = shiftEcho(sr_center,source(1),source(2),t,tm,c,R0,Kr,Ka,beta,v_x);
    sr_four = sr_four + sr_source.*response;
    target_four = [target_four;source+offsets]; %#ok<AGROW>
end
[img_four,~,~] = rdFocus(sr_four,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);

fig = pairedPhysicalResultFigure(tile_map_four,first_offsets,img_four, ...
    Range_axis_ground,Az_axis,reference_peak,display_floor_db, ...
    source_four,target_four,'四角4架→4×4共16架目标群',inner_delay_fraction);
exportgraphics(fig,fullfile(output_dir,'four_aircraft_7x7_to16_pair.png'), ...
    'Resolution',220);
close(fig);

%% 7. 4×4、5×5、7×7真实外层控制阵列示例
physical_defs = {
    4,[-1,-1;1,-1;-1,1;1,1]*grid_spacing_m,'4×4外层：4个等幅通道';
    5,[0,0;-1,0;1,0;0,-1;0,1]*grid_spacing_m,'5×5外层：5个等幅通道';
    7,cartesianPairs(-1:1,-1:1)*grid_spacing_m,'7×7外层：9个近等幅通道'};
for index=1:size(physical_defs,1)
    outer_N=physical_defs{index,1};
    offsets=physical_defs{index,2};
    title_text=physical_defs{index,3};
    tile_map=balancedTileMap(outer_N,size(offsets,1));
    response=compilePhysicalResponse(offsets,tile_map,physics);
    [img,~,~]=rdFocus(sr_center.*response,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
    fig=pairedPhysicalResultFigure(tile_map,offsets,img,Range_axis_ground, ...
        Az_axis,reference_peak,display_floor_db,[0,0],offsets, ...
        title_text,inner_delay_fraction);
    exportgraphics(fig,fullfile(output_dir, ...
        sprintf('physical_%dx%d_system_pair.png',outer_N,outer_N)), ...
        'Resolution',220);
    close(fig);
end

fig=createWideFigure();
tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
for index=1:size(physical_defs,1)
    nexttile;
    outer_N=physical_defs{index,1};
    offsets=physical_defs{index,2};
    tile_map=balancedTileMap(outer_N,size(offsets,1));
    plotOuterTileMap(tile_map,offsets,inner_delay_fraction);
    title(sprintf('%d×%d外层逻辑阵列',outer_N,outer_N));
end
sgtitle('最终阵列：外层宏格分配目标通道；每个宏格内部重复4×4时延子单元');
exportgraphics(fig,fullfile(output_dir,'physical_supercells_compare.png'), ...
    'Resolution',220);
close(fig);

%% 8. 手机手绘形状：7×7点阵编译为真实控制通道
heart_mask = logical([ ...
    0 1 1 0 1 1 0;
    1 1 1 1 1 1 1;
    1 1 1 1 1 1 1;
    0 1 1 1 1 1 0;
    0 0 1 1 1 0 0;
    0 0 0 1 0 0 0;
    0 0 0 0 0 0 0]);
arrow_mask = logical([ ...
    0 0 0 1 0 0 0;
    0 0 0 1 1 0 0;
    1 1 1 1 1 1 0;
    1 1 1 1 1 1 1;
    1 1 1 1 1 1 0;
    0 0 0 1 1 0 0;
    0 0 0 1 0 0 0]);
z_mask = logical([ ...
    1 1 1 1 1 1 1;
    0 0 0 0 0 1 1;
    0 0 0 0 1 1 0;
    0 0 0 1 1 0 0;
    0 0 1 1 0 0 0;
    0 1 1 0 0 0 0;
    1 1 1 1 1 1 1]);

writematrix(double(heart_mask),fullfile(input_dir,'sample_heart_7x7.csv'));
writematrix(double(arrow_mask),fullfile(input_dir,'sample_arrow_7x7.csv'));
writematrix(double(z_mask),fullfile(input_dir,'sample_Z_7x7.csv'));

phone_file=fullfile(input_dir,'phone_sketch.png');
if isfile(phone_file)
    phone_mask=compilePhoneSketch(phone_file,7);
else
    phone_mask=z_mask;
end
writematrix(double(phone_mask),fullfile(input_dir,'compiled_phone_mask_7x7.csv'));

shape_defs={
    'heart',heart_mask,'任意形状：心形';
    'arrow',arrow_mask,'任意形状：箭头';
    'phone',phone_mask,'手机草图自动编译结果'};
% 7.5 m既能拉开6 m级飞机轮廓，又与0.25 m分辨率形成整数周期。
shape_spacing_m=7.5;
for index=1:size(shape_defs,1)
    tag=shape_defs{index,1};
    mask=shape_defs{index,2};
    title_text=shape_defs{index,3};
    offsets=maskToOffsets(mask,shape_spacing_m);
    tile_map=balancedTileMap(7,size(offsets,1));
    [response,channel_table,tile_table]=compilePhysicalResponse(offsets,tile_map,physics);
    [img,~,~]=rdFocus(sr_center.*response,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
    writetable(channel_table,fullfile(control_dir,sprintf('shape_%s_channels.csv',tag)));
    writetable(tile_table,fullfile(control_dir,sprintf('shape_%s_7x7_tiles.csv',tag)));
    fig=pairedPhysicalResultFigure(tile_map,offsets,img,Range_axis_ground, ...
        Az_axis,reference_peak,-42,[0,0],offsets,title_text,inner_delay_fraction);
    exportgraphics(fig,fullfile(output_dir,sprintf('arbitrary_%s_pair.png',tag)), ...
        'Resolution',220);
    close(fig);
end

%% 9. 谐波理论检查（与每个宏格内部4×4时延子单元完全一致）
orders=(-15:15).';
base_coeff=arrayfun(@twoBitCoefficient,orders);
partition_factor=arrayfun(@(n)mean(exp(-1j*2*pi*n*inner_delay_fraction)),orders);
final_coeff=base_coeff.*partition_factor;

fig=createWideFigure();
tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
nexttile;
stem(orders,20*log10(abs(base_coeff)+eps),'filled','LineWidth',1.3);
grid on;ylim([-50,2]);xlim([-15.5,15.5]);
xlabel('谐波阶次n');ylabel('幅度/dB');title('单个同步2-bit序列');
nexttile;
stem(orders,20*log10(abs(final_coeff)+eps),'filled','LineWidth',1.3);
grid on;ylim([-50,2]);xlim([-15.5,15.5]);
xlabel('谐波阶次n');ylabel('幅度/dB');title('内部4×4时延子单元相干平均');
sgtitle('每个目标通道都采用同一组真实2-bit量化码和四时延谐波零陷');
exportgraphics(fig,fullfile(output_dir,'harmonic_suppression_compare.png'), ...
    'Resolution',220);
close(fig);

%% 10. 保存统一结果
save(fullfile(output_dir,'full_array_freedom_results.mat'), ...
    'single_configs','source_two','source_four','heart_mask','arrow_mask', ...
    'z_mask','phone_mask','inner_delay_fraction','state_response', ...
    'desired_ground_range_resolution','desired_az_resolution', ...
    'max_scatter_points','orders','base_coeff','partition_factor', ...
    'final_coeff','-v7.3');

fprintf('\n全部完整阵列仿真已保存：\n%s\n',output_dir);
fprintf('手机草图入口：\n%s\n',phone_file);

%% ======================== 局部函数 ========================
function pairs=cartesianPairs(range_orders,az_orders)
    [R,A]=meshgrid(range_orders,az_orders);
    pairs=[R(:),A(:)];
end

function tile_map=balancedTileMap(N,K)
    if K<1 || K>N^2
        error('目标通道数K必须在1到N^2之间。');
    end
    ids=repmat(1:K,1,ceil(N^2/K));
    ids=ids(1:N^2);
    % 蛇形排布让同一通道尽量交织分布，而不是形成一个连续大块。
    tile_map=reshape(ids,N,N).';
    for row=2:2:N
        tile_map(row,:)=fliplr(tile_map(row,:));
    end
end

function [response,channel_table,tile_table]=compilePhysicalResponse( ...
        offsets,tile_map,p)
    K=size(offsets,1);
    counts=histcounts(tile_map(:),0.5:1:(K+0.5)).';
    weights=counts/numel(tile_map);
    response=complex(zeros(numel(p.tm),numel(p.fast_time_relative)));
    range_frequency=zeros(K,1);
    azimuth_frequency=zeros(K,1);
    for channel=1:K
        range_frequency(channel)= ...
            -2*p.Kr*(offsets(channel,1)*sin(p.beta))/p.c;
        azimuth_frequency(channel)= ...
            -p.Ka*offsets(channel,2)/p.v_x;
        range_phase=2*pi*range_frequency(channel)*p.fast_time_relative;
        azimuth_phase=2*pi*azimuth_frequency(channel)*p.tm(:);
        range_average=complex(zeros(size(range_phase)));
        azimuth_average=complex(zeros(size(azimuth_phase)));
        for delay_index=1:numel(p.inner_delay_fraction)
            phase_delay=2*pi*p.inner_delay_fraction(delay_index);
            range_average=range_average+fourPhaseRamp( ...
                range_phase-phase_delay,p.state_response, ...
                p.state_dwell_fraction)/numel(p.inner_delay_fraction);
            azimuth_average=azimuth_average+fourPhaseRamp( ...
                azimuth_phase-phase_delay,p.state_response, ...
                p.state_dwell_fraction)/numel(p.inner_delay_fraction);
        end
        response=response+weights(channel)*(azimuth_average.*range_average);
    end
    channel_table=table((1:K).',offsets(:,1),offsets(:,2),counts,weights, ...
        range_frequency,azimuth_frequency, ...
        'VariableNames',{'channel_id','range_offset_m','azimuth_offset_m', ...
        'outer_tile_count','outer_area_fraction','range_mod_frequency_hz', ...
        'azimuth_mod_frequency_hz'});
    [row,col]=ndgrid(1:size(tile_map,1),1:size(tile_map,2));
    channel_id=tile_map(:);
    range_offset_m=offsets(channel_id,1);
    azimuth_offset_m=offsets(channel_id,2);
    inner_delay_set=repmat("[0,1/10,5/6,14/15]T",numel(channel_id),1);
    tile_table=table(row(:),col(:),channel_id,range_offset_m, ...
        azimuth_offset_m,inner_delay_set, ...
        'VariableNames',{'outer_row','outer_col','channel_id', ...
        'range_offset_m','azimuth_offset_m','inner_delay_set'});
end

function code=fourPhaseRamp(phase,state_response,dwell)
    u=mod(phase,2*pi)/(2*pi);
    edges=[0,cumsum(dwell)];
    state_index=zeros(size(u));
    for index=1:3
        state_index(u>=edges(index+1))=index;
    end
    code=reshape(state_response(state_index(:)+1),size(state_index));
end

function positions=maskToOffsets(mask,spacing)
    [row,col]=find(mask);
    N=size(mask,1);
    positions=[(col-(N+1)/2)*spacing,((N+1)/2-row)*spacing];
end

function mask=compilePhoneSketch(file,N)
    image_data=imread(file);
    if ndims(image_data)==3
        image_data=rgb2gray(image_data);
    end
    image_data=im2double(image_data);
    small=imresize(image_data,[N,N],'bilinear');
    threshold=graythresh(small);
    if mean(small(:))>0.5
        mask=small<threshold;
    else
        mask=small>threshold;
    end
    if ~any(mask(:))
        error('手机草图阈值化后没有有效像素。');
    end
end

function fig=pairedPhysicalResultFigure(tile_map,offsets,img,range_axis, ...
        az_axis,reference_peak,floor_db,sources,targets,title_text,delays)
    fig=createWideFigure();
    tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
    nexttile;
    plotOuterTileMap(tile_map,offsets,delays);
    title(sprintf('最终外层%d×%d控制阵列',size(tile_map,1),size(tile_map,2)));
    nexttile;
    plotSarDbWithSources(img,range_axis,az_axis,reference_peak,floor_db, ...
        29,sources,targets);
    title(sprintf('%s｜显示下限%d dB',title_text,round(floor_db)));
    sgtitle('左：实际整数控制配置　　右：同一配置产生的原始回波RD成像');
end

function plotOuterTileMap(tile_map,offsets,delays)
    K=size(offsets,1);
    imagesc(tile_map,[1,max(K,2)]);
    axis image;set(gca,'YDir','reverse');box on;
    colormap(gca,turbo(max(K,2)));
    xticks(1:size(tile_map,2));yticks(1:size(tile_map,1));
    xlabel('外层宏格列');ylabel('外层宏格行');
    hold on;
    for row=1:size(tile_map,1)
        for col=1:size(tile_map,2)
            k=tile_map(row,col);
            if size(tile_map,1)<=5
                label=sprintf('H_%d\n(%+.0f,%+.0f)m',k, ...
                    offsets(k,1),offsets(k,2));
                font_size=7.5;
            else
                label=sprintf('H_%d',k);
                font_size=7;
            end
            text(col,row,label,'HorizontalAlignment','center', ...
                'VerticalAlignment','middle','FontWeight','bold', ...
                'FontSize',font_size,'Color','k');
        end
    end
    hold off;
    subtitle(sprintf(['每个H_k内部均含4×4子单元：' ...
        'd_r,d_a=[%.2f,%.2f,%.2f,%.2f]T'],delays));
end

function plotSarDbWithSources(img,range_axis,az_axis,reference_peak, ...
        floor_db,half_width,sources,targets)
    db=20*log10(abs(img)+eps)-20*log10(reference_peak);
    imagesc(range_axis,az_axis,db,[floor_db,0]);
    set(gca,'YDir','normal','Color','k');axis image;box on;grid on;
    xlim([-half_width,half_width]);ylim([-half_width,half_width]);
    colormap(gca,gray(256));
    xlabel('相对地距向/m');ylabel('方位向/m');
    cb=colorbar;cb.Label.String='相对未调制单机/dB';
    hold on;
    for index=1:size(sources,1)
        x0=sources(index,1);y0=sources(index,2);
        patch(x0+[-3.3,3.3,3.3,-3.3],y0+[-3,-3,3,3], ...
            [0.45,0.82,1.00],'FaceAlpha',0.10, ...
            'EdgeColor',[0.45,0.85,1.00],'LineWidth',1.3);
    end
    scatter(targets(:,1),targets(:,2),18,[1.0,0.72,0.10], ...
        'o','LineWidth',0.8);
    hold off;
end

function shifted=shiftEcho(sr,range_offset,az_offset,t,tm,c,R0,Kr,Ka,beta,v)
    slant_offset=range_offset*sin(beta);
    fr=-2*Kr*slant_offset/c;
    fa=-Ka*az_offset/v;
    phase=2*pi*(fa*tm(:)+fr*(t-2*R0/c));
    shifted=sr.*exp(1j*phase);
end

function [img,R_axis_relative,Az_axis]=rdFocus( ...
        sr,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF)
    [Na,Nr]=size(sr);
    t_ref=((-Nr/2):(Nr/2-1))*dt;
    h_ref=exp(1j*pi*Kr*t_ref.^2).*(abs(t_ref)<=Tp/2);
    H_range=conj(fft(fftshift(h_ref)));
    s_rc=ifft(fft(sr,[],2).*H_range,[],2);
    S_az=fft(s_rc,[],1);
    fa=(0:Na-1)'/Na*PRF;
    fa(fa>PRF/2)=fa(fa>PRF/2)-PRF;
    R_axis=t*c/2;
    s_rcmc=complex(zeros(size(S_az)));
    for row=1:Na
        move_factor=lambda^2*fa(row)^2/(8*v_x^2);
        shift_R=R_axis*move_factor;
        s_rcmc(row,:)=interp1(R_axis,S_az(row,:),R_axis+shift_R,'linear',0);
    end
    H_az=exp(1j*pi*fa.^2/Ka);
    img=ifft(s_rcmc.*H_az,[],1);
    R_axis_relative=R_axis-R0;
    Az_axis=tm*v_x;
end

function coefficient=twoBitCoefficient(order)
    states=exp(1j*(0:3)*pi/2);
    edges=linspace(0,2*pi,5);
    if order==0
        coefficient=mean(states);return;
    end
    coefficient=0;
    for k=1:4
        coefficient=coefficient+states(k)*( ...
            exp(-1j*order*edges(k+1))-exp(-1j*order*edges(k))) ...
            /(-1j*2*pi*order);
    end
end

function fig=createWideFigure()
    fig=figure('Color','w','Position',[40,40,1800,920],'Visible','off');
end
