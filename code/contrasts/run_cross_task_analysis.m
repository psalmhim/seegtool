function results = run_cross_task_analysis(cross_contrasts, results_dir, cfg)
% RUN_CROSS_TASK_ANALYSIS Compare neural responses between tasks.
%
%   results = run_cross_task_analysis(cross_contrasts, results_dir, cfg)
%
%   For each cross-task contrast, loads trial data from both tasks,
%   aligns time vectors, and runs permutation-based comparison.
%
%   Inputs:
%       cross_contrasts - struct array from load_cross_task_contrasts
%       results_dir     - base results directory (contains task-*_run-*/)
%       cfg             - pipeline configuration
%
%   Output:
%       results - struct array with per-contrast analysis results

    if isempty(cross_contrasts)
        results = struct([]);
        return;
    end

    n_contrasts = numel(cross_contrasts);
    results = struct([]);

    for ci = 1:n_contrasts
        cc = cross_contrasts(ci);
        fprintf('\n[CrossTask %d/%d] %s\n', ci, n_contrasts, cc.name);
        fprintf('  %s vs %s\n', cc.task_A.task, cc.task_B.task);

        try
            r = analyze_single_cross_contrast(cc, results_dir, cfg);
            r.name = cc.name;
            r.description = cc.description;
            r.task_A_name = cc.task_A.task;
            r.task_B_name = cc.task_B.task;
            r.expected_effect = cc.expected_effect;
        catch ME
            fprintf('  FAILED: %s\n', ME.message);
            r = make_empty_result(cc);
        end

        if isempty(results)
            results = r;
        else
            results(end+1) = r;
        end
    end

    % Summary
    if ~isempty(results)
        n_sig = sum([results.significant]);
        fprintf('\n[CrossTask] %d/%d cross-task contrasts significant (p < 0.05)\n', ...
            n_sig, numel(results));
    end
end


