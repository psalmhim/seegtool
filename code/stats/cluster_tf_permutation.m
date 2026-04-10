function [sig_clusters, cluster_stats, p_values] = cluster_tf_permutation(tf_A, tf_B, n_perms, cluster_thresh, alpha)
% CLUSTER_TF_PERMUTATION Cluster-based permutation test for TF maps.
%
%   [sig_clusters, cluster_stats, p_values] = cluster_tf_permutation(tf_A, tf_B, n_perms, cluster_thresh, alpha)
%
%   Inputs:
%       tf_A            - trials_A x freqs x time
%       tf_B            - trials_B x freqs x time
%       n_perms         - number of permutations (default: 1000)
%       cluster_thresh  - t-statistic threshold for cluster formation (default: 2.0)
%       alpha           - significance level (default: 0.05)
%
%   Outputs:
%       sig_clusters  - logical matrix (freqs x time) of significant clusters
%       cluster_stats - vector of cluster statistics
%       p_values      - p-value for each cluster

    if nargin < 3, n_perms = 1000; end
    if nargin < 4, cluster_thresh = 2.0; end
    if nargin < 5, alpha = 0.05; end

    n_A = size(tf_A, 1);
    n_B = size(tf_B, 1);
    n_freqs = size(tf_A, 2);
    n_time = size(tf_A, 3);

    % Compute observed t-statistic map
    mean_A = squeeze(mean(tf_A, 1));
    mean_B = squeeze(mean(tf_B, 1));
    var_A = squeeze(var(tf_A, 0, 1));
    var_B = squeeze(var(tf_B, 0, 1));
    pooled_se = sqrt(var_A / n_A + var_B / n_B);
    pooled_se(pooled_se == 0) = eps;
    t_obs = (mean_A - mean_B) ./ pooled_se;

    % Find observed clusters
    [obs_cluster_stats, obs_cluster_map] = find_clusters(t_obs, cluster_thresh);

    % Build null distribution of max cluster stats
    combined = cat(1, tf_A, tf_B);
    n_total = n_A + n_B;
    null_max_cluster = zeros(n_perms, 1);

    for p = 1:n_perms
        perm_idx = randperm(n_total);
        perm_A = combined(perm_idx(1:n_A), :, :);
        perm_B = combined(perm_idx(n_A+1:end), :, :);

        perm_mean_A = squeeze(mean(perm_A, 1));
        perm_mean_B = squeeze(mean(perm_B, 1));
        perm_var_A = squeeze(var(perm_A, 0, 1));
        perm_var_B = squeeze(var(perm_B, 0, 1));
        perm_se = sqrt(perm_var_A / n_A + perm_var_B / n_B);
        perm_se(perm_se == 0) = eps;
        t_perm = (perm_mean_A - perm_mean_B) ./ perm_se;

        perm_stats = find_clusters(t_perm, cluster_thresh);
        if ~isempty(perm_stats)
            null_max_cluster(p) = max(abs(perm_stats));
        end
    end

    % Compute p-values for observed clusters
    n_clusters = numel(obs_cluster_stats);
    p_values = ones(n_clusters, 1);
    sig_clusters = false(n_freqs, n_time);

    for c = 1:n_clusters
        p_values(c) = (sum(null_max_cluster >= abs(obs_cluster_stats(c))) + 1) / (n_perms + 1);
        if p_values(c) < alpha
            sig_clusters = sig_clusters | (obs_cluster_map == c);
        end
    end

    cluster_stats = obs_cluster_stats;
end

function [cluster_stats, cluster_map] = find_clusters(t_map, thresh)
    pos_mask = t_map > thresh;
    neg_mask = t_map < -thresh;

    cluster_map = zeros(size(t_map));
    cluster_stats = [];
    cluster_id = 0;

    for mask_sign = [1, -1]
        if mask_sign == 1
            mask = pos_mask;
        else
            mask = neg_mask;
        end

        cc = bwconncomp(mask);
        for i = 1:cc.NumObjects
            cluster_id = cluster_id + 1;
            cluster_map(cc.PixelIdxList{i}) = cluster_id;
            cluster_stats(cluster_id) = sum(t_map(cc.PixelIdxList{i})); %#ok<AGROW>
        end
    end
end
