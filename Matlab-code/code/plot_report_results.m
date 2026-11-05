function info=plot_report_results(output_dir,data)
% PLOT_REPORT_RESULTS 直接绘制内存中的计算结果，只输出PNG。
% 三模型图统一未调制参考，-80..0dB，地距/方位±20m；其他控制图-50..0dB。
% 单参数调用仅兼容已有完整MAT归档；轻量结果需重算后绘图。
assert(isfolder(output_dir),'Result directory not found.');
p=jsondecode(fileread(fullfile(output_dir,'parameters.json')));
metrics=jsondecode(fileread(fullfile(output_dir,'point_metrics.json')));
fonts=listfonts;
cn=chooseFont(fonts,{'Microsoft YaHei','微软雅黑','PingFang SC','Heiti SC','Arial Unicode MS'});
en=chooseFont(fonts,{'Times New Roman','Times','Liberation Serif'});
info=struct('chinese_font',cn,'latin_font',en,'display_range_db',[-80,0], ...
 'raw_complex_data_clipped',false,'per_panel_renormalized',false, ...
 'full_complex_arrays_saved',false,'editable_figures_saved',false,'files',{{}});
datafile=fullfile(output_dir,'full_results.mat');
if nargin<2
 if isfile(datafile)
  data=matfile(datafile);point_only=false;
 elseif isfile(fullfile(output_dir,'point_images.mat'))
  data=load(fullfile(output_dir,'point_images.mat'));point_only=true;
 else
  error('plot_report_results:NoSavedData', ...
   'This lightweight run contains PNGs and metrics only. Rerun main_study to redraw.');
 end
else
 assert(isstruct(data)&&isfield(data,'mode'),'Missing in-memory plot data.');
 point_only=strcmp(data.mode,'point');
end
if point_only
 fig=newFigure(1500,500);tl=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
 keys={'ref','pc','ps'};titles={'未调制单点','计数平均单点','水平空间单点'};
 for k=1:3
  ax=nexttile(tl);drawSAR(ax,data.gx,data.gy,data.(keys{k}),1,20,-80,titles{k},cn,en);
 end
 cb=colorbar(ax);cb.Layout.Tile='east';cb.Ticks=-80:10:0;cb.FontName=en;cb.Label.String=mixed('共同单点参考幅度','/ dB',cn,en);
 info.files{end+1}=savePlot(fig,output_dir,'point_comparison_minus80');
 info.normalization='point images divided by same-run unmodulated point peak';
 writePlotJson(output_dir,info);return;
end

m=data;x=m.Range_axis_ground;y=m.Az_axis;
ref=m.reference_peak;point_ref=m.reference_point_peak;
assert(isfinite(ref)&&ref>0&&isfinite(point_ref)&&point_ref>0);
ix=find(abs(x)<=20);iy=find(abs(y)<=20);
fig=newFigure(1500,500);tl=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
keys={'img_reference','img_count','img_spatial'};titles={'未调制参考','计数平均模型','水平空间模型'};
peaks=zeros(1,3);
for k=1:3
 z=readCrop(m,keys{k},iy,ix);
 ax=nexttile(tl);drawSAR(ax,x(ix),y(iy),z,ref,20,-80,titles{k},cn,en);
 ax.Tag=keys{k};
 peaks(k)=20*log10(max(abs(z(:)))/ref);
 assert(isequal(clim(ax),[-80,0]));
 if k==3
  text(ax,.04,.96,mixed('窗口峰值',sprintf('%.2f dB',peaks(k)),cn,en), ...
   'Units','normalized','Color','white','VerticalAlignment','top','Interpreter','tex','FontSize',10);
 end
end
cb=colorbar(ax);cb.Layout.Tile='east';cb.Ticks=-80:10:0;
cb.FontName=en;cb.Label.Interpreter='tex';cb.Label.String=mixed('共同参考幅度','/ dB',cn,en);
info.files{end+1}=savePlot(fig,output_dir,'fig3_12_sar_comparison_minus80');
info.normalization='20log10(abs(image)/same-run unmodulated700point peak)';
info.reference_amplitude=ref;info.window_peak_db=peaks;info.window_ground_az_m=[-20,20];

