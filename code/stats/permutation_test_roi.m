function [p_value, observed_stat, null_dist] = permutation_test_roi(data_A, data_B, n_perms)
% PERMUTATION_TEST_ROI Permutation test on ROI summary statistics.
%
%   [p_value, observed_stat, null_dist] = permutation_test_roi(data_A, data_B, n_perms)
%
%   Inputs:
%       data_A  - trials x 1 values for condition A
%       data_B  - trials x 1 values for condition B
%       n_perms - number of permutations (default: 1000)
%
%   Outputs:
%       p_value       - empirical p-value
%       observed_stat - observed difference of means
%       null_dist     - n_perms x 1 null distribution

    if nargin < 3 || isempty(n_perms)
        n_perms = 1000;
    end

    data_A = data_A(:);
    data_B = data_B(:);
    observed_stat = mean(data_A) - mean(data_B);

    combined = [data_A; data_B];
    n_A = numel(data_A);
    n_total = numel(combined);

    null_dist = zeros(n_perms, 1);
    for p = 1:n_perms
        perm_idx = randperm(n_total);
        perm_A = combined(perm_idx(1:n_A));
        perm_B = combined(perm_idx(n_A+1:end));
        null_dist(p) = mean(perm_A) - mean(perm_B);
    end

    p_value = (sum(abs(null_dist) >= abs(observed_stat)) + 1) / (n_perms + 1);
end
