%% RUN_SINGLE_TEST - Test the pipeline on one run before full batch
%
% Runs saliencepain (task05) as the first test because:
%   - Clear condition contrast (Pain vs NoPain)
%   - Single run (fast)
%   - Likely to show significant condition separation
%
% After this succeeds:
%   >> open_dashboard          % view results in browser
%   >> run_EP01AN96M1047_all_tasks   % run all 11 runs
%
% Usage:
%   >> run_single_test

%% Setup
code_root = fileparts(mfilename('fullpath'));
addpath(fullfile(code_root, 'code'));
add_paths();

% Verify EEGLAB + BrainVision plugin
if ~exist('pop_loadbv', 'file')
    % Try to find and add bva-io plugin automatically
    if exist('eeglab', 'file')
        eeglab_path = fileparts(which('eeglab'));
        bva_dirs = dir(fullfile(eeglab_path, 'plugins', 'bva*'));
        if ~isempty(bva_dirs)
            bva_path = fullfile(eeglab_path, 'plugins', bva_dirs(1).name);
            addpath(bva_path);
            fprintf('Added bva-io plugin: %s\n', bva_path);
        else
            error(['BrainVision plugin (bva-io) not found.\n' ...
                   'Install it: eeglab → File → Manage Extensions → search "bva-io"']);
        end
    else
        error('EEGLAB not found on path. Add it first: addpath(genpath(''/path/to/eeglab''))');
    end
end

%% Paths
bids_root   = '/Volumes/OHDD/DATA/epilepsy';
subject     = 'EP01AN96M1047';

%% Define single run: saliencepain
run_info = struct();
run_info.session     = 'task05';
run_info.task        = 'saliencepain';
run_info.run         = '01';
run_info.epoch_event = 'stimulus';
run_info.description = 'Salience/pain processing';

results_dir = fullfile(bids_root, ['sub-' subject], ['ses-' run_info.session], 'ieeg', 'results');

fprintf('=== Single Run Test: %s ===\n', run_info.task);
fprintf('Start: %s\n\n', datestr(now));

tic;
summary = process_bids_run(bids_root, subject, run_info, results_dir);
elapsed = toc;

%% Print summary
fprintf('\n%s\n', repmat('=', 1, 60));
if summary.success
    fprintf('SUCCESS in %.1f minutes\n', elapsed / 60);
    fprintf('Trials: %d, Channels: %d\n', summary.n_trials, summary.n_channels);
    fprintf('Conditions: %s\n', strjoin(summary.conditions, ', '));
    fprintf('Stages completed: %d\n', numel(summary.stages_complete));
    fprintf('Figures generated: %d\n', summary.n_figures);

    % Generate Reports
    fprintf('\nGenerating Markdown/LaTeX reports...\n');
    generate_stage_report(summary.run_output, 'md');
    generate_stage_report(summary.run_output, 'tex');

    % Print Significant Features
    fprintf('\n--- STATISTICAL SIGNIFICANCE SUMMARY ---\n');
    stats_file = fullfile(summary.run_output, 'results', 'stage09_stats.mat');
    preproc_file = fullfile(summary.run_output, 'results', 'stage03_preproc.mat');
    if isfile(stats_file)
        s9 = load(stats_file);
        if isfield(s9, 'stats')
            if isfile(preproc_file)
                s3 = load(preproc_file, 'channel_labels');
                ch_labels = s3.channel_labels;
            else
                ch_labels = arrayfun(@(x) sprintf('Ch%d', x), 1:numel(s9.stats.roi_p_values), 'UniformOutput', false);
            end
            sig_idx = find(s9.stats.roi_significant);
            if isempty(sig_idx)
                fprintf('No statistically significant channels found (FDR corrected).\n');
            else
                fprintf('Found %d statistically significant channel(s):\n', numel(sig_idx));
                [~, sort_idx] = sort(s9.stats.roi_p_fdr(sig_idx));
                sorted_sig_idx = sig_idx(sort_idx);
                for idx = sorted_sig_idx(:)'
                    fprintf('  - %s: p(FDR)=%.4f, d=%.2f, onset=%.3fs\n', ...
                        ch_labels{idx}, s9.stats.roi_p_fdr(idx), ...
                        s9.stats.effect_sizes(idx), s9.stats.onset_times(idx));
                end
            end
        end
    else
        fprintf('Statistical results not found.\n');
    end
    fprintf('----------------------------------------\n');

    fprintf('\nResults saved to: %s\n', summary.run_output);
    fprintf('  Stage files:  stage01_bids.mat ... stage16_roi.mat\n');
    fprintf('  Legacy file:  results.mat (lightweight)\n');
    fprintf('\nNext steps:\n');
    fprintf('  >> open_dashboard                   %% view in browser\n');
    fprintf('  >> run_EP01AN96M1047_all_tasks      %% run all 11 runs\n');
else
    fprintf('FAILED\n');
    fprintf('Check error messages above.\n');
end
fprintf('%s\n', repmat('=', 1, 60));