% 图3-1：单个亮点、不加调制；两方向剖面沿用报告的16倍频域插值。
fig=newFigure(1400,650);tl=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
ir=find(abs(x)<=1);ia=find(abs(y)<=1);
ax=nexttile(tl,1,[2,1]);drawSAR(ax,x(ir),y(ia),m.point_reference(ia,ir),point_ref,1,-50,'单个点目标 未加调制',cn,en);
cb=colorbar(ax);cb.FontName=en;cb.Label.String=mixed('单点峰值参考','/ dB',cn,en);
profileR=m.point_reference(p.Na/2+1,:);profileA=m.point_reference(:,p.Nr/2+1);
ax=nexttile(tl,2);drawCut(ax,profileR,x,point_ref,.8,-50, ...
 mixed('地距剖面',sprintf(' -3 dB %.4f m',metrics.reference.range_width_m),cn,en),en,cn);
ax=nexttile(tl,4);drawCut(ax,profileA,y,point_ref,.8,-50, ...
 mixed('方位剖面',sprintf(' -3 dB %.4f m',metrics.reference.az_width_m),cn,en),en,cn);
info.files{end+1}=savePlot(fig,output_dir,'fig3_1_point_unmodulated');

% 图3-2：未调制700点与局部细节；共同参考、相同色阶。
fig=newFigure(1300,620);tl=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
limits=[29,5];titles={'未调制参考','中心局部放大'};
for k=1:2
 ir=find(abs(x)<=limits(k));ia=find(abs(y)<=limits(k));ax=nexttile(tl);
 drawSAR(ax,x(ir),y(ia),m.img_reference(ia,ir),ref,limits(k),-50,titles{k},cn,en);
 colormap(ax,gray(256));cb=colorbar(ax);cb.FontName=en;
end
info.files{end+1}=savePlot(fig,output_dir,'fig3_2_reference_unmodulated');

% 图3-3：普通四态和四延迟相消的计数模型对照，沿用报告±29m视窗。
fig=newFigure(1300,620);tl=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
ir=find(abs(x)<=29);ia=find(abs(y)<=29);
keys={'img_ordinary','img_count'};
titles={[mixed('普通','2-bit',cn,en) ' \fontname{' cn '}编码'],'四延迟相消编码'};
for k=1:2
 ax=nexttile(tl);drawSAR(ax,x(ir),y(ia),readCrop(m,keys{k},ia,ir),ref,29,-50,titles{k},cn,en);
end
cb=colorbar(ax);cb.Layout.Tile='east';cb.FontName=en;cb.Label.String=mixed('共同未调制参考','/ dB',cn,en);
info.files{end+1}=savePlot(fig,output_dir,'fig3_3_ordinary_vs_delay');

% 图3-13：慢时间响应，以及未调制的水平阵面单点控制。
tm=m.tm;
if isstruct(m)&&isfield(m,'slow_count')
 h0=m.slow_count;h1=m.slow_spatial;
else
 h0=m.response_count(:,p.Nr/2+1);h1=m.response_spatial(:,p.Nr/2+1);
end
fig=newFigure(1400,850);tl=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(tl);plot(ax,tm,abs(h0),tm,abs(h1),'LineWidth',.8);styleAxes(ax,en);
title(ax,'雷达方向场幅（快时间为零）','FontName',cn);
xlabel(ax,mixed('慢时间','/ s',cn,en));ylabel(ax,'归一化场幅','FontName',cn);
legend(ax,{'计数平均','空间响应'},'FontName',cn);
ax=nexttile(tl);phase=angle(h1.*conj(h0))*180/pi;
phase(abs(h0)<10^(-50/20)|abs(h1)<10^(-50/20))=NaN;
plot(ax,tm,phase,'LineWidth',.8);styleAxes(ax,en);
title(ax,'空间响应相对计数响应的相位','FontName',cn);
xlabel(ax,mixed('慢时间','/ s',cn,en));ylabel(ax,mixed('相位差','/ deg',cn,en));
profiles={profileA,m.point_uniform(:,p.Nr/2+1);profileR,m.point_uniform(p.Na/2+1,:)};
axes_values={y,x};cut_titles={'方位单点剖面','地距单点剖面'};
for k=1:2
 ax=nexttile(tl);hold(ax,'on');
 for j=1:2
  [xp,zp]=interpolatedCut(profiles{k,j},axes_values{k},point_ref);
  keep=abs(xp)<=1;plot(ax,xp(keep),zp(keep),'LineWidth',1.1);
 end
 styleAxes(ax,en);xlim(ax,[-1,1]);ylim(ax,[-50,0]);
 title(ax,cut_titles{k},'FontName',cn);xlabel(ax,mixed('相对位置','/ m',cn,en));
 ylabel(ax,mixed('共同单点参考','/ dB',cn,en));
 legend(ax,{'计数模型未调制','空间模型未调制'},'FontName',cn,'Location','south');
