function ch_sig = compute_channel_time_significance(trial_tensor, condition_labels, time_vec, cfg)
% COMPUTE_CHANNEL_TIME_SIGNIFICANCE Time-resolved per-channel permutation testing.
%
%   ch_sig = compute_channel_time_significance(trial_tensor, condition_labels, time_vec, cfg)
%
%   For each channel at each time point, tests condition A vs B via permutation
%   with cluster-based correction (Maris & Oostenveld 2007) and FDR correction.
%
%   Inputs:
%       trial_tensor     - trials x channels x time
%       condition_labels - cell array of condition labels per trial
%       time_vec         - time vector in seconds
%       cfg              - struct with: n_permutations, alpha_level, cluster_threshold
%
%   Outputs:
%       ch_sig - struct with:
%           .ch_time_p          - n_channels x n_time pointwise p-values
%           .ch_time_p_cluster  - n_channels x n_time cluster-corrected p-values
%           .ch_time_p_fdr      - n_channels x n_time FDR-corrected p-values
%           .ch_time_sig        - n_channels x n_time logical (cluster-corrected)
%           .ch_time_t          - n_channels x n_time observed t-statistics
%           .onset_per_channel  - n_channels x 1 first significant time (s)
%           .n_sig_timepoints   - n_channels x 1 count of significant timepoints

    conditions = unique(condition_labels);
    if numel(conditions) < 2
        error('compute_channel_time_significance:tooFewConditions', ...
            'Need at least 2 conditions, got %d', numel(conditions));
    end
    if numel(conditions) > 2
        warning('compute_channel_time_significance:multipleConditions', ...
            'Comparing first 2 of %d conditions: %s vs %s', ...
            numel(conditions), conditions{1}, conditions{2});
    end
    idx_A = strcmp(condition_labels, conditions{1});
    idx_B = strcmp(condition_labels, conditions{2});

    data_A = trial_tensor(idx_A, :, :);  % nA x channels x time
    data_B = trial_tensor(idx_B, :, :);  % nB x channels x time
    nA = size(data_A, 1);
    nB = size(data_B, 1);
    n_all = nA + nB;
    [~, n_channels, n_time] = size(trial_tensor);

    n_perm = cfg.n_permutations;
    alpha = cfg.alpha_level;
    t_thresh = cfg.cluster_threshold;

    % Combine trials for permutation shuffling
    all_data = trial_tensor([find(idx_A); find(idx_B)], :, :);  % (nA+nB) x ch x time

    % Observed t-statistics (channel x time)
    obs_t = compute_tstat(data_A, data_B);

    % Cluster-based permutation per channel
    ch_time_p = ones(n_channels, n_time);
    ch_time_p_cluster = ones(n_channels, n_time);

    fprintf('[ChTimeSig] %d channels, %d permutations...\n', n_channels, n_perm);

    for ch = 1:n_channels
        if mod(ch, 50) == 0
            fprintf('[ChTimeSig] Channel %d/%d\n', ch, n_channels);
        end

        ch_data = squeeze(all_data(:, ch, :));  % (nA+nB) x time
        obs_t_ch = obs_t(ch, :);

        % Observed clusters
        [obs_clusters, obs_cluster_mass] = find_temporal_clusters(obs_t_ch, t_thresh);

        % Null distribution of max cluster mass
        null_max_mass = zeros(n_perm, 1);
        null_t_counts = zeros(n_perm, n_time);  % for pointwise p

        for p = 1:n_perm
            perm_idx = randperm(n_all);
            perm_A = ch_data(perm_idx(1:nA), :);
            perm_B = ch_data(perm_idx(nA+1:end), :);
            perm_t = compute_tstat_1d(perm_A, perm_B);

            null_t_counts(p, :) = abs(perm_t) >= abs(obs_t_ch);

            [~, perm_mass] = find_temporal_clusters(perm_t, t_thresh);
            if ~isempty(perm_mass)
                null_max_mass(p) = max(abs(perm_mass));
            end
        end

        % Pointwise p-values
        ch_time_p(ch, :) = (sum(null_t_counts, 1) + 1) / (n_perm + 1);

        % Cluster-corrected p-values
        if ~isempty(obs_clusters)
            for ci = 1:numel(obs_cluster_mass)
                cluster_p = (sum(null_max_mass >= abs(obs_cluster_mass(ci))) + 1) / (n_perm + 1);
                ch_time_p_cluster(ch, obs_clusters{ci}) = cluster_p;
            end
        end
    end

    % FDR correction across all channel x time points
    p_vec = ch_time_p(:);
    [~, p_fdr_vec] = fdr_correction(p_vec, alpha);
    ch_time_p_fdr = reshape(p_fdr_vec, n_channels, n_time);

    % Significance mask (cluster-corrected)
    ch_time_sig = ch_time_p_cluster < alpha;

    % Per-channel onset: first post-zero significant time
    post_zero = time_vec > 0;
    onset_per_channel = NaN(n_channels, 1);
    n_sig_timepoints = zeros(n_channels, 1);

    for ch = 1:n_channels
        sig_post = ch_time_sig(ch, :) & post_zero;
        n_sig_timepoints(ch) = sum(ch_time_sig(ch, :));
        first_sig = find(sig_post, 1, 'first');
        if ~isempty(first_sig)
            onset_per_channel(ch) = time_vec(first_sig);
        end
    end

    ch_sig = struct();
    ch_sig.ch_time_p = ch_time_p;
    ch_sig.ch_time_p_cluster = ch_time_p_cluster;
    ch_sig.ch_time_p_fdr = ch_time_p_fdr;
    ch_sig.ch_time_sig = ch_time_sig;
    ch_sig.ch_time_t = obs_t;
    ch_sig.onset_per_channel = onset_per_channel;
    ch_sig.n_sig_timepoints = n_sig_timepoints;

    n_sig_ch = sum(any(ch_time_sig, 2));
    fprintf('[ChTimeSig] %d/%d channels with significant time points\n', n_sig_ch, n_channels);
