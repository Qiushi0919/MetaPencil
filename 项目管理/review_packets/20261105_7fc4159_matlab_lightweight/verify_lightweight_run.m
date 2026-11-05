function audit=verify_lightweight_run(run_dir,old_dir,packet,code_dir)
addpath(code_dir);
p=jsondecode(fileread(fullfile(run_dir,'parameters.json')));
old=jsondecode(fileread(fullfile(old_dir,'parameters.json')));
assert(isequaln(rmfield(p,'elapsed_seconds'),rmfield(old,'elapsed_seconds')));
assert(p.Na==2426&&p.Nr==32768&&p.Fs==9.6e9&&p.PRF==3072);
assert(isempty(dir(fullfile(run_dir,'**','*.mat')))&&isempty(dir(fullfile(run_dir,'**','*.fig'))));
names={'point_metrics.json','image_comparison.json','sar_display_check.json','checks.json'};
for k=1:numel(names)
 assert(isequaln(jsondecode(fileread(fullfile(run_dir,names{k}))), ...
  jsondecode(fileread(fullfile(old_dir,names{k})))),'Metrics differ: %s',names{k});
end
fm=jsondecode(fileread(fullfile(run_dir,'figure_manifest.json')));assert(numel(fm.files)==5);
rows=struct([]);
for k=1:numel(fm.files)
 name=fm.files{k};a=imread(fullfile(run_dir,name));b=imread(fullfile(old_dir,name));
 assert(isequal(a,b),'Pixels differ: %s',name);
 rows(k).name=name;rows(k).max_pixel_difference=0;
 fprintf('PNG EXACT MATCH %s\n',name);
end
for name={'cells.csv','channels.csv','tiles.csv'}
 assert(strcmp(fileread(fullfile(run_dir,name{1})),fileread(fullfile(old_dir,name{1}))));
end
mf=jsondecode(fileread(fullfile(run_dir,'run_manifest.json')));
assert(strcmp(mf.status,'PASS')&&~mf.full_complex_arrays_saved&&~mf.editable_figures_saved);
assert(~fm.full_complex_arrays_saved&&~fm.editable_figures_saved);
assert(strcmp(mf.input_sha256,'2eb085b69fd62cadbded5b9a7092c97eab52a9b1afb9c3a1e3c1d15b3168e2b0'));
for name={'main_study_spatial.m','plot_report_results.m'}
 assert(strcmp(fileread(fullfile(code_dir,name{1})),fileread(fullfile(run_dir,['source_' name{1}]))));
end
before=fileread(fullfile(run_dir,'run_manifest.json'));
rejected=false;try,main_study_spatial(struct('output_dir',run_dir));catch err
 rejected=contains(err.message,'must be empty');end
assert(rejected&&strcmp(before,fileread(fullfile(run_dir,'run_manifest.json'))));
no_cache=false;try,plot_report_results(run_dir);catch err
 no_cache=strcmp(err.identifier,'plot_report_results:NoSavedData');end
assert(no_cache);
files=dir(fullfile(run_dir,'*'));files=files(~[files.isdir]);bytes=sum([files.bytes]);
assert(bytes<15e6,'Unexpectedly large lightweight output.');
audit=struct('status','PASS','matlab_version',version,'same_parameters_except_elapsed_time',true, ...
 'all_metrics_identical',true,'all_five_png_pixels_identical',true,'pngs',rows, ...
 'control_csv_identical',true,'no_mat_or_fig_files',true,'no_cached_data_guard',true, ...
 'overwrite_guard',true,'same_input_data',true,'source_snapshots_match',true, ...
 'total_bytes',bytes,'total_decimal_MB',bytes/1e6,'total_MiB',bytes/1024^2, ...
 'file_count',numel(files),'numeric_elapsed_seconds',p.elapsed_seconds);
fid=fopen(fullfile(packet,'acceptance.json'),'w');fprintf(fid,'%s\n',jsonencode(audit,'PrettyPrint',true));fclose(fid);
disp(audit);
end
