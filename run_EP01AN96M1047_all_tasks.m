%% RUN_EP01AN96M1047_ALL_TASKS
% Batch SEEG population dynamics analysis for subject EP01AN96M1047.
%
% Analyzes all 8 task sessions (11 runs total):
%   ses-task01: lexicaldecision  (1 run)  - Visual word/nonword discrimination
%   ses-task02: shapecontrol     (1 run)  - Shape control task
%   ses-task03: sentencenoun     (1 run)  - Sentence noun comprehension
%   ses-task04: sentencegrammar  (1 run)  - Sentence grammar judgment
%   ses-task05: saliencepain     (1 run)  - Salience/pain processing
%   ses-task06: balloonwatching  (1 run)  - Balloon watching (anticipation)
%   ses-task08: viseme           (3 runs) - Visual speech perception
%              visemegen         (1 run)  - Visual speech generation
%   ses-task10: visualrhythm     (1 run)  - Visual rhythm processing
%
% Data: BrainVision format, 188 SEEG + 2 EKG + 1 TRIG channels, 2048 Hz
% Electrodes: MNI152NLin2009cAsym coordinates available
%
% Usage:
%   >> run_EP01AN96M1047_all_tasks
%
% Requirements:
%   - EEGLAB on MATLAB path (for BrainVision loading)
%   - seegring pipeline (run startup.m first)

%% ========================================================================
%  Configuration
%  ========================================================================

% Paths
bids_root   = '/Volumes/OHDD/DATA/epilepsy';
subject     = 'EP01AN96M1047';
sub_dir     = fullfile(bids_root, ['sub-' subject]);
results_dir = fullfile(bids_root, 'derivatives', 'seegring', ['sub-' subject]);

% Add pipeline paths
code_root = fileparts(mfilename('fullpath'));
addpath(fullfile(code_root, 'code'));
add_paths();

% Verify EEGLAB + BrainVision plugin
if ~exist('pop_loadbv', 'file')
    if exist('eeglab', 'file')
        eeglab_path = fileparts(which('eeglab'));
        bva_dirs = dir(fullfile(eeglab_path, 'plugins', 'bva*'));
        if ~isempty(bva_dirs)
            bva_path = fullfile(eeglab_path, 'plugins', bva_dirs(1).name);
            addpath(bva_path);
            fprintf('Added bva-io plugin: %s\n', bva_path);
        else
            error(['BrainVision plugin (bva-io) not found.\n' ...
                   'Install it: eeglab > File > Manage Extensions > search "bva-io"']);
        end
    else
        error('EEGLAB not found on path. Add it first: addpath(genpath(''/path/to/eeglab''))');
    end
end

%% ========================================================================
%  Define all runs to process
%  ========================================================================

runs = define_all_runs();

fprintf('=== SEEG Batch Analysis: sub-%s ===\n', subject);
fprintf('Total runs to process: %d\n', numel(runs));
fprintf('Start: %s\n\n', datestr(now));

%% ========================================================================
%  Process each run
%  ========================================================================

all_results = struct();
batch_start = tic;

for r = 1:numel(runs)
    run_info = runs(r);
    run_id = sprintf('%s_%s_run-%s', run_info.session, run_info.task, run_info.run);

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('[%d/%d] %s (task: %s)\n', r, numel(runs), run_id, run_info.task);
    fprintf('%s\n', repmat('=', 1, 70));

    try
        summary = process_bids_run(bids_root, subject, run_info, results_dir);
        summary.run_id = run_id;
        summary.run_info = run_info;
        all_results.(matlab.lang.makeValidName(run_id)) = summary;
        fprintf('[%d/%d] SUCCESS: %s\n', r, numel(runs), run_id);
    catch ME
        fprintf('[%d/%d] FAILED: %s\n', r, numel(runs), run_id);
        fprintf('  Error: %s\n', ME.message);
        fprintf('  In: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        all_results.(matlab.lang.makeValidName(run_id)) = struct( ...
            'run_id', run_id, 'error', ME.message, 'success', false);
    end
end

%% ========================================================================
%  Cross-task summary
%  ========================================================================

elapsed = toc(batch_start);
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('=== Batch Complete ===\n');
fprintf('Total time: %.1f minutes\n', elapsed / 60);
fprintf('Results saved to: %s\n', results_dir);

