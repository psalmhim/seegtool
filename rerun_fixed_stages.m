% RERUN_FIXED_STAGES Delete stage files affected by decoder/QC fixes.
%   Run this script, then re-run run_EP01AN96M1047_all_tasks to regenerate
%   results with the corrected pipeline.
%
%   Stages deleted:
%     stage05_qc.mat       - QC thresholds changed
%     stage14_decoding.mat - Decoder fixes (fold consistency, onset, imbalance)
%     stage14b_contrasts.mat - Depends on decoding
%   Also deletes figures/ and reports so they regenerate.

results_root = '/Volumes/OHDD/DATA/epilepsy/derivatives/seegring/sub-EP01AN96M1047';

task_dirs = dir(fullfile(results_root, 'task-*'));

stages_to_delete = {
    'stage05_qc.mat'
    'stage14_decoding.mat'
    'stage14b_contrasts.mat'
};

for d = 1:numel(task_dirs)
    task_path = fullfile(results_root, task_dirs(d).name, 'results');
    if ~isfolder(task_path)
        continue;
    end
    fprintf('\n=== %s ===\n', task_dirs(d).name);
    for s = 1:numel(stages_to_delete)
        f = fullfile(task_path, stages_to_delete{s});
        if isfile(f)
            delete(f);
            fprintf('  Deleted %s\n', stages_to_delete{s});
        end
    end
    % Delete report files so they regenerate
    report_md = fullfile(results_root, task_dirs(d).name, 'report.md');
    report_tex = fullfile(results_root, task_dirs(d).name, 'report.tex');
    if isfile(report_md), delete(report_md); fprintf('  Deleted report.md\n'); end
    if isfile(report_tex), delete(report_tex); fprintf('  Deleted report.tex\n'); end
end

fprintf('\nDone. Now run: run_EP01AN96M1047_all_tasks\n');
