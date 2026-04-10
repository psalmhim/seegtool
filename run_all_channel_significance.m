%% RUN_ALL_CHANNEL_SIGNIFICANCE - Channel significance across all tasks
%
% For each task: re-runs stage 11 (PCA 10 dims), stage 9 (channel x time
% significance with 1000 perms), stage 14 (decoding + channel importance).
% Generates per-task figures and a cross-task summary.

%% Setup
code_root = fileparts(mfilename('fullpath'));
addpath(fullfile(code_root, 'code'));
add_paths();

base_dir = '/Volumes/OHDD/DATA/epilepsy/derivatives/seegring/sub-EP01AN96M1047';

% Find tasks with required stage files
task_dirs = dir(fullfile(base_dir, 'task-*'));
valid_tasks = {};
for i = 1:numel(task_dirs)
    rd = fullfile(base_dir, task_dirs(i).name, 'results');
    if isfile(fullfile(rd, 'stage04_epochs.mat')) && isfile(fullfile(rd, 'stage05_qc.mat'))
        s5 = load(fullfile(rd, 'stage05_qc.mat'), 'condition_labels');
        n_conds = numel(unique(s5.condition_labels));
        if n_conds >= 2
            valid_tasks{end+1} = task_dirs(i).name;
        end
    end
end

fprintf('=== Channel Significance: %d Tasks ===\n', numel(valid_tasks));
fprintf('Start: %s\n\n', datestr(now));

% Collect cross-task results
all_results = struct([]);
total_time = 0;

for ti = 1:numel(valid_tasks)
    task_name = valid_tasks{ti};
    results_base = fullfile(base_dir, task_name);
    results_dir = fullfile(results_base, 'results');

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('TASK %d/%d: %s\n', ti, numel(valid_tasks), task_name);
    fprintf('%s\n', repmat('=', 1, 70));

    try
        task_result = run_single_task_significance(results_base, results_dir);
        total_time = total_time + task_result.elapsed;

        % Store for cross-task summary
        all_results(end+1).task = task_name;
        all_results(end).n_trials = task_result.n_trials;
        all_results(end).n_channels = task_result.n_channels;
        all_results(end).conditions = task_result.conditions;
        all_results(end).n_cluster_sig = task_result.n_cluster_sig;
        all_results(end).n_roi_sig = task_result.n_roi_sig;
        all_results(end).peak_accuracy = task_result.peak_accuracy;
        all_results(end).top_channels = task_result.top_channels;
        all_results(end).top_weights = task_result.top_weights;
        all_results(end).top_perm_imp = task_result.top_perm_imp;
        all_results(end).variance_explained = task_result.variance_explained;
    catch ME
        fprintf('[ERROR] %s: %s\n', task_name, ME.message);
        all_results(end+1).task = task_name;
        all_results(end).n_cluster_sig = -1;
    end
end

%% Cross-task summary
fprintf('\n\n%s\n', repmat('=', 1, 80));
fprintf('CROSS-TASK CHANNEL SIGNIFICANCE SUMMARY\n');
fprintf('%s\n\n', repmat('=', 1, 80));

fprintf('%-35s %5s %5s %6s %6s %6s  Top Channels (by decoding weight)\n', ...
    'Task', 'Trial', 'Cond', 'ClSig', 'FDR', 'Acc%');
fprintf('%s\n', repmat('-', 1, 120));

for i = 1:numel(all_results)
    r = all_results(i);
    if r.n_cluster_sig < 0
        fprintf('%-35s  ERROR\n', r.task);
        continue;
    end
    n_conds = numel(r.conditions);
    top_str = '';
    n_show = min(5, numel(r.top_channels));
    for j = 1:n_show
        top_str = [top_str, sprintf('%s(%.3f) ', r.top_channels{j}, r.top_weights(j))];
    end
    fprintf('%-35s %5d %5d %6d %6d %5.1f%%  %s\n', ...
        r.task, r.n_trials, n_conds, r.n_cluster_sig, r.n_roi_sig, ...
        r.peak_accuracy * 100, top_str);