% Save batch results
batch_file = fullfile(results_dir, sprintf('batch_results_%s.mat', ...
    datestr(now, 'yyyymmdd_HHMMSS')));
if ~isfolder(results_dir); mkdir(results_dir); end
save(batch_file, 'all_results', '-v7.3');
fprintf('Batch results: %s\n', batch_file);

% Print summary table
print_batch_summary(all_results, runs);

%% ========================================================================
%  Cross-Task Contrast Analysis (JSON-based)
%  ========================================================================

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('=== Cross-Task Contrast Analysis ===\n');
fprintf('=== Based on: %s/contrasts/ ===\n', sub_dir);

contrast_dir = fullfile(sub_dir, 'contrasts');
cross_contrasts = load_cross_task_contrasts(contrast_dir);

cross_results = struct([]);
if ~isempty(cross_contrasts)
    cross_cfg = default_config();
    cross_cfg.fs = 2048;
    cross_cfg.n_permutations = 500;
    cross_cfg.n_latent_dims = 6;

    cross_results = run_cross_task_analysis(cross_contrasts, results_dir, cross_cfg);

    % Save cross-task results
    cross_dir = fullfile(results_dir, 'cross_task');
    if ~isfolder(cross_dir); mkdir(cross_dir); end
    save(fullfile(cross_dir, 'cross_task_results.mat'), 'cross_results', 'cross_contrasts', '-v7.3');
    fprintf('\nCross-task results saved to: %s\n', cross_dir);
end

%% ========================================================================
%  Generate Reports with Condition Significance Emphasis
%  ========================================================================

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('=== Generating Publication Reports ===\n');

report_cfg = default_config();
report_cfg.fs = 2048;

% Print within-task significance summary
print_significance_summary(all_results, runs);

% Print cross-task significance summary
if ~isempty(cross_results)
    print_cross_task_significance(cross_results);
end

try
    generate_latex_report(all_results, runs, results_dir, report_cfg);
catch ME
    fprintf('[Report] LaTeX generation failed: %s\n', ME.message);
end

try
    generate_markdown_report(all_results, runs, results_dir, report_cfg);
catch ME
    fprintf('[Report] Markdown generation failed: %s\n', ME.message);
end

fprintf('\n=== Reports Complete ===\n');
fprintf('Output directory: %s\n', results_dir);


%% ========================================================================
%  Helper functions
%  ========================================================================

function runs = define_all_runs()
% Define all 11 runs to process

    runs = struct();
    idx = 0;

    idx = idx + 1;
    runs(idx).session = 'task01';
    runs(idx).task = 'lexicaldecision';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual word/nonword discrimination';

    idx = idx + 1;
    runs(idx).session = 'task02';
    runs(idx).task = 'shapecontrol';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Shape control task';

    idx = idx + 1;
    runs(idx).session = 'task03';
    runs(idx).task = 'sentencenoun';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Sentence noun comprehension';

    idx = idx + 1;
    runs(idx).session = 'task04';
    runs(idx).task = 'sentencegrammar';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Sentence grammar judgment';

    idx = idx + 1;
    runs(idx).session = 'task05';
    runs(idx).task = 'saliencepain';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Salience/pain processing';

    idx = idx + 1;
    runs(idx).session = 'task06';
    runs(idx).task = 'balloonwatching';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Balloon watching (anticipation)';

    idx = idx + 1;
    runs(idx).session = 'task08';
    runs(idx).task = 'viseme';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual speech perception run 1';

    idx = idx + 1;
    runs(idx).session = 'task08';
    runs(idx).task = 'viseme';
    runs(idx).run = '02';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual speech perception run 2';

    idx = idx + 1;
    runs(idx).session = 'task08';
    runs(idx).task = 'viseme';
    runs(idx).run = '03';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual speech perception run 3';

    idx = idx + 1;
    runs(idx).session = 'task08';
    runs(idx).task = 'visemegen';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual speech generation';

    idx = idx + 1;
    runs(idx).session = 'task10';
    runs(idx).task = 'visualrhythm';
    runs(idx).run = '02';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual rhythm processing';
end


% process_single_run is now in code/process_bids_run.m (shared function)


