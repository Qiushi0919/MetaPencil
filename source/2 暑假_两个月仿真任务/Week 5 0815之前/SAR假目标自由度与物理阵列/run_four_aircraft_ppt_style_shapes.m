%% 四架真实飞机 -> 16个目标：沿用原PPT完整仿真与显示参数
% 原有程序不修改。本脚本仅增加四组目标中心配置：
%   规则4x4、五角星轮廓、四旋臂风车、双环∞。
% 每架飞机使用独立4通道Ki；每个通道由4x4外层宏格中的4格承担，
% 每格内部继续使用4x4时延子阵[0,1/10,5/6,14/15]T。

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
output_dir = fullfile(script_dir,'results_four_aircraft_ppt_style_shapes');
control_dir = fullfile(output_dir,'control_tables');
cache_dir = fullfile(output_dir,'cache');
if ~exist(output_dir,'dir'), mkdir(output_dir); end
if ~exist(control_dir,'dir'), mkdir(control_dir); end
if ~exist(cache_dir,'dir'), mkdir(cache_dir); end

set(groot,'defaultAxesFontName','PingFang SC');
set(groot,'defaultTextFontName','PingFang SC');
set(groot,'defaultAxesFontSize',11);

%% 1. 与原PPT完全一致的雷达和RD参数
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
max_scatter_points = 700;
display_half_width_m = 29;
display_floor_db = -36;

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

range_margin_m = 48;
fast_time_span = Tp+4*range_margin_m/c;
Nr = 2^nextpow2(ceil(fast_time_span*Fs));
t = 2*R0/c+((-Nr/2):(Nr/2-1))/Fs;
dt = 1/Fs;
fast_time_relative = t-2*R0/c;

fprintf('PPT同参数四机仿真：散射点=%d，Na=%d，Nr=%d\n', ...
    max_scatter_points,Na,Nr);

%% 2. 生成一次700点中心飞机原始回波并缓存
scatter_file = fullfile(script_dir,'..','..','Week 4 0813之前', ...
    '歼36_4x4机群_sar_code_2D','airplane_scatter_points.mat');
if ~isfile(scatter_file)
    error('找不到歼-36散射点：%s',scatter_file);
end
cache_file = fullfile(cache_dir,sprintf( ...
    'center_echo_scatter%d_Na%d_Nr%d.mat',max_scatter_points,Na,Nr));

if isfile(cache_file)
    load(cache_file,'sr_center');
    fprintf('读取700点中心单机回波缓存。\n');
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
    sr_center = complex(zeros(Na,Nr));
    fprintf('生成700散射点歼-36原始回波...\n');
    for point_index=1:size(target,1)
        for slow_index=1:Na
            x_radar=tm(slow_index)*v_x;
            delta_azimuth=x_radar-target_azimuth(point_index);
            r_inst=sqrt(delta_azimuth^2+ ...
                target_ground_range(point_index)^2+H0^2);
            scatter_amplitude=(R0/r_inst)^2;
            tau=t-2*r_inst/c;
            pulse_mask=abs(tau)<=Tp/2;
            sr_center(slow_index,:)=sr_center(slow_index,:)+ ...
                scatter_amplitude.*pulse_mask.*exp(1j*pi*Kr*tau.^2).* ...
                exp(-1j*4*pi*r_inst/lambda);
        end
        if mod(point_index,100)==0 || point_index==size(target,1)
            fprintf('  散射点 %d/%d\n',point_index,size(target,1));
        end
    end
    save(cache_file,'sr_center','-v7.3');
end

