%% 少通道高清晰度假目标：两机2图 + 四机6x6网格3图
% 物理约束：
%   1) 每架真实飞机对应一块独立的7x7外层宏格超表面；
%   2) 每个外层宏格内部仍是4x4时延子阵列；
%   3) 每架飞机只生成2或3个假目标，使每个通道得到更多有效口径；
%   4) 所有图均由2-bit调制后的原始LFM回波经过RD成像得到，
%      不在图像域复制或平移飞机图像。

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
output_dir = fullfile(script_dir,'results_clear_low_channel_shapes');
control_dir = fullfile(output_dir,'control_tables');
cache_dir = fullfile(script_dir,'results_two_aircraft_independent_special','cache');
if ~exist(output_dir,'dir'), mkdir(output_dir); end
if ~exist(control_dir,'dir'), mkdir(control_dir); end
if ~exist(cache_dir,'dir'), mkdir(cache_dir); end

set(groot,'defaultAxesFontName','PingFang SC');
set(groot,'defaultTextFontName','PingFang SC');
set(groot,'defaultAxesFontSize',12);

%% 1. 雷达与完整RD成像参数
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
display_half_width_m = 23;
display_floor_db = -32;

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
fast_time_span = Tp+4*range_margin_m/c;
Nr = 2^nextpow2(ceil(fast_time_span*Fs));
t = 2*R0/c+((-Nr/2):(Nr/2-1))/Fs;
dt = 1/Fs;
fast_time_relative = t-2*R0/c;

fprintf('少通道完整仿真：散射点<=%d，Na=%d，Nr=%d\n', ...
    max_scatter_points,Na,Nr);

%% 2. 加载或生成中心歼-36原始回波
scatter_file = fullfile(script_dir,'..','..','Week 4 0813之前', ...
    '歼36_4x4机群_sar_code_2D','airplane_scatter_points.mat');
if ~isfile(scatter_file)
    error('找不到歼-36散射点：%s',scatter_file);
end

cache_file = fullfile(cache_dir,sprintf( ...
    'center_echo_scatter%d_Na%d_Nr%d.mat',max_scatter_points,Na,Nr));
if isfile(cache_file)
    fprintf('读取中心单机原始回波缓存。\n');
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
    sr_center = complex(zeros(Na,Nr));
    for point_index = 1:size(target,1)
        for slow_index = 1:Na
            x_radar = tm(slow_index)*v_x;
            delta_azimuth = x_radar-target_azimuth(point_index);
            r_inst = sqrt(delta_azimuth^2+ ...
                target_ground_range(point_index)^2+H0^2);
            scatter_amplitude = (R0/r_inst)^2;
            tau = t-2*r_inst/c;
            pulse_mask = abs(tau)<=Tp/2;
            sr_center(slow_index,:) = sr_center(slow_index,:)+ ...
                scatter_amplitude.*pulse_mask.*exp(1j*pi*Kr*tau.^2).* ...
                exp(-1j*4*pi*r_inst/lambda);
        end
    end
    save(cache_file,'sr_center','-v7.3');
end