function r = analyze_single_cross_contrast(cc, results_dir, cfg)
% Run analysis for a single cross-task contrast.

    % Load data for both tasks
    [tensor_A, time_A, weights_A, ~, ch_labels_A] = load_task_data(cc.task_A, results_dir);
    [tensor_B, time_B, weights_B, ~, ch_labels_B] = load_task_data(cc.task_B, results_dir);

    fprintf('  Task A (%s): %d trials x %d ch\n', cc.task_A.task, size(tensor_A, 1), size(tensor_A, 2));
    fprintf('  Task B (%s): %d trials x %d ch\n', cc.task_B.task, size(tensor_B, 1), size(tensor_B, 2));

    % Match channels (same implant — use minimum if mismatch from bad-channel rejection)
    n_ch_A = size(tensor_A, 2);
    n_ch_B = size(tensor_B, 2);
    n_ch = min(n_ch_A, n_ch_B);
    if n_ch_A ~= n_ch_B
        fprintf('  WARNING: Channel mismatch (%d vs %d), using first %d\n', n_ch_A, n_ch_B, n_ch);
        tensor_A = tensor_A(:, 1:n_ch, :);
        tensor_B = tensor_B(:, 1:n_ch, :);
    end

    % Align time vectors
    [tensor_A, tensor_B, common_time] = align_task_data(tensor_A, time_A, tensor_B, time_B);

    % Exclude bad trials (weight = 0)
    good_A = weights_A > 0;
    good_B = weights_B > 0;
    tensor_A = tensor_A(good_A, :, :);
    tensor_B = tensor_B(good_B, :, :);

    n_A = size(tensor_A, 1);
    n_B = size(tensor_B, 1);
    n_time = numel(common_time);
    fprintf('  After QC: %d vs %d trials\n', n_A, n_B);

    % Combine into single tensor with task labels
    combined = cat(1, tensor_A, tensor_B);
    n_total = n_A + n_B;
    task_labels = [repmat({'taskA'}, n_A, 1); repmat({'taskB'}, n_B, 1)];

    % 1) ERP-level comparison: mean difference per channel over time
    erp_A = reshape(mean(tensor_A, 1, 'omitnan'), n_ch, []);
    erp_B = reshape(mean(tensor_B, 1, 'omitnan'), n_ch, []);
    erp_diff = erp_A - erp_B;

    % 2) Permutation test on channel-averaged response
    mean_A = reshape(mean(tensor_A, [1 2], 'omitnan'), [], 1);
    mean_B = reshape(mean(tensor_B, [1 2], 'omitnan'), [], 1);
    observed_diff = mean_A - mean_B;

    n_perm = 500;
    if isfield(cfg, 'n_permutations')
        n_perm = cfg.n_permutations;
    end

    perm_diffs = zeros(n_perm, n_time);

    % Channel-averaged data for permutation: (nA+nB) x time
    ch_avg = reshape(mean(combined, 2, 'omitnan'), n_total, []);

    for pi = 1:n_perm
        perm_idx = randperm(n_total);
        perm_A = mean(ch_avg(perm_idx(1:n_A), :), 1, 'omitnan');
        perm_B = mean(ch_avg(perm_idx(n_A+1:end), :), 1, 'omitnan');
        perm_diffs(pi, :) = perm_A - perm_B;
    end

    % Two-tailed p-values
    p_values = zeros(1, n_time);
    for ti = 1:n_time
        p_values(ti) = mean(abs(perm_diffs(:, ti)) >= abs(observed_diff(ti)));
    end
    p_values = max(p_values, 1 / n_perm);

    % 3) Effect size (Cohen's d per timepoint, channel-averaged)
    % trial-averaged per trial: nA x time and nB x time
    trial_avg_A = reshape(mean(tensor_A, 2, 'omitnan'), n_A, []);
    trial_avg_B = reshape(mean(tensor_B, 2, 'omitnan'), n_B, []);
    std_A = std(trial_avg_A, 0, 1, 'omitnan');
    std_B = std(trial_avg_B, 0, 1, 'omitnan');
    pooled_std = sqrt((std_A.^2 * (n_A - 1) + std_B.^2 * (n_B - 1)) / (n_A + n_B - 2));
    pooled_std(pooled_std < eps) = eps;
    cohens_d = observed_diff(:)' ./ pooled_std;

    % 4) Per-channel permutation (for spatial maps)
    n_ch_perm = min(n_perm, 200);
    p_channel = zeros(n_ch, n_time);
    for ch = 1:n_ch
        ch_A = reshape(tensor_A(:, ch, :), n_A, []);
        ch_B = reshape(tensor_B(:, ch, :), n_B, []);
        obs_ch = mean(ch_A, 1, 'omitnan') - mean(ch_B, 1, 'omitnan');
        ch_combined = [ch_A; ch_B];

        null_ch = zeros(n_ch_perm, n_time);
        for pi = 1:n_ch_perm
            pidx = randperm(n_total);
            null_ch(pi, :) = mean(ch_combined(pidx(1:n_A), :), 1, 'omitnan') - ...
                             mean(ch_combined(pidx(n_A+1:end), :), 1, 'omitnan');
        end

        for ti = 1:n_time
            p_channel(ch, ti) = mean(abs(null_ch(:, ti)) >= abs(obs_ch(ti)));
        end
    end
    p_channel = max(p_channel, 1 / n_ch_perm);

    % 5) Latent space analysis (PCA on combined data)
    latent_result = run_latent_cross_task(combined, task_labels, n_A, cfg);

    % 6) Find significant time windows
    sig_mask = p_values < 0.05;
    sig_windows = find_sig_windows(sig_mask, common_time);

    % 7) Global significance (max-statistic correction)
    max_null = max(abs(perm_diffs), [], 2);
    max_obs = max(abs(observed_diff));
    p_global = mean(max_null >= max_obs);
    p_global = max(p_global, 1 / n_perm);
    is_significant = p_global < 0.05;

    % Significant channels (any timepoint p < 0.05)
    sig_ch_mask = any(p_channel < 0.05, 2);
    n_sig_channels = sum(sig_ch_mask);

    % Resolve channel labels
    if ~isempty(ch_labels_A)
        ch_labels = ch_labels_A(1:n_ch);
    elseif ~isempty(ch_labels_B)
        ch_labels = ch_labels_B(1:n_ch);
    else
        ch_labels = arrayfun(@(x) sprintf('ch%d', x), 1:n_ch, 'UniformOutput', false);
    end
    sig_channel_names = ch_labels(sig_ch_mask);

    % Package results
    r = struct();
    r.significant = is_significant;
    r.p_global = p_global;
    r.p_values = p_values;
    r.p_channel = p_channel;
    r.observed_diff = observed_diff(:)';
    r.cohens_d = cohens_d;
    r.mean_d = mean(abs(cohens_d), 'omitnan');
    r.erp_A = erp_A;
    r.erp_B = erp_B;
    r.erp_diff = erp_diff;
    r.common_time = common_time;
    r.n_trials_A = n_A;
    r.n_trials_B = n_B;
    r.sig_mask = sig_mask;
    r.sig_windows = sig_windows;
    r.n_sig_channels = n_sig_channels;
    r.channel_labels = ch_labels;
    r.sig_channel_names = sig_channel_names;
    r.latent = latent_result;
    r.name = '';
    r.description = '';
    r.task_A_name = '';
    r.task_B_name = '';
    r.expected_effect = '';
