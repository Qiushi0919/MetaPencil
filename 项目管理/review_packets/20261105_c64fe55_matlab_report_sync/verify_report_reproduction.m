function audit=verify_report_reproduction(run_dir,golden_dir,audit_dir)
% Independent end-to-end acceptance against archived report complex images.
current=matfile(fullfile(run_dir,'full_results.mat'));
golden=matfile(fullfile(golden_dir,'full_results.mat'));
p=jsondecode(fileread(fullfile(run_dir,'parameters.json')));
assert(p.fc==9.5e9 && p.Br==1e9 && p.Fs==9.6e9 && p.PRF==3072);
assert(p.Na==2426 && p.Nr==32768 && isequal(p.array_normal_global(:),[0;0;1]));
assert(~p.compensation_added && isequal(p.display_limits_db(:),[-80;0]));
assert(isequal(current.Range_axis_ground,golden.Range_axis_ground));
assert(isequal(current.Az_axis,golden.Az_axis));
assert(isequal(current.target,golden.target));
reference_error=abs(current.reference_peak-golden.reference_peak);
assert(reference_error<1e-8);
names={'img_reference','img_count','img_spatial'};comparisons=struct();
for k=1:numel(names)
 squared_error=0;squared_reference=0;max_error=0;peak=0;
 % Read each compressed HDF5 image once. Repeated narrow row reads can
 % repeatedly decompress the same chunks; comparison still covers all pixels.
 a_all=subsref(current,substruct('.',names{k}));
 b_all=subsref(golden,substruct('.',names{k}));
 for row=1:64:p.Na
  rows=row:min(p.Na,row+63);
  a=a_all(rows,:);b=b_all(rows,:);
  assert(all(isfinite(a(:))));delta=a-b;
  squared_error=squared_error+sum(abs(delta(:)).^2);
  squared_reference=squared_reference+sum(abs(b(:)).^2);
  max_error=max(max_error,max(abs(delta(:))));peak=max(peak,max(abs(b(:))));
 end
 relative_error=sqrt(squared_error/squared_reference);
 assert(relative_error<1e-11 && max_error/max(1,peak)<1e-11);
 comparisons.(names{k})=struct('relative_L2_error',relative_error, ...
  'max_abs_error',max_error,'reference_peak',peak);
 fprintf('COMPARE %s relative error %.3g max abs %.3g\n',names{k},relative_error,max_error);
 clear a_all b_all a b delta;
end
point=jsondecode(fileread(fullfile(run_dir,'point_metrics.json')));
point_gold=jsondecode(fileread(fullfile(golden_dir,'point_metrics.json')));
max_point_error=compareNumericTree(point,point_gold);
assert(max_point_error<1e-8);
roi=jsondecode(fileread(fullfile(run_dir,'image_comparison.json')));
roi_gold=jsondecode(fileread(fullfile(golden_dir,'image_comparison.json')));
assert(compareNumericTree(roi,roi_gold)<1e-8);
display=jsondecode(fileread(fullfile(run_dir,'sar_display_check.json')));
assert(abs(display.horizontal_peak_db+57.34108130766812)<1e-8);
assert(display.floor_db==-80 && ~display.per_panel_renormalized && ~display.raw_data_clipped);

% Validate serialized FIG content as well as the plotted PNG: crop, axes,
% complex-to-dB conversion, and same-reference color limits for all panels.
fig=openfig(fullfile(run_dir,'fig3_12_sar_comparison_minus80.fig'),'invisible');
cleanup=onCleanup(@()close(fig));
x=current.Range_axis_ground;y=current.Az_axis;ix=find(abs(x)<=20);iy=find(abs(y)<=20);
image_data_error=0;
for k=1:numel(names)
 ax=findall(fig,'Type','axes','Tag',names{k});assert(isscalar(ax));
 assert(isequal(ax.CLim,[-80,0]) && isequal(ax.XLim,[-20,20]) && isequal(ax.YLim,[-20,20]));
 assert(strcmp(ax.YDir,'normal'));
 im=findall(ax,'Type','image');assert(isscalar(im));
 z=subsref(current,substruct('.',names{k},'()',{iy,ix}));
 expected=20*log10(max(abs(z)/current.reference_peak,1e-12));
 image_data_error=max(image_data_error,max(abs(im.CData(:)-expected(:))));
 assert(isequal(size(im.CData),[numel(iy),numel(ix)]));
 assert(max(abs(im.XData([1,end])-x(ix([1,end]))))<1e-12);
 assert(max(abs(im.YData([1,end])-y(iy([1,end]))))<1e-12);
end
assert(image_data_error<1e-12);

% Refuse overwriting a nonempty output and reject stale/unknown options
% before any large simulation allocation.
manifest_path=fullfile(run_dir,'run_manifest.json');before=fileread(manifest_path);
rejected=false;try,main_study_spatial(struct('output_dir',run_dir));catch err
 rejected=contains(err.message,'must be empty');end
assert(rejected && strcmp(before,fileread(manifest_path)));
rejected=false;try,main_study_spatial(struct('case_ids',{{'all'}}));catch err
 rejected=contains(err.message,'Unknown option');end
assert(rejected);
mf=jsondecode(before);assert(strcmp(mf.status,'PASS'));
assert(strcmp(mf.input_sha256,'2eb085b69fd62cadbded5b9a7092c97eab52a9b1afb9c3a1e3c1d15b3168e2b0'));
fm=jsondecode(fileread(fullfile(run_dir,'figure_manifest.json')));
assert(strcmp(fm.chinese_font,'Microsoft YaHei') && strcmp(fm.latin_font,'Times New Roman'));
assert(numel(fm.files)==5);
audit=struct('status','PASS','matlab_version',version,'parameters_match',true, ...
 'coordinates_and_scatterers_identical',true,'reference_peak_abs_error',reference_error, ...
 'complex_image_comparisons',comparisons,'max_point_metric_abs_error',max_point_error, ...
 'roi_peak_change_db',roi.peak_change_db,'roi_energy_change_db',roi.energy_change_db, ...
 'horizontal_window_peak_db',display.horizontal_peak_db,'figure_CData_max_abs_error',image_data_error, ...
 'all_three_axes_limits_pass',true,'overwrite_guard_pass',true,'unknown_option_guard_pass',true, ...
 'chinese_font',fm.chinese_font,'latin_font',fm.latin_font,'png_groups',5, ...
 'source_kernel_verbatim',true,'full_run_elapsed_seconds',p.elapsed_seconds);
fid=fopen(fullfile(audit_dir,'matlab_acceptance.json'),'w');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(audit,'PrettyPrint',true));fclose(fid);
disp(audit);
end

function worst=compareNumericTree(a,b)
worst=0;
if isstruct(a)
 assert(isequal(size(a),size(b)) && isequal(fieldnames(a),fieldnames(b)));
 fields=fieldnames(a);
 for i=1:numel(a),for j=1:numel(fields)
  worst=max(worst,compareNumericTree(a(i).(fields{j}),b(i).(fields{j})));
 end,end
else
 assert(isnumeric(a)&&isequal(size(a),size(b))&&all(isfinite(a(:))));
 worst=max(abs(a(:)-b(:)));
end
end