function stim_events = filter_events_by_type(events, event_type)
% Filter events to keep only the specified trial_type.
    if isempty(events)
        stim_events = struct([]);
        return;
    end
    mask = strcmp({events.condition}, event_type);
    stim_events = events(mask);
end


function events = enrich_event_conditions(stim_events, all_events, task_name)
% Enrich stimulus event conditions using behavioral data.
%
% For each stimulus event, find the matching trial in all_events and
% extract meaningful condition labels based on the task.

    events = stim_events;

    % Build lookup from all events by trial_number (if available)
    all_onsets = [all_events.onset];

    for i = 1:numel(events)
        % Find the full event entry for this stimulus
        onset = events(i).onset;
        [~, match_idx] = min(abs(all_onsets - onset));

        % Task-specific condition extraction
        switch lower(task_name)
            case 'lexicaldecision'
                % Condition = direction (left/right word vs nonword)
                events(i).condition = extract_field_safe(all_events(match_idx), 'direction', 'stimulus');

            case 'shapecontrol'
                events(i).condition = extract_field_safe(all_events(match_idx), 'trial_type', 'stimulus');

            case {'sentencenoun', 'sentencegrammar'}
                events(i).condition = extract_field_safe(all_events(match_idx), 'trial_type', 'stimulus');

            case 'saliencepain'
                % Pain vs noPain
                events(i).condition = extract_field_safe(all_events(match_idx), 'Pain', 'stimulus');

            case 'balloonwatching'
                % condition column (no pop, pop, etc.)
                events(i).condition = extract_field_safe(all_events(match_idx), 'condition', 'stimulus');

            case 'viseme'
                % viseme_category
                events(i).condition = extract_field_safe(all_events(match_idx), 'viseme_category', 'stimulus');

            case 'visemegen'
                events(i).condition = extract_field_safe(all_events(match_idx), 'stimulus_type', 'stimulus');

            case 'visualrhythm'
                events(i).condition = extract_field_safe(all_events(match_idx), 'condition_name', 'stimulus');

            otherwise
                events(i).condition = 'stimulus';
        end
    end
end


function val = extract_field_safe(event_struct, field_name, default_val)
% Safely extract a field value from an event struct.
    if isfield(event_struct, field_name)
        val = event_struct.(field_name);
        if iscell(val)
            val = val{1};
        elseif isnumeric(val)
            val = sprintf('%g', val);
        end
        if isempty(val) || strcmp(val, 'n/a')
            val = default_val;
        end
    else
        val = default_val;
    end
end


function cfg = build_task_config(run_info, fs)
% Build task-appropriate configuration.

    cfg = default_config();
    cfg.fs = fs;
    cfg.line_noise_freq = 60;  % Korea: 60 Hz

    % General defaults (before switch so task-specific cases can override)
    cfg.n_latent_dims = 6;
    cfg.latent_method = 'pca';
    cfg.smooth_kernel_ms = 20;
    cfg.n_bootstrap = 200;
    cfg.bootstrap_ci = 0.95;
    cfg.n_permutations = 500;
    cfg.fig_format = 'png';
    cfg.fig_dpi = 150;

    % Task-specific epoch windows
    switch lower(run_info.task)
        case {'lexicaldecision', 'shapecontrol', 'sentencenoun', 'sentencegrammar'}
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 2.0;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;

        case 'saliencepain'
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 3.0;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;

        case 'balloonwatching'
            cfg.epoch_pre = 1.0;
            cfg.epoch_post = 16.0;
            cfg.baseline_start = -1.0;
            cfg.baseline_end = 0.0;
            cfg.n_cv_folds = 3;
            cfg.n_bootstrap = 100;

        case {'viseme', 'visemegen'}
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 2.5;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;

        case 'visualrhythm'
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 8.5;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;

        otherwise
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 1.5;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;
    end
end


function roi_groups = build_roi_groups_from_channels(channels, good_idx)
% Build ROI groups using the group column from channels.tsv.

    if ~isfield(channels, 'group')
        % Fallback: infer from channel names
        elec.label = channels.name(good_idx);
        roi_groups = build_roi_groups(elec, 'shaft');
        return;
    end

    groups = channels.group(good_idx);
    names = channels.name(good_idx);
    unique_groups = unique(groups, 'stable');

    roi_groups = struct();
    for g = 1:numel(unique_groups)
        mask = strcmp(groups, unique_groups{g});
        roi_groups(g).name = unique_groups{g};
        roi_groups(g).indices = find(mask)';
        roi_groups(g).labels = names(mask);
        roi_groups(g).n_channels = sum(mask);
    end

    fprintf('[ROI] %d groups from channels.tsv group column\n', numel(roi_groups));
