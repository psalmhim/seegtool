function stats_results = run_permutation_statistics(trial_tensor, condition_labels, time_vec, cfg)
% RUN_PERMUTATION_STATISTICS Main statistics pipeline.
%
%   stats_results = run_permutation_statistics(trial_tensor, condition_labels, time_vec, cfg)
%
%   Inputs:
%       trial_tensor    - trials x channels x time
%       condition_labels - cell array of condition labels per trial
%       time_vec        - time vector in seconds
%       cfg             - config struct
%
%   Outputs:
%       stats_results - struct with p-values, clusters, onset times

    conditions = unique(condition_labels);
    if numel(conditions) < 2
        error('run_permutation_statistics:singleCondition', 'Need at least 2 conditions.');
    end

    n_channels = size(trial_tensor, 2);
    stats_results = struct();
    stats_results.conditions = conditions;

    % ROI-based permutation tests per channel
    post_idx = time_vec > 0;
    stats_results.roi_p_values = zeros(n_channels, 1);
    stats_results.effect_sizes = zeros(n_channels, 1);

    for ch = 1:n_channels
        channel_summary = squeeze(mean(trial_tensor(:, ch, post_idx), 3, 'omitnan'));
        [p, effect_size] = permutation_test_roi_groups(channel_summary, condition_labels, cfg.n_permutations);
        stats_results.roi_p_values(ch) = p;
        stats_results.effect_sizes(ch) = effect_size;
    end

    % FDR correction
    [stats_results.roi_significant, stats_results.roi_p_fdr] = ...
        fdr_correction(stats_results.roi_p_values, cfg.alpha_level);

    % Time-resolved channel significance map
    fprintf('[Stats] Computing channel x time significance map...\n');
    ch_sig = compute_channel_time_significance(trial_tensor, condition_labels, time_vec, cfg);
    stats_results.ch_time_p = ch_sig.ch_time_p;
    stats_results.ch_time_p_cluster = ch_sig.ch_time_p_cluster;
    stats_results.ch_time_p_fdr = ch_sig.ch_time_p_fdr;
    stats_results.ch_time_sig = ch_sig.ch_time_sig;
    stats_results.ch_time_t = ch_sig.ch_time_t;
    stats_results.onset_per_channel = ch_sig.onset_per_channel;
    stats_results.n_sig_timepoints = ch_sig.n_sig_timepoints;

    % Response onset detection per channel
    stats_results.onset_times = NaN(n_channels, 1);
    baseline_window = [cfg.baseline_start, cfg.baseline_end];
    idx_A = strcmp(condition_labels, conditions{1});

    for ch = 1:n_channels
        mean_signal = squeeze(mean(trial_tensor(idx_A, ch, :), 1));
        [onset, ~] = estimate_response_onset(mean_signal, time_vec, baseline_window);
        stats_results.onset_times(ch) = onset;
    end
end


function [p, effect_size] = permutation_test_roi_groups(values, labels, n_perm)
% Permutation test for binary or multi-class ROI summaries.
    [~, ~, group_idx] = unique(labels);
    n_groups = max(group_idx);

    if n_groups == 2
        data_A = values(group_idx == 1);
        data_B = values(group_idx == 2);
        [p, ~, ~] = permutation_test_roi(data_A, data_B, n_perm);
        pooled_std = sqrt((var(data_A, 0, 'omitnan') + var(data_B, 0, 'omitnan')) / 2);
        if pooled_std > 0
            effect_size = abs(mean(data_A, 'omitnan') - mean(data_B, 'omitnan')) / pooled_std;
        else
            effect_size = 0;
        end
        return;
    end

    observed = compute_group_fstat(values, group_idx);
    null_stats = zeros(n_perm, 1);
    for p_idx = 1:n_perm
        null_stats(p_idx) = compute_group_fstat(values, group_idx(randperm(numel(group_idx))));
    end
    p = (sum(null_stats >= observed) + 1) / (n_perm + 1);
    effect_size = compute_eta_squared(values, group_idx);
end


function f_stat = compute_group_fstat(values, group_idx)
% One-way ANOVA F-statistic computed directly for permutation testing.
    grand_mean = mean(values, 'omitnan');
    ss_between = 0;
    ss_within = 0;
    groups = unique(group_idx(:))';
    for g = groups
        g_vals = values(group_idx == g);
        if isempty(g_vals)
            continue;
        end
        g_mean = mean(g_vals, 'omitnan');
        ss_between = ss_between + numel(g_vals) * (g_mean - grand_mean)^2;
        ss_within = ss_within + sum((g_vals - g_mean).^2, 'omitnan');
    end
    df_between = max(numel(groups) - 1, 1);
    df_within = max(numel(values) - numel(groups), 1);
    f_stat = (ss_between / df_between) / max(ss_within / df_within, eps);
end


function eta_sq = compute_eta_squared(values, group_idx)
% Effect size for multi-class ROI summaries.
    grand_mean = mean(values, 'omitnan');
    ss_total = sum((values - grand_mean).^2, 'omitnan');
    ss_between = 0;
    groups = unique(group_idx(:))';
    for g = groups
        g_vals = values(group_idx == g);
        if isempty(g_vals)
            continue;
        end
        g_mean = mean(g_vals, 'omitnan');
        ss_between = ss_between + numel(g_vals) * (g_mean - grand_mean)^2;
    end
    eta_sq = ss_between / max(ss_total, eps);
end