end


function [tensor, time_vec, weights, labels, ch_labels] = load_task_data(task_info, results_dir)
% Load trial tensor and metadata for a single task.

    run_dir = fullfile(results_dir, ...
        sprintf('task-%s_run-%s', task_info.task, task_info.run), 'results');

    if ~isfolder(run_dir)
        error('Results not found: %s', run_dir);
    end

    epoch_file = fullfile(run_dir, 'stage04_epochs.mat');
    if ~isfile(epoch_file)
        error('Epoch data not found: %s', epoch_file);
    end
    s4 = load(epoch_file);
    tensor = s4.trial_tensor;
    time_vec = s4.time_vec;

    qc_file = fullfile(run_dir, 'stage05_qc.mat');
    if isfile(qc_file)
        s5 = load(qc_file);
        weights = s5.trial_weights;
        labels = s5.condition_labels;
    else
        weights = ones(size(tensor, 1), 1);
        labels = repmat({'stimulus'}, size(tensor, 1), 1);
    end

    % Load channel labels from stage01 or stage03
    ch_labels = {};
    bids_file = fullfile(run_dir, 'stage01_bids.mat');
    if isfile(bids_file)
        s1 = load(bids_file, 'channel_labels');
        if isfield(s1, 'channel_labels')
            ch_labels = s1.channel_labels;
        end
    end
    if isempty(ch_labels)
        preproc_file = fullfile(run_dir, 'stage03_preproc.mat');
        if isfile(preproc_file)
            s3 = load(preproc_file, 'channel_labels');
            if isfield(s3, 'channel_labels')
                ch_labels = s3.channel_labels;
            end
        end
    end
end


