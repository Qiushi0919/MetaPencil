function result=main_study_spatial(options)
% MAIN_STUDY_SPATIAL 有限平面阵列复响应接入 SAR 的独立版本。
% 直接运行：result = main_study_spatial;
% 全部原编码：result = main_study_spatial(struct('case_ids',{{'all'}}));
% 自定义示例：struct('case_ids',{{'1to4'}},'pitch_m',0.015,'tile_map',map)
% options: case_ids, pitch_m, max_scatter_points, tile_map, output_dir,
%          make_plots (logical), save_raw (logical). 默认输出使用唯一时间目录。
%
% 保持 main_study.m 的雷达、量化器、坐标、负双程传播相位和 RD 算法。
% 旧响应 H0=(1/N)sum(Gamma_n)；新响应 F=(1/N)sum(Gamma_n *
% exp(+j*2*k*s(eta) dot r_n))。用 F 替换 H0，不重复乘原时间编码。
% Gamma 包含快/慢时间四态码。局部 x 距离切向，y 方位切向，z 指向
% 孔径中心雷达；阵面固定，单站位置相位含 2k。归一化场幅1=全阵同相。
% 图统一到未调制原参考，20log10场幅，显示-50..0dB，原复数不截断。
%
% 范围：中心视线、载频、冻结状态的理想有限平面阵因子；仍乘完整目标
% 复回波，没有散射点的物理分区归属、互耦/全波/实测或开关传播瞬态。
% 原固定Ka、调制后采样留量等限制保持。旧 main_study.m 不改写/调用。
if nargin<1,options=struct();end
opts=spatialOptions(options);
script_dir=fileparts(mfilename('fullpath'));
run_clock=tic;
if isempty(opts.output_dir)
    out=fullfile(script_dir,'results_spatial',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
    n=1;original_out=out;
    while isfolder(out)||isfile(out),out=sprintf('%s_%d',original_out,n);n=n+1;end
else
    out=opts.output_dir;
    if isfolder(out)
        entries=dir(out);assert(all(ismember({entries.name},{'.','..'})), ...
            'Output directory must be empty; existing results will not be overwritten.');
    else
        assert(~isfile(out),'output_dir points to a file.');
    end
end
if ~isfolder(out),mkdir(out);end
manifest=struct('status','RUNNING','started_local',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'model_level','ideal finite planar array factor times full-object raw complex echo; unchanged RD', ...
    'base_commit','c64fe55d0b03684aa7a624bc0cd6a4266463ef45','options',opts, ...
    'script_sha256',fileHash(mfilename('fullpath')+".m"), ...
    'input_sha256',fileHash(fullfile(script_dir,'airplane_scatter_points.mat')), ...
    'original_source_sha256',fileHash(fullfile(script_dir,'main_study.m')), ...
    'normalization','field divided by cell count; image uses original unmodulated peak; raw values unclipped', ...
    'full_spatial_scatterer_partition_implemented',false);
writeJson(fullfile(out,'run_manifest.json'),manifest);
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
max_scatter_points = opts.max_scatter_points;
display_half_width_m = 29;
display_floor_db = -50; % display only; complex data remain unclipped

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
scatter_file = fullfile(script_dir,'airplane_scatter_points.mat');
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


%% 有限阵面：用位置感知的复响应替换原 response，而非再次乘编码。
pitch=opts.pitch_m;
look=[zeros(Na,1),x_radar(:)./sqrt(R0^2+x_radar(:).^2), ...
    R0./sqrt(R0^2+x_radar(:).^2)];
focus=@(raw) rdFocus(raw,t,tm,dt,c,R0,Tp,Kr,lambda,v_x,Ka,PRF);
sr_point=complex(zeros(Na,Nr));
for a=1:Na
    rr=sqrt(x_radar(a)^2+Y0^2+H0^2); tau=t-2*rr/c;
    sr_point(a,:)=(R0/rr)^2.*(abs(tau)<=Tp/2).* ...
        exp(1j*pi*Kr*tau.^2).*exp(-1j*4*pi*rr/lambda);
end
point_reference=focus(sr_point);
view_mask=(abs(Az_axis(:))<=29)&(abs(Range_axis_ground)<=29);
checks=struct('zero_position_response_max_error',0,'zero_position_image_relative_error',0, ...
    'direct_cell_sum_max_error',0,'uniform_analytic_max_error',0, ...
    'all_finite',true,'all_normalized_field_amplitudes_le_one',true);
summary=struct([]); point_summary=struct([]); roi_summary=struct([]); uniform_summary=struct([]);
case_ids=opts.case_ids;
if isequal(case_ids,{'all'}),case_ids=single_defs(:,1);end
assert(all(ismember(case_ids,single_defs(:,1))),'Unknown case_ids; use 1to1/2/3/4/5/9/16 or all.');
assert(numel(unique(case_ids))==numel(case_ids),'case_ids must be unique.');
assert(isempty(opts.tile_map)||numel(case_ids)==1,'Custom tile_map requires one case.');
parameters=struct('fc_Hz',fc,'bandwidth_Hz',Br,'Fs_Hz',Fs,'PRF_Hz',PRF, ...
    'velocity_mps',v_x,'pulse_count',Na,'fast_sample_count',Nr,'scatter_points',Ntar, ...
    'pulse_interval_s',1/PRF,'fast_sample_interval_s',dt,'pitch_m',pitch, ...
    'normal','fixed toward center radar','local_x','range tangent / rows', ...
    'local_y','azimuth tangent / columns','array_phase','+j 2 k s dot r', ...
    'propagation_phase','-j 4 pi R/lambda, already included in raw echo', ...
    'image_reference_peak',reference_peak,'display_limits_dB',[-50,0], ...
    'roi_half_width_m',3.9,'view_half_width_m',29,'case_ids',{case_ids}, ...
    'state_response_phase_deg',[0,90,180,270],'inner_delay_fraction',inner_delay_fraction);
save(fullfile(out,'shared_inputs.mat'),'sr_center','sr_point','img_reference','point_reference', ...
    'target','physics','t','tm','dt','Range_axis_ground','Az_axis','look','parameters','-v7.3');
writetable(table((1:Na)',tm(:),x_radar(:),look(:,1),look(:,2),look(:,3), ...
    'VariableNames',{'pulse','slow_time_s','flight_position_m','look_x','look_y','look_z'}), ...
    fullfile(out,'radar_geometry.csv'));
writeJson(fullfile(out,'parameters.json'),parameters);
for ci=1:numel(case_ids)
    idx=find(strcmp(single_defs(:,1),case_ids{ci}));
    tag=single_defs{idx,1}; outer_N=single_defs{idx,2}; offsets=single_defs{idx,3}*grid_spacing_m;
    if isempty(opts.tile_map)
        tile_map=balancedTileMap(outer_N,size(offsets,1));
    else
        tile_map=opts.tile_map;
        validateattributes(tile_map,{'numeric'},{'2d','nonempty','integer','>=',1,'<=',size(offsets,1)});
        assert(size(tile_map,1)==size(tile_map,2),'tile_map must be square.');
        assert(all(ismember(1:size(offsets,1),tile_map(:))),'Every selected channel must occur in tile_map.');
        outer_N=size(tile_map,1);
    end
    cells=makeCells(tile_map,pitch);
    [response_count,channel_table,tile_table]=compilePhysicalResponse(offsets,tile_map,physics);
    response_spatial=positionResponse(offsets,cells,physics,lambda,look);
    response_zero=positionResponse(offsets,cells,physics,lambda,zeros(size(look)));
    checks.zero_position_response_max_error=max(checks.zero_position_response_max_error, ...
        max(abs(response_zero(:)-response_count(:))));
    [~,mid]=min(abs(tm));
    for a=unique([1,73,mid,Na])
        for r=unique([1,777,Nr/2+1,Nr])
            f=directPositionResponse(offsets,cells,physics,lambda,look(a,:),a,r);
            checks.direct_cell_sum_max_error=max(checks.direct_cell_sum_max_error,abs(f-response_spatial(a,r)));
        end
    end
    raw_count=sr_center.*response_count;
    raw_spatial=sr_center.*response_spatial; % response_spatial already contains all coding.
    img_count=focus(raw_count); img_spatial=focus(raw_spatial);
    img_zero=focus(sr_center.*response_zero);
    checks.zero_position_image_relative_error=max(checks.zero_position_image_relative_error, ...
        norm(img_zero(:)-img_count(:))/norm(img_count(:)));
    point_count=focus(sr_point.*response_count); point_spatial=focus(sr_point.*response_spatial);
    uniform_response=mean(exp(1j*2*(2*pi/lambda)*look*cells{:,{'x_m','y_m','z_m'}}'),2);
    N=4*outer_N; z=2*pi*look(:,2)*pitch/lambda;
    analytic=ones(size(z)); nz=abs(sin(z))>1e-12;
    analytic(nz)=sin(N*z(nz))./(N*sin(z(nz)));
    % At nonzero integer pi singularities the centered-array sign may be -1.
    singular=~nz; analytic(singular)=cos((N-1)*z(singular));
    checks.uniform_analytic_max_error=max(checks.uniform_analytic_max_error,max(abs(uniform_response-analytic)));
    img_uniform=focus(sr_center.*uniform_response);
    point_uniform=focus(sr_point.*uniform_response);
    p0=pointMetrics(point_reference,Range_axis_ground,Az_axis,[0,0]);
    p1=pointMetrics(point_uniform,Range_axis_ground,Az_axis,[0,0]);
    uniform_summary(end+1).case_id=tag;
    uniform_summary(end).side_cells=N;
    uniform_summary(end).az_width_count_m=p0.az_width_m;
    uniform_summary(end).az_width_spatial_m=p1.az_width_m;
    uniform_summary(end).range_width_count_m=p0.range_width_m;
    uniform_summary(end).range_width_spatial_m=p1.range_width_m;
    desired_mask=false(size(img_count));
    for ch=1:size(offsets,1)
        mask=(abs(Range_axis_ground-offsets(ch,1))<3.9)&(abs(Az_axis(:)-offsets(ch,2))<3.9);
        assert(~any(desired_mask(mask)),'ROI overlap');desired_mask=desired_mask|mask;
        m=compareImages(img_count,img_spatial,mask);
        e=struct('case_id',tag,'channel',ch,'range_offset_m',offsets(ch,1),'az_offset_m',offsets(ch,2), ...
            'peak_change_db',m.peak_change_db,'energy_change_db',m.energy_change_db);
        if isempty(roi_summary),roi_summary=e;else,roi_summary(end+1)=e;end
        a=pointMetrics(point_count,Range_axis_ground,Az_axis,offsets(ch,:));
        b=pointMetrics(point_spatial,Range_axis_ground,Az_axis,offsets(ch,:));
        e=struct('case_id',tag,'channel',ch,'range_width_count_m',a.range_width_m, ...
            'range_width_spatial_m',b.range_width_m,'az_width_count_m',a.az_width_m, ...
            'az_width_spatial_m',b.az_width_m,'range_peak_change_m',b.range_peak_m-a.range_peak_m, ...
            'az_peak_change_m',b.az_peak_m-a.az_peak_m);
        if isempty(point_summary),point_summary=e;else,point_summary(end+1)=e;end
    end
    m=compareImages(img_count,img_spatial,view_mask);mr=compareImages(img_count,img_spatial,desired_mask);
    e=struct('case_id',tag,'side_cells',N,'peak_change_db',m.peak_change_db, ...
        'target_roi_energy_change_db',mr.energy_change_db,'view_energy_change_db',m.energy_change_db, ...
        'magnitude_cosine_similarity',m.magnitude_correlation, ...
        'gain_fitted_complex_relative_error',m.gain_fitted_complex_relative_error);
    if isempty(summary),summary=e;else,summary(end+1)=e;end
    checks.all_finite=checks.all_finite&&all(isfinite(img_spatial(:)))&&all(isfinite(response_spatial(:)));
    checks.all_normalized_field_amplitudes_le_one=checks.all_normalized_field_amplitudes_le_one&&max(abs(response_spatial(:)))<=1+2e-14;
    writetable(cells,fullfile(out,[tag '_cells.csv']));
    writetable(channel_table,fullfile(out,[tag '_channels.csv']));
    writetable(tile_table,fullfile(out,[tag '_tiles.csv']));
    save(fullfile(out,[tag '_results.mat']),'response_count','response_spatial','img_count','img_spatial', ...
        'point_count','point_spatial','img_uniform','point_uniform','uniform_response','cells','tile_map','offsets','-v7.3');
    if opts.save_raw,save(fullfile(out,[tag '_raw.mat']),'raw_count','raw_spatial','-v7.3');end
    if opts.make_plots
        plotSpatialCase(out,tag,img_reference,img_count,img_spatial,img_uniform, ...
            point_reference,point_uniform,response_count,response_spatial, ...
            Range_axis_ground,Az_axis,reference_peak,tm,fast_time_relative,offsets,e,uniform_summary(end));
    end
    fprintf('%s: peak %+.3f dB, target ROI energy %+.3f dB\n',tag,e.peak_change_db,e.target_roi_energy_change_db);
end
assert(checks.zero_position_response_max_error<2e-13,'Count-only limit failed');
assert(checks.zero_position_image_relative_error<2e-12,'Count-only image limit failed');
assert(checks.direct_cell_sum_max_error<2e-13,'Independent cell sum failed');
assert(checks.uniform_analytic_max_error<2e-13,'Uniform-array analytic check failed');
assert(checks.all_finite&&checks.all_normalized_field_amplitudes_le_one);
writetable(struct2table(summary),fullfile(out,'summary.csv'));
writetable(struct2table(roi_summary),fullfile(out,'target_roi_metrics.csv'));
writetable(struct2table(point_summary),fullfile(out,'point_metrics.csv'));
writetable(struct2table(uniform_summary),fullfile(out,'unmodulated_metrics.csv'));
writeJson(fullfile(out,'checks.json'),checks);
writeJson(fullfile(out,'summary.json'),summary);
manifest.status='PASS';manifest.elapsed_seconds=toc(run_clock);manifest.parameters=parameters;
manifest.checks=checks;manifest.summary=summary;
writeJson(fullfile(out,'run_manifest.json'),manifest);
result=struct('output_dir',out,'summary',struct2table(summary),'checks',checks,'parameters',parameters);
fprintf('Completed in %.1f s. Output: %s\n',toc(run_clock),out);
end

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


function s=compareImages(old,new,mask)
    a=old(mask); b=new(mask);
    g=(a'*b)/(a'*a);
    s=struct('peak_change_db',20*log10(max(abs(b))/max(abs(a))), ...
        'energy_change_db',10*log10(sum(abs(b).^2)/sum(abs(a).^2)), ...
        'magnitude_correlation',dot(abs(a),abs(b))/(norm(abs(a))*norm(abs(b))), ...
        'complex_relative_error',norm(b-a)/norm(a), ...
        'gain_fitted_complex_relative_error',norm(b-g*a)/norm(b));
end

function m=pointMetrics(im,x,y,offset)
    rr=find(abs(x-offset(1))<3.9); aa=find(abs(y-offset(2))<3.9);
    sub=abs(im(aa,rr)); [peak,idx]=max(sub(:)); [ai,ri]=ind2sub(size(sub),idx);
    ia=aa(ai); ir=rr(ri);
    m=struct('peak',peak,'range_peak_m',x(ir),'az_peak_m',y(ia), ...
        'range_width_m',width3dB(im(ia,:),x,ir), ...
        'az_width_m',width3dB(im(:,ir),y,ia));
end

function width=width3dB(profile,axisv,peak_index)
    % Interpolate the native band-limited cut 16x; search only around the
    % selected peak so other replicas cannot become the measurement target.
    up=16; profile=profile(:); z=abs(interpft(profile,numel(profile)*up));
    mid=(peak_index-1)*up+1; window=max(1,mid-up):min(numel(z),mid+up);
    [pk,j]=max(z(window)); ip=window(j); h=pk/sqrt(2);
    lo=find(z(1:ip)<=h,1,'last'); hi=ip-1+find(z(ip:end)<=h,1,'first');
    if isempty(lo)||isempty(hi),width=NaN;return;end
    left=lo+(h-z(lo))/(z(lo+1)-z(lo));
    right=hi-1+(h-z(hi-1))/(z(hi)-z(hi-1));
    width=(right-left)*abs(axisv(2)-axisv(1))/up;
end

function writeJson(path,value)
    f=fopen(path,'w'); assert(f>=0); cleanup=onCleanup(@()fclose(f));
    fprintf(f,'%s\n',jsonencode(value,'PrettyPrint',true));
end


function opts=spatialOptions(options)
    opts=struct('case_ids',{{'1to4'}},'pitch_m',.015,'max_scatter_points',700, ...
        'tile_map',[],'output_dir','','make_plots',true,'save_raw',true);
    assert(isstruct(options)&&isscalar(options),'Input must be a scalar options struct.');
    names=fieldnames(options);
    for i=1:numel(names)
        assert(isfield(opts,names{i}),'Unknown option: %s',names{i});opts.(names{i})=options.(names{i});
    end
    if ischar(opts.case_ids)||isstring(opts.case_ids),opts.case_ids=cellstr(opts.case_ids);end
    assert(iscellstr(opts.case_ids)&&~isempty(opts.case_ids),'case_ids must contain case names.');
    validateattributes(opts.pitch_m,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(opts.max_scatter_points,{'numeric'},{'scalar','integer','finite','positive'});
    validateattributes(opts.make_plots,{'logical'},{'scalar'});
    validateattributes(opts.save_raw,{'logical'},{'scalar'});
    assert(ischar(opts.output_dir)||(isstring(opts.output_dir)&&isscalar(opts.output_dir)));
    opts.output_dir=char(opts.output_dir);
end

function cells=makeCells(map,pitch)
    M=4*size(map,1);[row,col]=ndgrid(1:M,1:M);
    mr=ceil(row/4);mc=ceil(col/4);channel=map(sub2ind(size(map),mr,mc));
    dr=mod(row-1,4)+1;da=mod(col-1,4)+1;
    x=(row-(M+1)/2)*pitch;y=(col-(M+1)/2)*pitch;
    cells=table(row(:),col(:),mr(:),mc(:),channel(:),dr(:),da(:),x(:),y(:),zeros(M*M,1), ...
        'VariableNames',{'row','col','macro_row','macro_col','channel', ...
        'range_delay_type','azimuth_delay_type','x_m','y_m','z_m'});
end

function response=positionResponse(offsets,cells,p,lambda,look)
    % General coordinate sum grouped by identical code histories. Positions
    % enter the carrier's two-way phase; no dependence on counts alone.
    count=height(cells);positions=cells{:,{'x_m','y_m','z_m'}};
    response=complex(zeros(numel(p.tm),numel(p.fast_time_relative)));
    for k=1:size(offsets,1)
        fr=-2*p.Kr*(offsets(k,1)*sin(p.beta))/p.c;
        fa=-p.Ka*offsets(k,2)/p.v_x;
        rp=2*pi*fr*p.fast_time_relative;ap=2*pi*fa*p.tm(:);
        for dr=1:4
            qr=fourPhaseRamp(rp-2*pi*p.inner_delay_fraction(dr),p.state_response,p.state_dwell_fraction);
            slow_weight=complex(zeros(numel(p.tm),1));
            for da=1:4
                ids=cells.channel==k&cells.range_delay_type==dr&cells.azimuth_delay_type==da;
                if ~any(ids),continue;end
                qa=fourPhaseRamp(ap-2*pi*p.inner_delay_fraction(da),p.state_response,p.state_dwell_fraction);
                w=sum(exp(1j*2*(2*pi/lambda)*look*positions(ids,:)'),2)/count;
                slow_weight=slow_weight+qa.*w;
            end
            response=response+slow_weight.*qr;
        end
    end
end

function total=directPositionResponse(offsets,cells,p,lambda,s,a,r)
    total=0;
    for n=1:height(cells)
        k=cells.channel(n);dr=cells.range_delay_type(n);da=cells.azimuth_delay_type(n);
        fr=-2*p.Kr*(offsets(k,1)*sin(p.beta))/p.c;fa=-p.Ka*offsets(k,2)/p.v_x;
        qr=fourPhaseRamp(2*pi*fr*p.fast_time_relative(r)-2*pi*p.inner_delay_fraction(dr),p.state_response,p.state_dwell_fraction);
        qa=fourPhaseRamp(2*pi*fa*p.tm(a)-2*pi*p.inner_delay_fraction(da),p.state_response,p.state_dwell_fraction);
        position=[cells.x_m(n),cells.y_m(n),cells.z_m(n)];
        total=total+qr*qa*exp(1j*2*(2*pi/lambda)*dot(s,position));
    end
    total=total/height(cells);
end

function plotSpatialCase(out,tag,reference,old,new,uniform,pref,puniform,H0,H1,x,y,refpk,tm,tau,offsets,m,um)
    fig=figure('Visible','off','Color','w','Position',[50 50 1550 530]);
    cleaner=onCleanup(@()close(fig));
    layout=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
    images={reference,old,new};titles={'未调制原参考','原模型：通道计数平均','新版：单元位置 + 移动视线'};
    for i=1:3
        ax=nexttile(layout);imagesc(ax,x,y,20*log10(max(abs(images{i})/refpk,1e-12)));
        axis(ax,'xy');axis(ax,'equal');xlim(ax,[-20,20]);ylim(ax,[-20,20]);clim(ax,[-50,0]);
        colormap(ax,turbo);xlabel(ax,'地距 / m');ylabel(ax,'方位 / m');title(ax,titles{i});
        set(ax,'FontName','PingFang SC','FontSize',12);
        if i>1,hold(ax,'on');plot(ax,offsets(:,1),offsets(:,2),'w+');end
    end
    cb=colorbar;cb.Layout.Tile='east';cb.Label.String='共同参考幅度 / dB';
    title(layout,sprintf('%s | 峰值变化 %+.2f dB；目标窗口能量变化 %+.2f dB', ...
        strrep(tag,'to','→'),m.peak_change_db,m.target_roi_energy_change_db),'FontName','PingFang SC');
    exportgraphics(fig,fullfile(out,[tag '_comparison.png']),'Resolution',150);
    savefig(fig,fullfile(out,[tag '_comparison.fig']));clear cleaner;

    fig=figure('Visible','off','Color','w','Position',[50 50 1350 850]);cleaner=onCleanup(@()close(fig));
    layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');[~,it]=min(abs(tau));
    ax=nexttile(layout);plot(ax,tm,20*log10(max(abs(H0(:,it)),1e-12)),tm,20*log10(max(abs(H1(:,it)),1e-12)),'LineWidth',1.1);
    ylim(ax,[-50,0]);grid(ax,'on');xlabel(ax,'慢时间 / s');ylabel(ax,'场幅 / dB');title(ax,'雷达方向幅度：快时间 τ≈0');legend(ax,'原模型','有限阵面','Location','best');
    ax=nexttile(layout);valid=abs(H0(:,it))>10^(-2.5)&abs(H1(:,it))>10^(-2.5);v=nan(size(tm));
    v(valid)=rad2deg(angle(H1(valid,it).*conj(H0(valid,it))));
    plot(ax,tm,v,'.-');ylim(ax,[-180,180]);grid(ax,'on');xlabel(ax,'慢时间 / s');ylabel(ax,'相位差 / °');title(ax,'新增空间相位差；低于 −50 dB 留空');
    [~,ir]=min(abs(x));[~,ia]=min(abs(y));ppk=max(abs(pref(:)));
    for d=1:2
        ax=nexttile(layout);hold(ax,'on');
        if d==1,profiles={pref(:,ir),puniform(:,ir)};axisv=y;axisname='方位 / m';else,profiles={pref(ia,:),puniform(ia,:)};axisv=x;axisname='地距 / m';end
        for i=1:2
            z=abs(interpft(profiles{i},16*numel(axisv)));xx=axisv(1)+(0:numel(z)-1)*(axisv(2)-axisv(1))/16;
            plot(ax,xx,20*log10(max(z/ppk,1e-12)),'LineWidth',1.3);
        end
        xlim(ax,[-1.5,1.5]);ylim(ax,[-50,2]);grid(ax,'on');xlabel(ax,axisname);ylabel(ax,'共同参考幅度 / dB');
        if d==1,title(ax,sprintf('无调制单点方位宽度：%.4f → %.4f m',um.az_width_count_m,um.az_width_spatial_m));
        else,title(ax,sprintf('无调制单点距离宽度：%.4f → %.4f m',um.range_width_count_m,um.range_width_spatial_m));end
        legend(ax,'原参考','有限阵面','Location','southwest');
    end
    set(findall(fig,'Type','axes'),'FontName','PingFang SC','FontSize',11);
    title(layout,'上：编码时序的空间影响；下：单独关闭调制，检查有效合成孔径','FontName','PingFang SC');
    exportgraphics(fig,fullfile(out,[tag '_response_and_focus.png']),'Resolution',150);
    savefig(fig,fullfile(out,[tag '_response_and_focus.fig']));
end

function h=fileHash(filename)
    fid=fopen(filename,'rb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
    md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
    h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
