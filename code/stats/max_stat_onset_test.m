function [onset_time, p_values] = max_stat_onset_test(data_post, data_base, time_vec, n_perms)
% MAX_STAT_ONSET_TEST Max-statistic permutation test for response onset.
%
%   [onset_time, p_values] = max_stat_onset_test(data_post, data_base, time_vec, n_perms)
%
%   Controls FWER across timepoints using max-statistic approach.
%
%   Inputs:
%       data_post - trials x time (post-stimulus)
%       data_base - trials x time (baseline)
%       time_vec  - time vector for post-stimulus period
%       n_perms   - number of permutations (default: 1000)
%
%   Outputs:
%       onset_time - first significant timepoint (seconds)
%       p_values   - 1 x time corrected p-values

    if nargin < 4, n_perms = 1000; end

    n_trials = size(data_post, 1);
    n_time = size(data_post, 2);
    n_base = size(data_base, 2);

    % Observed t-statistics at each timepoint
    base_mean = mean(data_base(:));
    base_std = std(data_base(:));
    if base_std == 0, base_std = eps; end

    t_obs = (mean(data_post, 1) - base_mean) / (base_std / sqrt(n_trials));

    % Null distribution of max statistic
    null_max = zeros(n_perms, 1);
    combined = [data_post, data_base];
    n_total_time = n_time + n_base;

    for p = 1:n_perms
        perm_data = combined(:, randperm(n_total_time));
        perm_post = perm_data(:, 1:n_time);
        perm_base = perm_data(:, n_time+1:end);
        perm_base_mean = mean(perm_base(:));
        perm_base_std = std(perm_base(:));
        if perm_base_std == 0, perm_base_std = eps; end
        t_perm = (mean(perm_post, 1) - perm_base_mean) / (perm_base_std / sqrt(n_trials));
        null_max(p) = max(abs(t_perm));
    end

    % Corrected p-values
    p_values = zeros(1, n_time);
    for t = 1:n_time
        p_values(t) = (sum(null_max >= abs(t_obs(t))) + 1) / (n_perms + 1);
    end

    % Find onset
    sig_idx = find(p_values < 0.05, 1);
    if isempty(sig_idx)
        onset_time = NaN;
    else
        onset_time = time_vec(sig_idx);
    end
end