end

%% Channel frequency across tasks
fprintf('\n--- Channel frequency in top-20 across tasks ---\n');
ch_counts = containers.Map();
for i = 1:numel(all_results)
    r = all_results(i);
    if r.n_cluster_sig < 0; continue; end
    for j = 1:numel(r.top_channels)
        ch = r.top_channels{j};
        if ch_counts.isKey(ch)
            ch_counts(ch) = ch_counts(ch) + 1;
        else
            ch_counts(ch) = 1;
        end
    end
end

ch_names = ch_counts.keys();
ch_freqs = cellfun(@(k) ch_counts(k), ch_names);
[ch_freqs_sorted, si] = sort(ch_freqs, 'descend');
n_show = min(30, numel(si));
fprintf('\n%-15s %s\n', 'Channel', 'Tasks in top-20');
for i = 1:n_show
    if ch_freqs_sorted(i) < 2; break; end
    fprintf('%-15s %d/%d tasks\n', ch_names{si(i)}, ch_freqs_sorted(i), numel(valid_tasks));
end

fprintf('\n%s\n', repmat('=', 1, 80));
fprintf('Total time: %.1f minutes across %d tasks\n', total_time / 60, numel(valid_tasks));
fprintf('%s\n', repmat('=', 1, 80));

% Save cross-task results
save(fullfile(base_dir, 'channel_significance_summary.mat'), 'all_results');
fprintf('Summary saved to: %s\n', fullfile(base_dir, 'channel_significance_summary.mat'));

% Cleanup
delete(fullfile(code_root, 'check_tasks.m'));


