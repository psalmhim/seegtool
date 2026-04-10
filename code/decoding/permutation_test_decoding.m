function [p_values, null_dist] = permutation_test_decoding(latent_tensor, condition_labels, observed_accuracy, n_perms, n_folds, method)
% PERMUTATION_TEST_DECODING Permutation test for decoding significance.
    if nargin < 4, n_perms = 100; end
    if nargin < 5, n_folds = 5; end
    if nargin < 6, method = 'lda'; end
    n_time = size(latent_tensor, 3);
    null_dist = zeros(n_perms, n_time);
    for p = 1:n_perms
        perm_labels = condition_labels(randperm(numel(condition_labels)));
        [null_dist(p,:), ~] = run_time_resolved_decoding(latent_tensor, perm_labels, n_folds, method);
    end
    p_values = zeros(1, n_time);
    for t = 1:n_time
        p_values(t) = (sum(null_dist(:,t) >= observed_accuracy(t)) + 1) / (n_perms + 1);
    end
end
