function [accuracy_time, predictions_time] = run_time_resolved_decoding(latent_tensor, condition_labels, n_folds, method)
% RUN_TIME_RESOLVED_DECODING Decode at each timepoint independently.
%   Uses a FIXED fold assignment across all timepoints to prevent
%   temporal leakage from inconsistent train/test splits.
    if nargin < 3, n_folds = 5; end
    if nargin < 4, method = 'lda'; end
    [n_trials, ~, n_time] = size(latent_tensor);
    accuracy_time = zeros(1, n_time);
    predictions_time = zeros(n_trials, n_time);

    % Create fold assignment ONCE, reuse across all timepoints
    fold_idx = make_fixed_stratified_folds(condition_labels, n_folds);

    for t = 1:n_time
        X = squeeze(latent_tensor(:, :, t));
        [acc, pred, ~] = run_cross_validation(X, condition_labels, n_folds, method, fold_idx);
        accuracy_time(t) = acc;
        predictions_time(:, t) = pred;
    end
end


function fold_idx = make_fixed_stratified_folds(labels, n_folds)
% MAKE_FIXED_STRATIFIED_FOLDS Create stratified fold indices once.
    n_samples = numel(labels);
    [~, ~, y_numeric] = unique(labels);
    n_classes = max(y_numeric);
    fold_idx = zeros(n_samples, 1);
    for c = 1:n_classes
        c_idx = find(y_numeric == c);
        c_idx = c_idx(randperm(numel(c_idx)));
        for i = 1:numel(c_idx)
            fold_idx(c_idx(i)) = mod(i - 1, n_folds) + 1;
        end
    end
end