[img_reference,R_axis_slant_relative,Az_axis] = rdFocus( ...
    sr_center,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
Range_axis_ground = R_axis_slant_relative/sin(beta);
reference_peak = max(abs(img_reference(:)))+eps;

%% 3. 每架飞机使用相同硬件结构，但各自独立编译码本
state_response = exp(1j*deg2rad([0,90,180,270]));
state_dwell_fraction = [0.25,0.25,0.25,0.25];
inner_delay_fraction = [0,1/10,5/6,14/15];
physics = struct('c',c,'Kr',Kr,'Ka',Ka,'beta',beta,'v_x',v_x, ...
    'fast_time_relative',fast_time_relative,'tm',tm, ...
    'state_response',state_response, ...
    'state_dwell_fraction',state_dwell_fraction, ...
    'inner_delay_fraction',inner_delay_fraction);
outer_N = 7;

%% 4. 两架飞机：每架2~3个通道，共输出两张图
source_two = [-5,-9;5,-9];

% 图1：V字编队，共5个目标；K1负责3个，K2负责2个。
two_v_targets = [-14,11;-7,5;0,-1;7,5;14,11];
two_v_owner = [1;1;1;2;2];

% 图2：折线/闪电编队，共6个目标；每块超表面负责3个。
two_zigzag_targets = [-14,12;-5,7;-9,1;7,1;3,-5;14,-11];
two_zigzag_owner = [1;1;1;2;2;2];

two_defs = {
    'v_formation',two_v_targets,two_v_owner,'两架飞机独立码本：V形5机编队';
    'zigzag',two_zigzag_targets,two_zigzag_owner,'两架飞机独立码本：折线6机编队'};

for case_index=1:size(two_defs,1)
    runCase(two_defs{case_index,1},two_defs{case_index,4}, ...
        source_two,two_defs{case_index,2},two_defs{case_index,3}, ...
        outer_N,sr_center,physics,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF, ...
        beta,Range_axis_ground,Az_axis,reference_peak, ...
        display_floor_db,display_half_width_m,output_dir,control_dir);
end

%% 5. 四架飞机：严格按照“四通道Ki”构成6x6空间网格图形
% 6x6网格坐标为[-20,-12,-4,+4,+12,+20] m。
% 四架真飞机位于四个3x3分区的中心：(+-12,+-12) m。
% 每架Ki只含4个通道：
%   (0,0)、(+-8,0)、(0,+-8)、(+-8,+-8)，
% 即保留1个本位像并额外生成3个假像。
source_four = [-12,12;12,12;-12,-12;12,-12];

% 图1：四架均向各自外角展开，形成四个角部2x2块。
sign_outward = [-1,1;1,1;-1,-1;1,-1];
[four_outward_targets,owner_four] = makeFourChannelTargets( ...
    source_four,sign_outward,8);

% 图2：四架均向中心展开，合成规则中央4x4编队。
sign_inward = [1,-1;-1,-1;1,1;-1,1];
[four_inward_targets,~] = makeFourChannelTargets( ...
    source_four,sign_inward,8);

% 图3：四套Ki采用不同符号组合，形成错位风车型。
sign_pinwheel = [1,1;1,-1;-1,1;-1,-1];
[four_pinwheel_targets,~] = makeFourChannelTargets( ...
    source_four,sign_pinwheel,8);

four_defs = {
    'grid6_outward_blocks',four_outward_targets,owner_four, ...
        '四架飞机四通道Ki：6x6网格向外四角块';
    'grid6_inward_4x4',four_inward_targets,owner_four, ...
        '四架飞机四通道Ki：向内合成中央4x4';
    'grid6_pinwheel',four_pinwheel_targets,owner_four, ...
        '四架飞机四通道Ki：6x6网格错位风车型'};

for case_index=1:size(four_defs,1)
    runCase(four_defs{case_index,1},four_defs{case_index,4}, ...
        source_four,four_defs{case_index,2},four_defs{case_index,3}, ...
        outer_N,sr_center,physics,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF, ...
        beta,Range_axis_ground,Az_axis,reference_peak, ...
        display_floor_db,display_half_width_m,output_dir,control_dir);
end

save(fullfile(output_dir,'clear_low_channel_shapes_results.mat'), ...
    'two_defs','four_defs','source_two','source_four','outer_N', ...
    'inner_delay_fraction','desired_ground_range_resolution', ...
    'desired_az_resolution','display_floor_db','-v7.3');

fprintf('\n全部完成，结果目录：\n%s\n',output_dir);

%% ======================== 局部函数 ======================== 
function runCase(tag,title_text,sources,targets,owner,outer_N, ...
        sr_center,physics,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF,beta, ...
        range_axis,az_axis,reference_peak,floor_db,half_width, ...
        output_dir,control_dir)
    source_count = size(sources,1);
    sr_case = complex(zeros(size(sr_center)));
    all_channels = table();
    target_counts = zeros(source_count,1);

    for source_index=1:source_count
        owned_targets = targets(owner==source_index,:);
        target_counts(source_index) = size(owned_targets,1);
        offsets = owned_targets-sources(source_index,:);
        tile_map = balancedTileMap(outer_N,size(offsets,1));
        [response,channel_table,tile_table] = compilePhysicalResponse( ...
            offsets,tile_map,physics);
        sr_source = shiftEcho(sr_center,sources(source_index,1), ...
            sources(source_index,2),t,tm,c,R0,Kr,Ka,beta,v_x);
        sr_case = sr_case+sr_source.*response;

        channel_table.source_id = repmat(source_index,height(channel_table),1);
        channel_table.target_range_m = owned_targets(:,1);
        channel_table.target_azimuth_m = owned_targets(:,2);
        all_channels = [all_channels;channel_table]; %#ok<AGROW>
        writetable(tile_table,fullfile(control_dir,sprintf( ...
            '%s_source%d_outer7x7_tiles.csv',tag,source_index)));
    end
    writetable(all_channels,fullfile(control_dir,sprintf('%s_channels.csv',tag)));

    [img,~,~] = rdFocus(sr_case,t,tm,dt,c,R0,Tp,Kr, ...
        lambda,v_x,Ka,PRF);
    fig = figure('Color','w','Position',[40,40,1350,1120],'Visible','off');
    plotClearSar(img,range_axis,az_axis,reference_peak,floor_db, ...
        half_width,sources,targets,owner);
    title(title_text,'FontSize',19,'FontWeight','bold');
    if source_count==4 && all(target_counts==4)
        counts_text = '每个K_i：1个本位通道+3个偏移假像';
    else
        counts_text = strjoin(compose('K_%d=%d个假像', ...
            (1:source_count).',target_counts),'，');
    end
    subtitle(sprintf('%s｜青框=真飞机位置｜显示相对本图峰值',counts_text), ...
        'FontSize',13);
    exportgraphics(fig,fullfile(output_dir,[tag,'_sar.png']),'Resolution',250);
    close(fig);

    peak_relative_single_db = 20*log10(max(abs(img(:)))/reference_peak+eps);
    fprintf('已完成 %-16s：通道数=%s，本图峰值相对单机 %.2f dB\n', ...
        tag,mat2str(target_counts.'),peak_relative_single_db);
end

function [targets,owner]=makeFourChannelTargets(sources,sign_pairs,spacing)
    source_count=size(sources,1);
    targets=zeros(4*source_count,2);
    owner=zeros(4*source_count,1);
    cursor=1;
    for source_index=1:source_count
        sx=sign_pairs(source_index,1);
        sy=sign_pairs(source_index,2);
        local_offsets=[0,0;sx*spacing,0;0,sy*spacing; ...
            sx*spacing,sy*spacing];
        rows=cursor:(cursor+3);
        targets(rows,:)=sources(source_index,:)+local_offsets;
        owner(rows)=source_index;
        cursor=cursor+4;
    end
end

function tile_map=balancedTileMap(N,K)
    if K<1 || K>N^2
        error('每架飞机的目标通道数必须在1到N^2之间。');
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

function plotClearSar(img,range_axis,az_axis,reference_peak, ...
        floor_db,half_width,sources,targets,owner)
    %#ok<INUSD> reference_peak保留用于与绝对幅度结果表兼容。
    image_peak=max(abs(img(:)))+eps;
    db=20*log10(abs(img)+eps)-20*log10(image_peak);
    imagesc(range_axis,az_axis,db,[floor_db,0]);
    set(gca,'YDir','normal','Color','k');
    axis image; box on; grid on;
    xlim([-half_width,half_width]); ylim([-half_width,half_width]);
    colormap(gca,gray(256));
    xlabel('相对地距向/m'); ylabel('方位向/m');
    cb=colorbar; cb.Label.String='相对本图峰值/dB';
    hold on;
    for index=1:size(sources,1)
        x0=sources(index,1); y0=sources(index,2);
        patch(x0+[-2.8,2.8,2.8,-2.8],y0+[-2.7,-2.7,2.7,2.7], ...
            [0.35,0.83,1.00],'FaceAlpha',0.08, ...
            'EdgeColor',[0.25,0.80,1.00],'LineWidth',1.2);
    end
    colors=[0.00,0.65,1.00;1.00,0.46,0.05; ...
        0.20,0.85,0.38;0.88,0.25,0.83];
    for source_index=1:size(sources,1)
        mask=owner==source_index;
        scatter(targets(mask,1),targets(mask,2),24, ...
            colors(source_index,:),'o','LineWidth',1.0);
    end
    hold off;
end
