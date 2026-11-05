function result=main_study_spatial(options)
% MAIN_STUDY_SPATIAL 复现最新报告的水平阵面 SAR 结果。
% 直接运行：result = main_study_spatial;
% 默认：9–10GHz，Fs=9.6GSa/s，PRF=3072Hz，700散射点，1→4编码。
% options 可选字段：mode('full'或'point'), Fs, PRF, output_dir, make_plots。
% 只重新绘图：plot_report_results(result.output_dir)。
% 旧多案例/四机/倾斜阵面程序完整保存在历史版本/报告同步前_20261105/code。
%
% 阵面水平：r=(x地距,y方位,0)，s=(-Y0,v*eta,H)/sqrt(R0^2+(v*eta)^2)。
% Hspatial=mean(Gamma.*exp(+j*2*k*s.r))；原传播exp(-j*4*pi*R/lambda)。
% 不加方向补偿。保持报告的量化器、四延迟、复回波与RD算法。
% 图3-12统一20log10场幅，参考同次700点未调制图像峰值，显示-80..0dB。
% 模型：理想载频有限阵因子乘完整目标复回波；无真实散射点分区/全波/硬件验证。
if nargin<1,options=struct();end
assert(isstruct(options)&&isscalar(options),'options must be a scalar struct.');
opts=struct('mode','full','Fs',9.6e9,'PRF',3072,'output_dir','','make_plots',true);
names=fieldnames(options);
assert(all(ismember(names,fieldnames(opts))), ...
 'Unknown option. Old case_ids/tile_map interface is preserved in the backup version.');
for i=1:numel(names),opts.(names{i})=options.(names{i});end
assert((ischar(opts.mode)||isstring(opts.mode))&&ismember(string(opts.mode),["full","point"]), ...
 'mode must be full or point.');
opts.mode=char(opts.mode);
validateattributes(opts.Fs,{'numeric'},{'real','finite','positive','scalar'});
validateattributes(opts.PRF,{'numeric'},{'real','finite','positive','scalar'});
assert(islogical(opts.make_plots)&&isscalar(opts.make_plots),'make_plots must be logical scalar.');
assert(ischar(opts.output_dir)||(isstring(opts.output_dir)&&isscalar(opts.output_dir)), ...
 'output_dir must be text.');
