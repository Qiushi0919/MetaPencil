%% 两架真实飞机 + 独立码本：高自由度特殊形状完整SAR仿真
% 每架真实飞机均使用独立的7×7外层宏格阵列。
% 每个外层宏格内部仍使用相同的4×4距离/方位时延子阵列：
%   d = [0, 1/10, 5/6, 14/15]T
% 所有结果都经过：整数阵列 -> 2-bit四相位时变反射 -> 原始LFM回波 -> RD成像。
% 不在成像后复制、平移或粘贴飞机图像。

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
output_dir = fullfile(script_dir,'results_two_aircraft_independent_special');
control_dir = fullfile(output_dir,'control_tables');
cache_dir = fullfile(output_dir,'cache');
if ~exist(output_dir,'dir'), mkdir(output_dir); end
if ~exist(control_dir,'dir'), mkdir(control_dir); end
if ~exist(cache_dir,'dir'), mkdir(cache_dir); end

set(groot,'defaultAxesFontName','PingFang SC');
set(groot,'defaultTextFontName','PingFang SC');
set(groot,'defaultAxesFontSize',12);

%% 1. 雷达和RD成像参数
c = 3e8;
fc = 10e9;
lambda = c/fc;
Tp = 1e-6;
beta = deg2rad(60);
H0 = 500;
v_x = 80;
Y0 = H0*tan(beta);
R0 = hypot(H0,Y0);

desired_ground_range_resolution = 0.25;
desired_az_resolution = 0.25;
max_scatter_points = 420;
display_half_width_m = 32;
display_floor_db = -42;

desired_slant_range_resolution = desired_ground_range_resolution*sin(beta);
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

range_margin_m = 55;
fast_time_span = Tp + 4*range_margin_m/c;
Nr = 2^nextpow2(ceil(fast_time_span*Fs));
t = 2*R0/c + ((-Nr/2):(Nr/2-1))/Fs;
dt = 1/Fs;
fast_time_relative = t-2*R0/c;

fprintf('两机独立码本完整仿真：散射点<=%d，Na=%d，Nr=%d\n', ...
    max_scatter_points,Na,Nr);

%% 2. 加载歼-36散射点；中心单机回波仅计算一次并缓存
scatter_file = fullfile(script_dir,'..','..','Week 4 0813之前', ...
    '歼36_4x4机群_sar_code_2D','airplane_scatter_points.mat');
if ~isfile(scatter_file)
    error('找不到歼-36散射点：%s',scatter_file);
end

cache_file = fullfile(cache_dir,sprintf( ...
    'center_echo_scatter%d_Na%d_Nr%d.mat',max_scatter_points,Na,Nr));
if isfile(cache_file)
    fprintf('读取中心单机原始回波缓存：%s\n',cache_file);
    load(cache_file,'sr_center');
else
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
            x_radar = tm(slow_index)*v_x;
            delta_azimuth = x_radar-target_azimuth(point_index);
            r_inst = sqrt(delta_azimuth^2 + ...
                target_ground_range(point_index)^2 + H0^2);
            scatter_amplitude = (R0/r_inst)^2;
            tau = t-2*r_inst/c;
            pulse_mask = abs(tau)<=Tp/2;
            sr_center(slow_index,:) = sr_center(slow_index,:) + ...
                scatter_amplitude.*pulse_mask.*exp(1j*pi*Kr*tau.^2).* ...
                exp(-1j*4*pi*r_inst/lambda);
        end
        if mod(point_index,70)==0 || point_index==Ntar
            fprintf('  散射点 %d/%d\n',point_index,Ntar);
        end
    end
    save(cache_file,'sr_center','-v7.3');
end