function latent = run_latent_cross_task(combined_tensor, task_labels, n_A, cfg)
% PCA on combined data, then measure task separation in latent space.

    n_trials = size(combined_tensor, 1);
    n_ch = size(combined_tensor, 2);
    n_time = size(combined_tensor, 3);

    % Normalize per channel
    for ch = 1:n_ch
        ch_data = reshape(combined_tensor(:, ch, :), [], 1);
        mu = mean(ch_data, 'omitnan');
        sd = std(ch_data, 'omitnan');
        if sd > eps
            combined_tensor(:, ch, :) = (combined_tensor(:, ch, :) - mu) / sd;
        end
    end

    % Reshape for PCA: (trials*time) x channels
    X = reshape(permute(combined_tensor, [1 3 2]), [], n_ch);
    X(isnan(X)) = 0;

    n_dims = min(6, n_ch);
    if isfield(cfg, 'n_latent_dims')
        n_dims = min(cfg.n_latent_dims, n_ch);
    end

    [coeff, ~, ~, ~, explained] = pca(X, 'NumComponents', n_dims);

    % Project each trial: trials x dims x time
    latent_tensor = zeros(n_trials, n_dims, n_time);
    for tr = 1:n_trials
        tr_data = reshape(combined_tensor(tr, :, :), n_ch, [])';  % time x ch
        tr_data(isnan(tr_data)) = 0;
        latent_tensor(tr, :, :) = (tr_data * coeff)';
    end

    % Task-averaged trajectories: dims x time
    traj_A = reshape(mean(latent_tensor(1:n_A, :, :), 1, 'omitnan'), n_dims, []);
    traj_B = reshape(mean(latent_tensor(n_A+1:end, :, :), 1, 'omitnan'), n_dims, []);

    % Euclidean distance between task centroids over time
    separation = sqrt(sum((traj_A - traj_B).^2, 1));

    % Permutation test on separation (correct: split by index, not logical)
    n_perm = 200;
    null_sep = zeros(n_perm, n_time);
    for pi = 1:n_perm
        perm_idx = randperm(n_trials);
        pA = reshape(mean(latent_tensor(perm_idx(1:n_A), :, :), 1, 'omitnan'), n_dims, []);
        pB = reshape(mean(latent_tensor(perm_idx(n_A+1:end), :, :), 1, 'omitnan'), n_dims, []);
        null_sep(pi, :) = sqrt(sum((pA - pB).^2, 1));
    end

    p_sep = zeros(1, n_time);
    for ti = 1:n_time
        p_sep(ti) = mean(null_sep(:, ti) >= separation(ti));
    end
    p_sep = max(p_sep, 1 / n_perm);

    latent = struct();
    latent.explained_variance = explained(1:n_dims) / 100;
    latent.traj_A = traj_A;
    latent.traj_B = traj_B;
    latent.separation = separation;
    latent.p_separation = p_sep;
    latent.peak_separation = max(separation);
    latent.p_peak = min(p_sep);
end


function sig_windows = find_sig_windows(sig_mask, time_vec)
% Find contiguous significant time windows.
    sig_windows = {};
    in_window = false;
    win_start = 0;

    for ti = 1:numel(sig_mask)
        if sig_mask(ti) && ~in_window
            in_window = true;
            win_start = time_vec(ti) * 1000;
        elseif ~sig_mask(ti) && in_window
            in_window = false;
            sig_windows{end+1} = [win_start, time_vec(ti-1) * 1000];
        end
    end
    if in_window
        sig_windows{end+1} = [win_start, time_vec(end) * 1000];
    end
end


function r = make_empty_result(cc)
% Create an empty result struct for failed contrasts (matching all fields).
    r = struct();
    r.significant = false;
    r.p_global = NaN;
    r.p_values = [];
    r.p_channel = [];
    r.observed_diff = [];
    r.cohens_d = [];
    r.mean_d = NaN;
    r.erp_A = [];
    r.erp_B = [];
    r.erp_diff = [];
    r.common_time = [];
    r.n_trials_A = 0;
    r.n_trials_B = 0;
    r.sig_mask = [];
    r.sig_windows = {};
    r.n_sig_channels = 0;
    r.channel_labels = {};
    r.sig_channel_names = {};
    r.latent = struct('explained_variance', [], 'traj_A', [], 'traj_B', [], ...
        'separation', [], 'p_separation', [], 'peak_separation', NaN, 'p_peak', NaN);
    r.name = cc.name;
    r.description = cc.description;
    r.task_A_name = cc.task_A.task;
    r.task_B_name = cc.task_B.task;
    r.expected_effect = cc.expected_effect;
end