script_dir=fileparts(mfilename('fullpath'));
input_file=fullfile(script_dir,'airplane_scatter_points.mat');
assert(isfile(input_file),'Missing input: %s',input_file);
if isempty(opts.output_dir)
 out=fullfile(script_dir,'results_report',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
 n=1;stem=out;while isfolder(out)||isfile(out),out=sprintf('%s_%d',stem,n);n=n+1;end
else
 out=char(opts.output_dir);
end
assert(~isfile(out),'output_dir points to a file.');
if isfolder(out)
 entries=dir(out);assert(all(ismember({entries.name},{'.','..'})), ...
  'Output directory must be empty; existing results will not be overwritten.');
else
 [ok,msg]=mkdir(out);assert(ok,'Cannot create output: %s',msg);
end
manifest=struct('status','RUNNING','version','report_sync_20261105', ...
 'started_local',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
 'matlab_version',version,'baseline_source_commit','c64fe55d0b03684aa7a624bc0cd6a4266463ef45', ...
 'options',opts,'script_sha256',fileHash([mfilename('fullpath') '.m']), ...
 'plot_script_sha256',fileHash(fullfile(script_dir,'plot_report_results.m')), ...
 'input_sha256',fileHash(input_file), ...
 'model_level','ideal carrier horizontal array factor times whole-object complex echo; unchanged RD', ...
 'normalization','20log10 image amplitude / same-run unmodulated reference peak; no clipping', ...
 'physical_scatterer_partition_implemented',false,'direction_compensation_added',false);
writeJson(fullfile(out,'run_manifest.json'),manifest);
copyfile([mfilename('fullpath') '.m'],fullfile(out,'source_main_study_spatial.m'));
copyfile(fullfile(script_dir,'plot_report_results.m'),fullfile(out,'source_plot_report_results.m'));
try
 result=runReport(script_dir,out,opts.mode,opts.Fs,opts.PRF);
 if opts.make_plots,result.figures=plot_report_results(out);end
 manifest.status='PASS';manifest.parameters=result.parameters;manifest.checks=result.checks;
 if isfield(result,'display'),manifest.display=result.display;end
 if isfield(result,'figures'),manifest.figures=result.figures;end
 manifest.finished_local=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
 writeJson(fullfile(out,'run_manifest.json'),manifest);
 fprintf('结果目录：%s\n',out);
catch err
 manifest.status='FAILED';manifest.error=getReport(err,'extended','hyperlinks','off');
 writeJson(fullfile(out,'run_manifest.json'),manifest);rethrow(err);
end
end

function result=runReport(script_dir,dest,mode,Fs,PRF)
stamp=tic;tag=sprintf('%s_Fs%.1f_PRF%d',mode,Fs/1e9,PRF);
p=struct('c',3e8,'fc',9.5e9,'Br',1e9,'Tp',1e-6,'beta',deg2rad(60), ...
 'H0',500,'v_x',80,'Fs',Fs,'PRF',PRF,'pitch_m',.015);
p.lambda=p.c/p.fc;p.Y0=p.H0*tan(p.beta);p.R0=hypot(p.H0,p.Y0);
p.Kr=p.Br/p.Tp;p.Ka=-2*p.v_x^2/(p.lambda*p.R0);
p.nominal_az_resolution=.25;p.nominal_ground_resolution=p.c/(2*p.Br*sin(p.beta));
p.aperture_length=p.lambda*p.R0/(2*p.nominal_az_resolution);p.aperture_time=p.aperture_length/p.v_x;
p.Na=ceil(p.aperture_time*PRF);if mod(p.Na,2),p.Na=p.Na+1;end
% Original Tp+4margin/c only covers received support, not full correlation.
% Use 2Tp+4margin/c, preserving the center time and axis definitions.
p.fast_span_required=2*p.Tp+4*48/p.c;p.Nr=2^nextpow2(ceil(p.fast_span_required*Fs));
tm=(-p.Na/2:p.Na/2-1)/PRF;t=2*p.R0/p.c+(-p.Nr/2:p.Nr/2-1)/Fs;dt=1/Fs;
p.tm=tm;p.fast_time_relative=t-2*p.R0/p.c;p.state_response=exp(1j*(0:3)*pi/2);
p.state_dwell_fraction=ones(1,4)/4;p.inner_delay_fraction=[0,1/10,5/6,14/15];
x=tm*p.v_x;look=[-p.Y0*ones(p.Na,1),x(:),p.H0*ones(p.Na,1)]./sqrt(p.R0^2+x(:).^2);
p.display_limits_db=[-80,0];p.display_half_width_m=20;
p.compensation_added=false;p.array_normal_global=[0,0,1];p.array_orientation='horizontal ground plane';p.center_incidence_deg=rad2deg(p.beta);
offsets=[-8,-8;8,-8;-8,8;8,8];map=balancedTileMap(4,4);cells=makeCells(map,p.pitch_m);
fprintf('START %s Na=%d Nr=%d\n',tag,p.Na,p.Nr);
focus=@(z)rdFocus(z,t,tm,dt,p.c,p.R0,p.Tp,p.Kr,p.lambda,p.v_x,p.Ka,PRF);
sr_point=echoPoints([0,0],p,t,x);
[point_reference,R_axis,Az_axis]=focus(sr_point);Range_axis_ground=R_axis/sin(p.beta);
reference_point_peak=max(abs(point_reference(:)));
[response_count,channel_table,tile_table]=compilePhysicalResponse(offsets,map,p);
point_count=focus(sr_point.*response_count);
response_spatial=positionResponse(offsets,cells,p,p.lambda,look);
point_spatial=focus(sr_point.*response_spatial);
pun=p;pun.inner_delay_fraction=0;response_ordinary=compilePhysicalResponse(offsets,map,pun);
point_ordinary=focus(sr_point.*response_ordinary);
uniform_response=mean(exp(1j*2*(2*pi/p.lambda)*look*cells{:,{'x_m','y_m','z_m'}}'),2);
point_uniform=focus(sr_point.*uniform_response);
metrics=struct();metrics.reference=pointMetrics(point_reference,Range_axis_ground,Az_axis,[0,0]);
metrics.uniform=pointMetrics(point_uniform,Range_axis_ground,Az_axis,[0,0]);
names={'count','spatial','ordinary'};images={point_count,point_spatial,point_ordinary};
for j=1:3
 rows=struct([]);
 for k=1:4
  m=pointMetrics(images{j},Range_axis_ground,Az_axis,offsets(k,:));
  m.peak_db=20*log10(m.peak/reference_point_peak);rows=[rows;m];
 end
 metrics.(names{j})=rows;
end
ix=abs(Range_axis_ground)<=55;iy=abs(Az_axis)<=55;
gx=Range_axis_ground(ix);gy=Az_axis(iy);
ref=point_reference(iy,ix)/reference_point_peak;pc=point_count(iy,ix)/reference_point_peak;
ps=point_spatial(iy,ix)/reference_point_peak;po=point_ordinary(iy,ix)/reference_point_peak;
pu=point_uniform(iy,ix)/reference_point_peak;
save(fullfile(dest,'point_images.mat'),'gx','gy','ref','pc','ps','po','pu','-v7.3');
writeJson(fullfile(dest,'point_metrics.json'),metrics);
checks=struct('all_finite',all(isfinite(point_spatial(:))),'source_quantizer_unmodified',true);
for a=unique([1,round(p.Na/2)+1,p.Na])
 for r=[1,round(p.Nr/2)+1,p.Nr]
  direct=directPositionResponse(offsets,cells,p,p.lambda,look(a,:),a,r);
  err=abs(direct-response_spatial(a,r));assert(err<1e-12);
 end
end
checks.direct_cell_sum=true;
if strcmp(mode,'full')
 loaded=load(fullfile(script_dir,'airplane_scatter_points.mat'),'my_data');
 target_all=loaded.my_data;
 assert(size(target_all,2)==2 && size(target_all,1)>=700 && all(isfinite(target_all(:))), ...
  'Report input requires at least700 finite two-coordinate scatterers.');
 keep=round(linspace(1,size(target_all,1),700));target=target_all(keep,:);
 sr_center=echoPoints(target,p,t,x);
 [img_reference,~,~]=focus(sr_center);reference_peak=max(abs(img_reference(:)));
 img_count=focus(sr_center.*response_count);img_spatial=focus(sr_center.*response_spatial);
 img_ordinary=focus(sr_center.*response_ordinary);img_uniform=focus(sr_center.*uniform_response);
 mask=false(size(img_count));
 for k=1:4,mask=mask|((abs(Range_axis_ground-offsets(k,1))<3.9)&(abs(Az_axis(:)-offsets(k,2))<3.9));end
 summary=compareImages(img_count,img_spatial,mask);
 summary.peak_change_view_db=20*log10(max(abs(img_spatial(:)))/max(abs(img_count(:))));
 writeJson(fullfile(dest,'image_comparison.json'),summary);
 mask_view=abs(Range_axis_ground)<=20 & abs(Az_axis(:))<=20;
 display_check=struct('window_m',[-20,20],'floor_db',-80,'ceiling_db',0, ...
  'reference',reference_peak, ...
  'horizontal_peak_db',20*log10(max(abs(img_spatial(mask_view)))/reference_peak), ...
  'count_peak_db',20*log10(max(abs(img_count(mask_view)))/reference_peak), ...
  'per_panel_renormalized',false,'raw_data_clipped',false);
 writeJson(fullfile(dest,'sar_display_check.json'),display_check);
 save(fullfile(dest,'full_results.mat'),'img_reference','img_count','img_spatial','img_ordinary','img_uniform', ...
  'point_reference','point_uniform','sr_center','target','response_count','response_spatial', ...
  'uniform_response','Range_axis_ground','Az_axis','t','tm','reference_peak','reference_point_peak','offsets','map','-v7.3');
 writetable(cells,fullfile(dest,'cells.csv'));writetable(channel_table,fullfile(dest,'channels.csv'));
 writetable(tile_table,fullfile(dest,'tiles.csv'));
 % Stable switching intervals and precise MATLAB slow states for plots.
 fr=channel_table.range_mod_frequency_hz;fa=channel_table.azimuth_mod_frequency_hz;
 T=1/abs(fr(1));edges=[0,1];D=p.inner_delay_fraction;
 for s=[-1,1],for d=D,edges=[edges,mod(s*((0:3)/4+d),1)];end,end
 edges=unique(round(edges*1e12)/1e12)*T;mids=(edges(1:end-1)+edges(2:end))/2;
 gammas=zeros(height(cells),numel(mids));
 for ii=1:numel(mids),for n=1:height(cells)
  k=cells.channel(n);dr=cells.range_delay_type(n);da=cells.azimuth_delay_type(n);
  gammas(n,ii)=fourPhaseRamp(2*pi*fr(k)*mids(ii)-2*pi*D(dr),p.state_response,p.state_dwell_fraction)* ...
   fourPhaseRamp(-2*pi*D(da),p.state_response,p.state_dwell_fraction);
 end,end
 slow_states=zeros(p.Na,4);fast_example_t=[1.2,5]*1e-9;
 for d=1:4,slow_states(:,d)=mod(round(angle(fourPhaseRamp(2*pi*fa(4)*tm(:)-2*pi*D(d),p.state_response,p.state_dwell_fraction))/(pi/2)),4);end
 save(fullfile(dest,'timing.mat'),'fr','fa','D','edges','mids','gammas','slow_states','tm','fast_example_t','-v7');
end
parameters=rmfield(p,{'tm','fast_time_relative','state_response'});
parameters.state_response_deg=[0,90,180,270];parameters.actual_aperture_N_over_PRF=p.Na/PRF;
parameters.source='report-synced portable MATLAB entry; unchanged report quantizer/response/RD';
parameters.normalization='image amplitude to unmodulated reference peak within same run; raw complex values not clipped';
parameters.model_level='horizontal ground plane at60deg incidence; ideal carrier finite planar array factor times complete object complex echo; no actual wideband unit-cell response';
parameters.elapsed_seconds=toc(stamp);writeJson(fullfile(dest,'parameters.json'),parameters);
writeJson(fullfile(dest,'checks.json'),checks);
result=struct('output_dir',dest,'parameters',parameters,'point_metrics',metrics,'checks',checks);
if strcmp(mode,'full'),result.comparison=summary;result.display=display_check;end
fprintf('DONE %s seconds=%.2f\n',tag,toc(stamp));
end

function sr=echoPoints(target,p,t,x)
sr=complex(zeros(p.Na,p.Nr));
for a=1:p.Na
 row=complex(zeros(1,p.Nr));
 for i=1:size(target,1)
  r=sqrt((x(a)-target(i,1))^2+(p.Y0+target(i,2))^2+p.H0^2);
  tau=t-2*r/p.c;ind=find(abs(tau)<=p.Tp/2);
  row(ind)=row(ind)+(p.R0/r)^2*exp(-1j*4*pi*r/p.lambda).*exp(1j*pi*p.Kr*tau(ind).^2);
 end
 sr(a,:)=row;
 if size(target,1)>1 && mod(a,100)==0,fprintf(' ECHO %d/%d\n',a,p.Na);end
end
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


function value=fileHash(path)
    fid=fopen(path,'rb');assert(fid>=0,'Cannot read %s',path);
    clean=onCleanup(@()fclose(fid));
    digest=java.security.MessageDigest.getInstance('SHA-256');
    while ~feof(fid)
        bytes=fread(fid,1024*1024,'*uint8');digest.update(bytes);
    end
    value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