[img_reference,R_axis_slant_relative,Az_axis] = rdFocus( ...
    sr_center,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
Range_axis_ground = R_axis_slant_relative/sin(beta);
reference_peak = max(abs(img_reference(:)))+eps;

%% 3. 与原PPT一致的2-bit物理阵列参数
state_response = exp(1j*deg2rad([0,90,180,270]));
state_dwell_fraction = [0.25,0.25,0.25,0.25];
inner_delay_fraction = [0,1/10,5/6,14/15];
physics = struct('c',c,'Kr',Kr,'Ka',Ka,'beta',beta,'v_x',v_x, ...
    'fast_time_relative',fast_time_relative,'tm',tm, ...
    'state_response',state_response, ...
    'state_dwell_fraction',state_dwell_fraction, ...
    'inner_delay_fraction',inner_delay_fraction);

source_four = [-12,-12;12,-12;-12,12;12,12];
outer_N = 4;
owner_grouped = repelem((1:4).',4);

%% 4. 四种16点形状
% 4.1 原PPT规则4x4：每架由自身向中心生成一个2x2子阵。
regular_targets=zeros(16,2);
cursor=1;
for source_index=1:4
    source=source_four(source_index,:);
    inward_range=-sign(source(1))*8;
    inward_az=-sign(source(2))*8;
    offsets=[0,0;inward_range,0;0,inward_az;inward_range,inward_az];
    regular_targets(cursor:cursor+3,:)=source+offsets;
    cursor=cursor+4;
end

% 4.2 五角星轮廓：沿五角星十条边等弧长抽取16个中心。
star_targets=makeStarArcSamples(24,11,16);

% 4.3 四旋臂风车：每架飞机独立负责一条弯曲旋臂。
radii=[7,13,19,25].';
bend=[0,0.22,0.50,0.82].';
pinwheel_targets=zeros(16,2);
for arm=1:4
    theta=(arm-1)*pi/2+bend;
    rows=(arm-1)*4+(1:4);
    pinwheel_targets(rows,:)=[radii.*cos(theta),radii.*sin(theta)];
end

% 4.4 稍复杂的双环∞：16个等参数中心，无中心重叠。
tt=((0:15).'+0.5)/16*2*pi;
infinity_targets=[23*sin(tt),12*sin(2*tt)];

shape_defs={ ...
    'regular_4x4',regular_targets,owner_grouped,'四架飞机→规则4×4目标群';
    'star_16',star_targets,owner_grouped,'四架飞机→五角星轮廓目标群';
    'pinwheel_16',pinwheel_targets,owner_grouped,'四架飞机→四旋臂风车目标群';
    'infinity_16',infinity_targets,owner_grouped,'四架飞机→双环∞目标群'};

%% 5. 四组均从原始回波重新调制并RD成像
shape_images=cell(size(shape_defs,1),1);
for case_index=1:size(shape_defs,1)
    tag=shape_defs{case_index,1};
    targets=shape_defs{case_index,2};
    owner=shape_defs{case_index,3};
    title_text=shape_defs{case_index,4};
    sr_case=complex(zeros(size(sr_center)));
    all_channels=table();

    for source_index=1:4
        owned_targets=targets(owner==source_index,:);
        offsets=owned_targets-source_four(source_index,:);
        tile_map=balancedTileMap(outer_N,4);
        [response,channel_table,tile_table]=compilePhysicalResponse( ...
            offsets,tile_map,physics);
        sr_source=shiftEcho(sr_center,source_four(source_index,1), ...
            source_four(source_index,2),t,tm,c,R0,Kr,Ka,beta,v_x);
        sr_case=sr_case+sr_source.*response;

        channel_table.source_id=repmat(source_index,4,1);
        channel_table.target_range_m=owned_targets(:,1);
        channel_table.target_azimuth_m=owned_targets(:,2);
        all_channels=[all_channels;channel_table]; %#ok<AGROW>
        writetable(tile_table,fullfile(control_dir,sprintf( ...
            '%s_K%d_outer4x4_tiles.csv',tag,source_index)));
    end
    writetable(all_channels,fullfile(control_dir,[tag,'_channels.csv']));

    [img,~,~]=rdFocus(sr_case,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
    shape_images{case_index}=img;
    fig=figure('Color','w','Position',[40,40,1380,1120],'Visible','off');
    plotSarPptStyle(img,Range_axis_ground,Az_axis,reference_peak, ...
        display_floor_db,display_half_width_m,source_four,targets);
    title(sprintf('%s｜四套独立K_i、每套4通道',title_text), ...
        'FontSize',18,'FontWeight','bold');
    subtitle('青框：四架真实飞机位置｜橙圈：16个设计目标中心', ...
        'FontSize',12);
    exportgraphics(fig,fullfile(output_dir,[tag,'_sar.png']),'Resolution',240);
    close(fig);
    fprintf('已完成：%s\n',tag);
end

save(fullfile(output_dir,'four_aircraft_ppt_style_results.mat'), ...
    'shape_defs','shape_images','source_four','outer_N', ...
    'inner_delay_fraction','reference_peak','display_floor_db','-v7.3');
fprintf('\n四张PPT同风格结果已保存：\n%s\n',output_dir);

%% ======================== 局部函数 ======================== 
function points=makeStarArcSamples(outer_radius,inner_radius,N)
    vertices=zeros(11,2);
    for k=1:10
        radius=outer_radius;
        if mod(k,2)==0, radius=inner_radius; end
        angle=pi/2+(k-1)*pi/5;
        vertices(k,:)=[radius*cos(angle),radius*sin(angle)];
    end
    vertices(11,:)=vertices(1,:);
    edge_lengths=sqrt(sum(diff(vertices,1,1).^2,2));
    cumulative=[0;cumsum(edge_lengths)];
    sample_s=(0:N-1).'/N*cumulative(end);
    points=zeros(N,2);
    for index=1:N
        edge=find(cumulative<=sample_s(index),1,'last');
        edge=min(edge,10);
        alpha=(sample_s(index)-cumulative(edge))/edge_lengths(edge);
        points(index,:)=(1-alpha)*vertices(edge,:)+alpha*vertices(edge+1,:);
    end
end

function tile_map=balancedTileMap(N,K)
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

function plotSarPptStyle(img,range_axis,az_axis,reference_peak, ...
        floor_db,half_width,sources,targets)
    db=20*log10(abs(img)+eps)-20*log10(reference_peak);
    imagesc(range_axis,az_axis,db,[floor_db,0]);
    set(gca,'YDir','normal','Color','k');
    axis image; box on; grid on;
    xlim([-half_width,half_width]); ylim([-half_width,half_width]);
    colormap(gca,gray(256));
    xlabel('相对地距向/m'); ylabel('方位向/m');
    cb=colorbar; cb.Label.String='相对未调制单机/dB';
    hold on;
    for index=1:size(sources,1)
        x0=sources(index,1); y0=sources(index,2);
        patch(x0+[-3.3,3.3,3.3,-3.3],y0+[-3,-3,3,3], ...
            [0.45,0.82,1.00],'FaceAlpha',0.10, ...
            'EdgeColor',[0.45,0.85,1.00],'LineWidth',1.3);
    end
    scatter(targets(:,1),targets(:,2),18,[1.0,0.72,0.10], ...
        'o','LineWidth',0.8);
    hold off;
end