function result = run_single_task_significance(results_base, results_dir)
% Run channel significance for a single task.

    tic_total = tic;

    % Load stage files
    s1 = load(fullfile(results_dir, 'stage01_bids.mat'));
    s2 = load(fullfile(results_dir, 'stage02_config.mat'));
    s4 = load(fullfile(results_dir, 'stage04_epochs.mat'));
    s5 = load(fullfile(results_dir, 'stage05_qc.mat'));

    cfg = s2.cfg;
    cfg.n_permutations = 1000;
    cfg.n_latent_dims = 10;
    cfg.smooth_kernel_ms = 10;
    cfg.channel_sig_top_n = 20;

    % Ensure required fields
    if ~isfield(cfg, 'baseline_start'); cfg.baseline_start = -0.5; end
    if ~isfield(cfg, 'baseline_end'); cfg.baseline_end = 0; end
    if ~isfield(cfg, 'cluster_threshold'); cfg.cluster_threshold = 2.0; end
    if ~isfield(cfg, 'alpha_level'); cfg.alpha_level = 0.05; end
    if ~isfield(cfg, 'decode_method'); cfg.decode_method = 'lda'; end
    if ~isfield(cfg, 'n_cv_folds'); cfg.n_cv_folds = 5; end

    % Channel labels
    if isfile(fullfile(results_dir, 'stage03_preproc.mat'))
        s3 = load(fullfile(results_dir, 'stage03_preproc.mat'));
        if isfield(s3, 'channel_labels') && ~isempty(s3.channel_labels)
            channel_labels = s3.channel_labels;
        else
            channel_labels = s1.channel_labels;
        end
    else
        channel_labels = s1.channel_labels;
    end

    conditions = unique(s5.condition_labels);
    fprintf('  %d trials, %d ch, %d conds (%s)\n', ...
        s4.n_trials, s4.n_channels, numel(conditions), strjoin(conditions, ', '));

    % Stage 11: PCA (10 dims)
    fprintf('  [Stage 11] Latent dynamics...\n');
    pop_tensor = build_population_tensor(s4.trial_tensor, 'voltage');
    pop_tensor = normalize_population_tensor(pop_tensor, 'zscore');
    model = fit_latent_model(pop_tensor, cfg);
    latent_tensor = project_to_latent_space(pop_tensor, model);

    % Get fs from config or stage files
    fs = cfg.fs;
    if isfield(s1, 'fs'); fs = s1.fs; end
    latent_tensor = smooth_latent_trajectories(latent_tensor, cfg.smooth_kernel_ms, fs);
    clear pop_tensor;

    fprintf('  [Stage 11] %.1f%% variance in %d dims\n', sum(model.explained_variance)*100, cfg.n_latent_dims);
    save(fullfile(results_dir, 'stage11_latent.mat'), 'latent_tensor', 'model', '-v7.3');

    % Stage 9: Permutation statistics + channel x time
    fprintf('  [Stage 9] Permutation statistics (1000 perms)...\n');
    stats_results = run_permutation_statistics(s4.trial_tensor, s5.condition_labels, s4.time_vec, cfg);
    save(fullfile(results_dir, 'stage09_stats.mat'), 'stats_results', '-v7.3');

    % Stage 14: Decoding + channel importance
    fprintf('  [Stage 14] Neural decoding + channel importance...\n');
    pca_model = model;
    decoding = run_neural_decoding(latent_tensor, s5.condition_labels, s4.time_vec, cfg, pca_model, pop_tensor);
    save(fullfile(results_dir, 'stage14_decoding.mat'), 'decoding', '-v7.3');

    % Generate figure
    try
        s = nature_style();
        fig = plot_channel_significance(stats_results, decoding, s4.time_vec, ...
            'channel_labels', channel_labels, 'top_n', 20, ...
            'title', sprintf('Channel Significance - %s', s1.task), 'style', s);
        fig_dir = fullfile(results_base, 'figures');
        png_dir = fullfile(fig_dir, 'png');
        pdf_dir = fullfile(fig_dir, 'pdf');
        if ~isfolder(png_dir); mkdir(png_dir); end
        if ~isfolder(pdf_dir); mkdir(pdf_dir); end
        export_figure(fig, fullfile(png_dir, 'channel_significance'), s, 'width', 'double', 'formats', {'png'});
        export_figure(fig, fullfile(pdf_dir, 'channel_significance'), s, 'width', 'double');
        close(fig);
    catch ME
        fprintf('  [WARN] Figure failed: %s\n', ME.message);
    end

    % Print per-task results
    n_cluster_sig = sum(any(stats_results.ch_time_sig, 2));
    n_roi_sig = sum(stats_results.roi_significant);

    fprintf('  ROI FDR significant: %d channels\n', n_roi_sig);
    fprintf('  Cluster-corrected: %d channels\n', n_cluster_sig);
    fprintf('  Peak decoding: %.1f%%\n', max(decoding.accuracy_time) * 100);

    % Top channels
    if isfield(decoding, 'channel_top')
        top_idx = decoding.channel_top;
        n_show = min(10, numel(top_idx));
        fprintf('  Top %d decoding channels:\n', n_show);
        for j = 1:n_show
            ch = top_idx(j);
            fprintf('    %2d. %-12s w=%.4f imp=%.3f\n', j, channel_labels{ch}, ...
                decoding.channel_mean_weight(ch), decoding.channel_perm_importance(ch));
        end
    end

    % Collect result
    result = struct();
    result.n_trials = s4.n_trials;
    result.n_channels = s4.n_channels;
    result.conditions = conditions;
    result.n_cluster_sig = n_cluster_sig;
    result.n_roi_sig = n_roi_sig;
    result.peak_accuracy = max(decoding.accuracy_time);
    result.variance_explained = sum(model.explained_variance);

    if isfield(decoding, 'channel_top')
        n_top = min(20, numel(decoding.channel_top));
        result.top_channels = channel_labels(decoding.channel_top(1:n_top));
        result.top_weights = decoding.channel_mean_weight(decoding.channel_top(1:n_top));
        result.top_perm_imp = decoding.channel_perm_importance(decoding.channel_top(1:n_top));
    else
        result.top_channels = {};
        result.top_weights = [];
        result.top_perm_imp = [];
    end

    result.elapsed = toc(tic_total);
    fprintf('  Done in %.1f s\n', result.elapsed);
end