[img_reference,R_axis_slant_relative,Az_axis] = rdFocus( ...
    sr_center,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
Range_axis_ground = R_axis_slant_relative/sin(beta);
reference_peak = max(abs(img_reference(:)))+eps;

%% 3. 两块独立7×7超表面共用的单元物理参数
state_response = exp(1j*deg2rad([0,90,180,270]));
state_dwell_fraction = [0.25,0.25,0.25,0.25];
inner_delay_fraction = [0,1/10,5/6,14/15];
physics = struct('c',c,'Kr',Kr,'Ka',Ka,'beta',beta,'v_x',v_x, ...
    'fast_time_relative',fast_time_relative,'tm',tm, ...
    'state_response',state_response, ...
    'state_dwell_fraction',state_dwell_fraction, ...
    'inner_delay_fraction',inner_delay_fraction);

outer_N = 7;
source_positions = [-6,0; 6,0];

%% 4. 构造四种特殊目标中心集合，并分配给两套独立码本
% 4.1 五角星轮廓：相邻目标点交替交给两架飞机。
star_targets = makeStarOutline(23,10.5,2);
star_owner = 1+mod((0:size(star_targets,1)-1).',2);

% 4.2 无穷符号：左环由飞机1负责，右环由飞机2负责。
tt = ((0:23).'+0.5)/24*2*pi;
infinity_targets = [22*sin(tt), 12*sin(2*tt)];
infinity_owner = ones(size(tt));
infinity_owner(infinity_targets(:,1)>=0)=2;

% 4.3 笑脸：轮廓和面部细节交替分配，保证两块口径负载接近。
theta_circle = (0:17).'/18*2*pi;
face_outline = [22*cos(theta_circle),22*sin(theta_circle)];
eyes = [-8,7;8,7];
theta_mouth = linspace(deg2rad(205),deg2rad(335),7).';
mouth = [13*cos(theta_mouth),10*sin(theta_mouth)-1];
smile_targets = [face_outline;eyes;mouth];
smile_owner = 1+mod((0:size(smile_targets,1)-1).',2);

% 4.4 DNA双螺旋：每架飞机独立生成一条波动链。
y_helix = linspace(-24,24,10).';
phase_helix = linspace(0,2.2*pi,10).'+pi/7;
strand_1 = [12*sin(phase_helix),y_helix];
strand_2 = [-12*sin(phase_helix),y_helix];
dna_targets = [strand_1;strand_2];
dna_owner = [ones(10,1);2*ones(10,1)];

shape_defs = {
    'star',star_targets,star_owner,'独立码本：五角星轮廓';
    'infinity',infinity_targets,infinity_owner,'独立码本：∞双环轨迹';
    'smile',smile_targets,smile_owner,'独立码本：笑脸（轮廓+眼睛+嘴）';
    'dna',dna_targets,dna_owner,'独立码本：DNA双螺旋'};

%% 5. 每个案例均从两架真实飞机原始回波重新调制并RD成像
shape_images = cell(size(shape_defs,1),1);
for case_index = 1:size(shape_defs,1)
    tag = shape_defs{case_index,1};
    final_targets = shape_defs{case_index,2};
    owner = shape_defs{case_index,3};
    title_text = shape_defs{case_index,4};
    sr_case = complex(zeros(size(sr_center)));
    channel_rows = cell(2,1);

    for source_index = 1:2
        owned_targets = final_targets(owner==source_index,:);
        offsets = owned_targets-source_positions(source_index,:);
        if size(offsets,1)>outer_N^2
            error('%s中飞机%d的目标通道数超过7×7宏格数。',tag,source_index);
        end
        tile_map = balancedTileMap(outer_N,size(offsets,1));
        [response,channel_table,tile_table] = compilePhysicalResponse( ...
            offsets,tile_map,physics);
        sr_source = shiftEcho(sr_center,source_positions(source_index,1), ...
            source_positions(source_index,2),t,tm,c,R0,Kr,Ka,beta,v_x);
        sr_case = sr_case+sr_source.*response;

        channel_table.source_id = repmat(source_index,height(channel_table),1);
        channel_table.target_range_m = owned_targets(:,1);
        channel_table.target_azimuth_m = owned_targets(:,2);
        channel_rows{source_index} = channel_table;
        writetable(tile_table,fullfile(control_dir,sprintf( ...
            '%s_source%d_outer7x7_tiles.csv',tag,source_index)));
    end

    all_channels = [channel_rows{1};channel_rows{2}];
    writetable(all_channels,fullfile(control_dir,sprintf( ...
        '%s_independent_channel_table.csv',tag)));

    [img,~,~] = rdFocus(sr_case,t,tm,dt,c,R0,Tp,Kr, ...
        lambda,v_x,Ka,PRF);
    shape_images{case_index}=img;

    fig=createWideFigure();
    plotIndependentSar(img,Range_axis_ground,Az_axis,reference_peak, ...
        display_floor_db,display_half_width_m,source_positions, ...
        final_targets,owner);
    title(sprintf('%s｜两架真实飞机、两套独立7×7码本',title_text), ...
        'FontSize',18,'FontWeight','bold');
    subtitle(sprintf(['蓝框：真实飞机；蓝/橙圆点：分别由K_1/K_2生成；' ...
        '显示下限%d dB'],display_floor_db));
    exportgraphics(fig,fullfile(output_dir,sprintf( ...
        'two_aircraft_independent_%s_sar.png',tag)),'Resolution',240);
    close(fig);
    fprintf('已完成：%s（K1=%d通道，K2=%d通道）\n',tag, ...
        sum(owner==1),sum(owner==2));
end

%% 6. 四种特殊形状总览
fig=figure('Color','w','Position',[40,40,1800,1500],'Visible','off');
tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
for case_index=1:size(shape_defs,1)
    nexttile;
    plotIndependentSar(shape_images{case_index},Range_axis_ground,Az_axis, ...
        reference_peak,display_floor_db,display_half_width_m,source_positions, ...
        shape_defs{case_index,2},shape_defs{case_index,3});
    title(shape_defs{case_index,4},'FontSize',15,'FontWeight','bold');
end
sgtitle('两架真实飞机独立码本：高自由度特殊形状完整回波RD成像', ...
    'FontSize',20,'FontWeight','bold');
exportgraphics(fig,fullfile(output_dir, ...
    'two_aircraft_independent_special_overview.png'),'Resolution',230);
close(fig);

save(fullfile(output_dir,'two_aircraft_independent_special_results.mat'), ...
    'shape_defs','shape_images','source_positions','outer_N', ...
    'inner_delay_fraction','desired_ground_range_resolution', ...
    'desired_az_resolution','display_floor_db','-v7.3');

fprintf('\n特殊形状结果已保存：\n%s\n',output_dir);

%% ======================== 局部函数 ======================== 
function points=makeStarOutline(outer_radius,inner_radius,samples_per_edge)
    angle0=pi/2;
    vertices=zeros(10,2);
    for k=1:10
        radius=outer_radius;
        if mod(k,2)==0, radius=inner_radius; end
        angle=angle0+(k-1)*pi/5;
        vertices(k,:)=[radius*cos(angle),radius*sin(angle)];
    end
    points=zeros(10*samples_per_edge,2);
    index=1;
    for k=1:10
        p0=vertices(k,:);
        p1=vertices(mod(k,10)+1,:);
        for sample=0:samples_per_edge-1
            alpha=sample/samples_per_edge;
            points(index,:)=(1-alpha)*p0+alpha*p1;
            index=index+1;
        end
    end
end

function tile_map=balancedTileMap(N,K)
    if K<1 || K>N^2
        error('目标通道数K必须在1到N^2之间。');
    end
    ids=repmat(1:K,1,ceil(N^2/K));
    ids=ids(1:N^2);
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

function plotIndependentSar(img,range_axis,az_axis,reference_peak, ...
        floor_db,half_width,sources,targets,owner)
    db=20*log10(abs(img)+eps)-20*log10(reference_peak);
    imagesc(range_axis,az_axis,db,[floor_db,0]);
    set(gca,'YDir','normal','Color','k');
    axis image;box on;grid on;
    xlim([-half_width,half_width]);ylim([-half_width,half_width]);
    colormap(gca,gray(256));
    xlabel('相对地距向/m');ylabel('方位向/m');
    cb=colorbar;cb.Label.String='相对未调制单机/dB';
    hold on;
    for index=1:size(sources,1)
        x0=sources(index,1);y0=sources(index,2);
        patch(x0+[-3.3,3.3,3.3,-3.3],y0+[-3,-3,3,3], ...
            [0.45,0.82,1.00],'FaceAlpha',0.10, ...
            'EdgeColor',[0.35,0.82,1.00],'LineWidth',1.4);
    end
    colors=[0.10,0.70,1.00;1.00,0.48,0.08];
    for source_index=1:2
        mask=owner==source_index;
        scatter(targets(mask,1),targets(mask,2),19, ...
            colors(source_index,:),'o','LineWidth',0.9);
    end
    hold off;
end

function fig=createWideFigure()
    fig=figure('Color','w','Position',[40,40,1500,1120],'Visible','off');
end
