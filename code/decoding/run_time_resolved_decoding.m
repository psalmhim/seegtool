function [accuracy_time, predictions_time] = run_time_resolved_decoding(latent_tensor, condition_labels, n_folds, method)
% RUN_TIME_RESOLVED_DECODING Decode at each timepoint independently.
    if nargin < 3, n_folds = 5; end
    if nargin < 4, method = 'lda'; end
    [n_trials, ~, n_time] = size(latent_tensor);
    accuracy_time = zeros(1, n_time);
    predictions_time = zeros(n_trials, n_time);
    for t = 1:n_time
        X = squeeze(latent_tensor(:, :, t));
        [acc, pred, ~] = run_cross_validation(X, condition_labels, n_folds, method);
        accuracy_time(t) = acc;
        predictions_time(:, t) = pred;
    end
end
