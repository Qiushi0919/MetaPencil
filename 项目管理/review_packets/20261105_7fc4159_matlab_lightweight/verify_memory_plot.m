function audit=verify_memory_plot(code_dir,old_run,out)
addpath(code_dir);
assert(~isfolder(out));mkdir(out);
copyfile(fullfile(old_run,'parameters.json'),fullfile(out,'parameters.json'));
copyfile(fullfile(old_run,'point_metrics.json'),fullfile(out,'point_metrics.json'));
p=jsondecode(fileread(fullfile(out,'parameters.json')));
f=fullfile(old_run,'full_results.mat');
data=load(f,'Range_axis_ground','Az_axis','reference_peak','reference_point_peak', ...
 'img_reference','img_count','img_spatial','img_ordinary','point_reference','point_uniform','tm');
m=matfile(f);data.slow_count=m.response_count(:,p.Nr/2+1);data.slow_spatial=m.response_spatial(:,p.Nr/2+1);
data.mode='full';info=plot_report_results(out,data);clear data;
assert(isempty(dir(fullfile(out,'*.mat')))&&isempty(dir(fullfile(out,'*.fig'))));
results=struct([]);
for k=1:numel(info.files)
 name=info.files{k};a=imread(fullfile(out,name));b=imread(fullfile(old_run,name));
 assert(isequal(a,b),'PNG pixels differ: %s',name);
 results(k).file=name;results(k).pixels_identical=true;
end
% The lightweight directory deliberately cannot be used as a cached dataset.
rejected=false;try,plot_report_results(out);catch err
 rejected=strcmp(err.identifier,'plot_report_results:NoSavedData');end
assert(rejected);
audit=struct('status','PASS','png_comparisons',results,'no_mat_or_fig',true,'no_saved_data_guard',rejected);
fid=fopen(fullfile(out,'validation.json'),'w');fprintf(fid,'%s\n',jsonencode(audit,'PrettyPrint',true));fclose(fid);
disp(audit);
for name={'main_study.m','main_study_spatial.m','plot_report_results.m'}
 fprintf('CHECKCODE %s\n',name{1});disp(jsonencode(checkcode(fullfile(code_dir,name{1}),'-id')));
end
end
