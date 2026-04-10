function [sep_index, p_values] = compute_time_resolved_separation(latent_tensor, cond_indices, n_perms)
% COMPUTE_TIME_RESOLVED_SEPARATION Separation index with cluster-corrected permutation test.
%   S(t) = ||z_bar_A(t) - z_bar_B(t)|| / (sigma_A(t) + sigma_B(t) + lambda)
%
%   Uses cluster-based correction (Maris & Oostenveld 2007) for temporal
%   multiple comparisons: clusters of contiguous above-threshold timepoints
%   are tested against the null distribution of max cluster mass.
%
%   Lambda = regularization on denominator to prevent noise spikes from
%   near-zero dispersion.

    if nargin < 3, n_perms = 1000; end
    cond_names = fieldnames(cond_indices);
    idx_A = cond_indices.(cond_names{1});
    idx_B = cond_indices.(cond_names{2});
    n_time = size(latent_tensor, 3);

    centroid_A = squeeze(mean(latent_tensor(idx_A, :, :), 1));
    centroid_B = squeeze(mean(latent_tensor(idx_B, :, :), 1));

    disp_A = compute_dispersion(latent_tensor(idx_A, :, :), centroid_A);
    disp_B = compute_dispersion(latent_tensor(idx_B, :, :), centroid_B);

    % Regularization: use median dispersion as floor to prevent noise spikes
    all_disp = [disp_A, disp_B];
    lambda = median(all_disp(all_disp > 0)) * 0.1;
    if isnan(lambda) || lambda == 0; lambda = 0.01; end

    sep_index = zeros(1, n_time);
    for t = 1:n_time
        denom = disp_A(t) + disp_B(t) + lambda;
        sep_index(t) = norm(centroid_A(:,t) - centroid_B(:,t)) / denom;
    end

    % Permutation test — build null distribution
    all_idx = [idx_A(:); idx_B(:)];
    n_A = numel(idx_A);
    null_sep = zeros(n_perms, n_time);
    null_max_cluster = zeros(n_perms, 1);  % for cluster correction

    for p = 1:n_perms
        perm = all_idx(randperm(numel(all_idx)));
        perm_idx_A = perm(1:n_A);
        perm_idx_B = perm(n_A+1:end);
        perm_cent_A = squeeze(mean(latent_tensor(perm_idx_A, :, :), 1));
        perm_cent_B = squeeze(mean(latent_tensor(perm_idx_B, :, :), 1));
        perm_disp_A = compute_dispersion(latent_tensor(perm_idx_A, :, :), perm_cent_A);
        perm_disp_B = compute_dispersion(latent_tensor(perm_idx_B, :, :), perm_cent_B);
        for t = 1:n_time
            denom = perm_disp_A(t) + perm_disp_B(t) + lambda;
            null_sep(p, t) = norm(perm_cent_A(:,t) - perm_cent_B(:,t)) / denom;
        end

        % Max cluster mass for this permutation (for cluster correction)
        null_max_cluster(p) = max_cluster_mass(null_sep(p, :), sep_index);
    end

    % Pointwise p-values (one-sided: separation is always >= 0)
    p_pointwise = zeros(1, n_time);
    for t = 1:n_time
        p_pointwise(t) = (sum(null_sep(:,t) >= sep_index(t)) + 1) / (n_perms + 1);
    end

    % Cluster-corrected p-values (Maris & Oostenveld 2007)
    p_values = cluster_correct_pvalues(sep_index, p_pointwise, null_max_cluster, 0.05);
end


function max_mass = max_cluster_mass(null_trace, obs_trace)
% Compute max cluster mass of null trace exceeding median of observed.
% Uses pointwise threshold: null > 95th percentile of observed as proxy.
    threshold = median(obs_trace);  % cluster-forming threshold
    above = null_trace > threshold;
    if ~any(above)
        max_mass = 0;
        return;
    end
    % Find contiguous clusters
    d = diff([0, above, 0]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    masses = zeros(numel(starts), 1);
    for c = 1:numel(starts)
        masses(c) = sum(null_trace(starts(c):ends(c)));
    end
    max_mass = max(masses);
end


function p_corr = cluster_correct_pvalues(obs_sep, p_pointwise, null_max_cluster, alpha)
% Assign cluster-corrected p-values.
% Clusters formed at pointwise p < alpha, then cluster mass compared to
% null distribution of max cluster mass.
    n_time = numel(obs_sep);
    p_corr = ones(1, n_time);  % default: not significant

    % Find observed clusters (pointwise p < alpha)
    sig_mask = p_pointwise < alpha;
    if ~any(sig_mask); return; end

    d = diff([0, sig_mask, 0]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;

    for c = 1:numel(starts)
        cluster_mass = sum(obs_sep(starts(c):ends(c)));
        % Cluster p-value: proportion of null max clusters >= observed cluster mass
        cluster_p = (sum(null_max_cluster >= cluster_mass) + 1) / (numel(null_max_cluster) + 1);
        % Assign cluster p to all timepoints in this cluster
        p_corr(starts(c):ends(c)) = cluster_p;
    end
end