end



function print_batch_summary(all_results, runs)
% Print a summary table of all processed runs.

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('%-12s %-20s %-6s %-6s %-8s %-10s\n', ...
        'Session', 'Task', 'Run', 'Status', 'Trials', 'Conditions');
    fprintf('%s\n', repmat('-', 1, 70));

    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);

        if isfield(all_results, field)
            res = all_results.(field);
            if isfield(res, 'success') && res.success
                n_trials = res.n_trials;
                n_conds = numel(res.conditions);
                fprintf('%-12s %-20s %-6s %-6s %-8d %-10d\n', ...
                    runs(r).session, runs(r).task, runs(r).run, 'OK', n_trials, n_conds);
            else
                fprintf('%-12s %-20s %-6s %-6s\n', ...
                    runs(r).session, runs(r).task, runs(r).run, 'FAIL');
            end
        else
            fprintf('%-12s %-20s %-6s %-6s\n', ...
                runs(r).session, runs(r).task, runs(r).run, 'SKIP');
        end
    end
    fprintf('%s\n', repmat('=', 1, 70));
end


function print_significance_summary(all_results, runs)
% Print condition-dependent significance summary across all tasks.

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('  CONDITION-DEPENDENT SIGNIFICANCE SUMMARY\n');
    fprintf('%s\n', repmat('=', 1, 70));

    n_sig = 0;
    n_total = 0;
    best_task = '';
    best_sep = 0;

    fprintf('%-20s %-10s %-10s %-12s %-10s %-8s %-10s %-8s\n', ...
        'Task', 'PeakSep', 'p_min', 'Significant', 'PeakAcc', 'Onset', 'Contrasts', 'TFClust');
    fprintf('%s\n', repmat('-', 1, 88));

    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);
        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if ~isfield(res, 'success') || ~res.success; continue; end
        n_total = n_total + 1;

        peak_sep = NaN;
        min_p = NaN;
        is_sig = false;
        peak_acc_str = '--';
        onset_str = '--';
        n_contrasts_str = '--';
        n_sig_contrasts = 0;
        sig_ch_str = '';

        % Load actual stage results from disk
        run_results_dir = fullfile(res.run_output, 'results');

        % Stage 12: geometry (condition separation)
        % Stage 12 saves: separation.index, separation.p_values
        geom_file = fullfile(run_results_dir, 'stage12_geometry.mat');
        if isfile(geom_file)
            s12 = load(geom_file);
            if isfield(s12, 'separation') && isstruct(s12.separation)
                if isfield(s12.separation, 'index')
                    peak_sep = max(s12.separation.index);
                end
                if isfield(s12.separation, 'p_values')
                    min_p = min(s12.separation.p_values);
                    is_sig = min_p < 0.05;
                    if is_sig; n_sig = n_sig + 1; end
                    if peak_sep > best_sep
                        best_sep = peak_sep;
                        best_task = runs(r).task;
                    end
                end
            end
        end

        % Stage 14: decoding
        % Stage 14 saves: decoding.accuracy_time, decoding.onset_time
        dec_file = fullfile(run_results_dir, 'stage14_decoding.mat');
        if isfile(dec_file)
            s14 = load(dec_file);
            if isfield(s14, 'decoding') && isstruct(s14.decoding)
                dec = s14.decoding;
            else
                dec = s14;
            end
            if isfield(dec, 'accuracy_time')
                peak_acc_str = sprintf('%.1f%%', max(dec.accuracy_time) * 100);
            end
            if isfield(dec, 'onset_time') && ~isnan(dec.onset_time)
                onset_str = sprintf('%.0fms', dec.onset_time * 1000);
            end
        end

        % Stage 14b: contrasts (sig count + channel names)
        con_file = fullfile(run_results_dir, 'stage14b_contrasts.mat');
        if isfile(con_file)
            s14b = load(con_file);
            if isfield(s14b, 'contrast_results')
                cr_list = s14b.contrast_results;
                n_con = numel(cr_list);
                for ci = 1:n_con
                    if isfield(cr_list(ci), 'significant') && cr_list(ci).significant
                        n_sig_contrasts = n_sig_contrasts + 1;
                    end
                end
                n_contrasts_str = sprintf('%d/%d', n_sig_contrasts, n_con);
            end
        end

        % Stage 9b: TF multivariate stats
        tf_clust_str = '--';
        tf_file = fullfile(run_results_dir, 'stage09b_tf_stats.mat');
        if isfile(tf_file)
            s9b = load(tf_file, 'tf_stats');
            if isfield(s9b, 'tf_stats') && isfield(s9b.tf_stats, 'n_sig_clusters_total')
                tf_clust_str = sprintf('%d', s9b.tf_stats.n_sig_clusters_total);
            end
        end

        if is_sig
            sig_str = '*** YES ***';
        else
            sig_str = 'no';
        end

        fprintf('%-20s %-10.2f %-10.4f %-12s %-10s %-8s %-10s %-8s\n', ...
            runs(r).task, peak_sep, min_p, sig_str, peak_acc_str, onset_str, n_contrasts_str, tf_clust_str);
    end

    fprintf('%s\n', repmat('=', 1, 80));
    fprintf('  %d / %d tasks show significant condition separation\n', n_sig, n_total);
    if ~isempty(best_task)
        fprintf('  Strongest condition separation: %s (peak = %.2f)\n', best_task, best_sep);
    end
    fprintf('%s\n', repmat('=', 1, 80));

    % Detailed within-task contrast report with channel names
    fprintf('\n%s\n', repmat('=', 1, 80));
    fprintf('  WITHIN-TASK CONTRAST DETAILS (with significant channels)\n');
    fprintf('%s\n', repmat('=', 1, 80));

    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);
        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if ~isfield(res, 'success') || ~res.success; continue; end

        run_results_dir = fullfile(res.run_output, 'results');
        con_file = fullfile(run_results_dir, 'stage14b_contrasts.mat');
        if ~isfile(con_file); continue; end

        s14b = load(con_file);
        if ~isfield(s14b, 'contrast_results') || isempty(s14b.contrast_results); continue; end

        % Load channel labels
        ch_labels = {};
        bids_file = fullfile(run_results_dir, 'stage01_bids.mat');
        if isfile(bids_file)
            s1_tmp = load(bids_file, 'channel_labels');
            if isfield(s1_tmp, 'channel_labels')
                ch_labels = s1_tmp.channel_labels;
            end
        end

        cr_list = s14b.contrast_results;
        has_sig = any([cr_list.significant]);
        if ~has_sig; continue; end

        fprintf('\n--- %s (%s) ---\n', runs(r).task, runs(r).run);
        for ci = 1:numel(cr_list)
            cr = cr_list(ci);
            if ~cr.significant; continue; end

            fprintf('  [%s] p_min=%.4f', cr.contrast.name, cr.p_min);

            % Find significant channels from permutation p-values
            if isfield(cr, 'permutation') && isfield(cr.permutation, 'p_values')
                p_ch = cr.permutation.p_values;  % n_ch x n_t
                sig_ch_mask = any(p_ch < 0.05, 2);
                n_sig_ch = sum(sig_ch_mask);
                if n_sig_ch > 0 && ~isempty(ch_labels) && numel(ch_labels) == size(p_ch, 1)
                    sig_names = ch_labels(sig_ch_mask);
                    fprintf(' | %d sig channels: %s', n_sig_ch, strjoin(sig_names, ', '));
                elseif n_sig_ch > 0
                    fprintf(' | %d sig channels', n_sig_ch);
                end
            end
            fprintf('\n');
        end
    end

    % TF multivariate stats detail section
    fprintf('\n%s\n', repmat('=', 1, 80));
    fprintf('  TIME-FREQUENCY CLUSTER & MULTIVARIATE ANALYSIS\n');
    fprintf('%s\n', repmat('=', 1, 80));

    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);
        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if ~isfield(res, 'success') || ~res.success; continue; end

        run_results_dir = fullfile(res.run_output, 'results');
        tf_file = fullfile(run_results_dir, 'stage09b_tf_stats.mat');
        if ~isfile(tf_file); continue; end

        s9b = load(tf_file, 'tf_stats');
        if ~isfield(s9b, 'tf_stats'); continue; end
        tfs = s9b.tf_stats;

        fprintf('\n--- %s (%s) ---\n', runs(r).task, runs(r).run);

        % Adaptive peaks
        if isfield(tfs, 'adaptive_peaks') && isfield(tfs.adaptive_peaks, 'bands')
            peaks = tfs.adaptive_peaks;
            band_names = fieldnames(peaks.bands);
            for bi = 1:numel(band_names)
                b = peaks.bands.(band_names{bi});
                fprintf('  [Peak] %s: %.1f Hz (adaptive [%.1f-%.1f] Hz)\n', ...
                    band_names{bi}, b.global_peak_freq, b.adaptive_range(1), b.adaptive_range(2));
            end
        end

        % TF clusters
        if isfield(tfs, 'cluster_contrasts') && ~isempty(tfs.cluster_contrasts)
            for ci = 1:numel(tfs.cluster_contrasts)
                cc = tfs.cluster_contrasts(ci);
                if cc.n_sig_clusters > 0
                    fprintf('  [TF-Cluster] %s vs %s: %d sig cluster(s)\n', ...
                        cc.cond_A, cc.cond_B, cc.n_sig_clusters);
                    if isfield(cc, 'cluster_bands')
                        for bi = 1:numel(cc.cluster_bands)
                            b = cc.cluster_bands(bi);
                            fprintf('    %.0f-%.0f Hz, idx %d-%d\n', ...
                                b.freq_range(1), b.freq_range(2), b.time_idx(1), b.time_idx(2));
                        end
                    end
                end
            end
        end

        % Band contrasts
        if isfield(tfs, 'band_contrasts') && ~isempty(tfs.band_contrasts)
            for ci = 1:numel(tfs.band_contrasts)
                bc = tfs.band_contrasts(ci);
                if ~bc.any_significant; continue; end
                band_names = fieldnames(bc.band_results);
                for bi = 1:numel(band_names)
                    br = bc.band_results.(band_names{bi});
                    if br.significant
                        fprintf('  [Band] %s vs %s, %s: sig (%d ch)\n', ...
                            bc.cond_A, bc.cond_B, band_names{bi}, br.n_sig_channels);
                    end
                end
            end
        end

        % MVPA
        if isfield(tfs, 'mvpa') && isstruct(tfs.mvpa) && isfield(tfs.mvpa, 'peak_accuracy')
            fprintf('  [MVPA-TF] Peak %.1f%% (p=%.4f), %d features\n', ...
                tfs.mvpa.peak_accuracy * 100, tfs.mvpa.p_peak, tfs.mvpa.n_features);
            if isfield(tfs.mvpa, 'accuracy_per_band')
                band_names = fieldnames(tfs.mvpa.accuracy_per_band);
                for bi = 1:numel(band_names)
                    acc = tfs.mvpa.accuracy_per_band.(band_names{bi});
                    if ~isempty(acc)
                        fprintf('    %s: peak %.1f%%\n', band_names{bi}, max(acc) * 100);
                    end
                end
            end
        end

        % PAC
        if isfield(tfs, 'pac') && isfield(tfs.pac, 'contrast') && ~isempty(tfs.pac.contrast)
            for ci = 1:numel(tfs.pac.contrast)
                pc = tfs.pac.contrast(ci);
                fprintf('  [PAC] %s vs %s: max MI diff = %.4f\n', ...
                    pc.cond_A, pc.cond_B, pc.max_diff);
            end
        end
    end