end


function t = compute_tstat(data_A, data_B)
% Two-sample t-statistic for 3D arrays (trials x channels x time).
    nA = size(data_A, 1);
    nB = size(data_B, 1);
    n_ch = size(data_A, 2);
    n_t = size(data_A, 3);
    mean_A = reshape(mean(data_A, 1, 'omitnan'), n_ch, n_t);
    mean_B = reshape(mean(data_B, 1, 'omitnan'), n_ch, n_t);
    var_A = reshape(var(data_A, 0, 1, 'omitnan'), n_ch, n_t);
    var_B = reshape(var(data_B, 0, 1, 'omitnan'), n_ch, n_t);
    se = sqrt(var_A / nA + var_B / nB);
    se(se == 0) = eps;
    t = (mean_A - mean_B) ./ se;
    t(isnan(t)) = 0;
end


function t = compute_tstat_1d(data_A, data_B)
% Two-sample t-statistic for 2D arrays (trials x time).
    nA = size(data_A, 1);
    nB = size(data_B, 1);
    mean_A = mean(data_A, 1, 'omitnan');
    mean_B = mean(data_B, 1, 'omitnan');
    var_A = var(data_A, 0, 1, 'omitnan');
    var_B = var(data_B, 0, 1, 'omitnan');
    se = sqrt(var_A / nA + var_B / nB);
    se(se == 0) = eps;
    t = (mean_A - mean_B) ./ se;
    t(isnan(t)) = 0;
end


function [clusters, cluster_mass] = find_temporal_clusters(t_vals, threshold)
% Find contiguous temporal clusters above threshold.
    above = abs(t_vals) > threshold;
    clusters = {};
    cluster_mass = [];

    if ~any(above)
        return;
    end

    % Find cluster boundaries
    d = diff([0, above, 0]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;

    for i = 1:numel(starts)
        idx = starts(i):ends(i);
        clusters{end+1} = idx; %#ok<AGROW>
        cluster_mass(end+1) = sum(t_vals(idx)); %#ok<AGROW>
    end
end