end
info.files{end+1}=savePlot(fig,output_dir,'fig3_13_slow_time_and_point_controls');
writePlotJson(output_dir,info);
end

function z=readCrop(m,key,iy,ix)
 % matfile dynamic field indexing needs a subscript structure on older releases.
 z=subsref(m,substruct('.',key,'()',{iy,ix}));
end

function fig=newFigure(w,h)
 fig=figure('Color','white','Visible','off','Units','pixels','Position',[80,80,w,h]);
end

function drawSAR(ax,x,y,z,ref,lim,floor_db,name,cn,en)
 imagesc(ax,x,y,20*log10(max(abs(z)/ref,1e-12)),[floor_db,0]);
 set(ax,'YDir','normal');axis(ax,'image');xlim(ax,[-lim,lim]);ylim(ax,[-lim,lim]);
 colormap(ax,turbo(256));set(ax,'FontName',en,'FontSize',11,'Box','on');
 xlabel(ax,mixed('相对地距','/ m',cn,en),'Interpreter','tex');
 ylabel(ax,mixed('方位','/ m',cn,en),'Interpreter','tex');
 title(ax,name,'FontName',cn,'Interpreter','tex','FontWeight','normal','FontSize',14);
end

function drawCut(ax,profile,axisv,ref,lim,floor_db,name,en,cn)
 [xp,zp]=interpolatedCut(profile,axisv,ref);keep=abs(xp)<=lim;
 plot(ax,xp(keep),zp(keep),'LineWidth',1.2);hold(ax,'on');yline(ax,-3.0103,'--');
 styleAxes(ax,en);xlim(ax,[-lim,lim]);ylim(ax,[floor_db,1]);
 xlabel(ax,mixed('相对位置','/ m',cn,en));ylabel(ax,mixed('幅度','/ dB',cn,en));
 title(ax,name,'Interpreter','tex','FontWeight','normal');
end

function [x,z]=interpolatedCut(profile,axisv,ref)
 v=interpft(profile(:),16*numel(profile));
 x=axisv(1)+(0:numel(v)-1)'*(axisv(2)-axisv(1))/16;
 z=20*log10(max(abs(v)/ref,1e-12));
end

function styleAxes(ax,en)
 set(ax,'FontName',en,'FontSize',11,'Box','on');grid(ax,'on');ax.GridAlpha=.15;
end

function text=mixed(cjk,latin,cn,en)
 text=['\fontname{' cn '}' cjk ' \fontname{' en '}' latin];
end

function name=chooseFont(available,preferences)
 name=preferences{1};
 for k=1:numel(preferences)
  if any(strcmpi(available,preferences{k})),name=preferences{k};return;end
 end
 warning('Requested fonts unavailable; renderer will substitute %s.',name);
end

function name=savePlot(fig,out,stem)
 name=[stem '.png'];drawnow;
 exportgraphics(fig,fullfile(out,name),'Resolution',240,'BackgroundColor','white');
 if usejava('desktop'),set(fig,'Visible','on');else,close(fig);end
end

function writePlotJson(out,info)
 fid=fopen(fullfile(out,'figure_manifest.json'),'w');assert(fid>=0);
 clean=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(info,'PrettyPrint',true));
end