end


function print_cross_task_significance(cross_results)
% Print cross-task contrast significance report.

    fprintf('\n%s\n', repmat('=', 1, 80));
    fprintf('  CROSS-TASK CONTRAST SIGNIFICANCE REPORT\n');
    fprintf('  (Based on contrast JSON definitions)\n');
    fprintf('%s\n', repmat('=', 1, 80));

    fprintf('%-35s %-8s %-8s %-10s %-8s %-10s\n', ...
        'Contrast', 'p_min', 'Sig?', 'Cohen''s d', 'Trials', 'LatentSep');
    fprintf('%s\n', repmat('-', 1, 80));

    n_sig = 0;
    for ci = 1:numel(cross_results)
        cr = cross_results(ci);

        sig_str = 'no';
        if cr.significant
            sig_str = '*** YES ***';
            n_sig = n_sig + 1;
        end

        p_str = '--';
        if ~isnan(cr.p_global)
            p_str = sprintf('%.4f', cr.p_global);
        end

        d_str = '--';
        if ~isnan(cr.mean_d)
            d_str = sprintf('%.2f', cr.mean_d);
        end

        trial_str = sprintf('%d/%d', cr.n_trials_A, cr.n_trials_B);

        lat_str = '--';
        if isfield(cr, 'latent') && isfield(cr.latent, 'peak_separation')
            lat_str = sprintf('%.2f', cr.latent.peak_separation);
        end

        fprintf('%-35s %-8s %-8s %-10s %-8s %-10s\n', ...
            cr.name, p_str, sig_str, d_str, trial_str, lat_str);

        % Print significant time windows
        if cr.significant && ~isempty(cr.sig_windows)
            win_strs = {};
            for wi = 1:numel(cr.sig_windows)
                w = cr.sig_windows{wi};
                win_strs{end+1} = sprintf('%.0f-%.0fms', w(1), w(2));
            end
            fprintf('  -> Sig windows: %s\n', strjoin(win_strs, ', '));
        end

        % Print latent space significance
        if isfield(cr, 'latent') && isfield(cr.latent, 'p_peak') && cr.latent.p_peak < 0.05
            fprintf('  -> Latent separation: p=%.4f (peak=%.2f)\n', ...
                cr.latent.p_peak, cr.latent.peak_separation);
        end

        % Print expected effect for context
        if ~isempty(cr.expected_effect) && cr.significant
            fprintf('  -> Expected: %s\n', cr.expected_effect);
        end

        % Print significant channel names
        if cr.n_sig_channels > 0
            fprintf('  -> %d sig channels: %s\n', cr.n_sig_channels, ...
                strjoin(cr.sig_channel_names(1:min(20, cr.n_sig_channels)), ', '));
            if cr.n_sig_channels > 20
                fprintf('    ... and %d more\n', cr.n_sig_channels - 20);
            end
        end
    end

    fprintf('%s\n', repmat('=', 1, 80));
    fprintf('  %d / %d cross-task contrasts significant (p < 0.05)\n', ...
        n_sig, numel(cross_results));
    fprintf('%s\n', repmat('=', 1, 80));

    % Detailed report for significant contrasts
    if n_sig > 0
        fprintf('\n%s\n', repmat('=', 1, 80));
        fprintf('  SIGNIFICANT CROSS-TASK CONTRASTS — DETAILS\n');
        fprintf('%s\n', repmat('=', 1, 80));

        for ci = 1:numel(cross_results)
            cr = cross_results(ci);
            if ~cr.significant; continue; end

            fprintf('\n--- %s ---\n', cr.name);
            fprintf('  %s vs %s\n', cr.task_A_name, cr.task_B_name);
            fprintf('  %s\n', cr.description);
            fprintf('  Trials: %d vs %d\n', cr.n_trials_A, cr.n_trials_B);
            fprintf('  Global p: %.4f\n', cr.p_global);
            fprintf('  Mean |Cohen''s d|: %.2f\n', cr.mean_d);

            if ~isempty(cr.sig_windows)
                fprintf('  Significant time windows:\n');
                for wi = 1:numel(cr.sig_windows)
                    w = cr.sig_windows{wi};
                    fprintf('    %.0f — %.0f ms\n', w(1), w(2));
                end
            end

            if isfield(cr, 'latent') && isstruct(cr.latent)
                lat = cr.latent;
                fprintf('  Latent space:\n');
                fprintf('    Variance explained (PC1-3): %.1f%%, %.1f%%, %.1f%%\n', ...
                    lat.explained_variance(1)*100, lat.explained_variance(2)*100, ...
                    lat.explained_variance(3)*100);
                fprintf('    Peak separation: %.2f (p=%.4f)\n', ...
                    lat.peak_separation, lat.p_peak);
            end

            fprintf('  Sig channels (%d): %s\n', cr.n_sig_channels, ...
                strjoin(cr.sig_channel_names, ', '));

            if ~isempty(cr.expected_effect)
                fprintf('  Expected neural effect: %s\n', cr.expected_effect);
            end
        end
    end
end
