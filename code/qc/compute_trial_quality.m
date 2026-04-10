function [quality_scores, trial_labels, metrics] = compute_trial_quality(trial_tensor, time_vec, cfg)
% COMPUTE_TRIAL_QUALITY Main trial-level quality control pipeline.
%
%   [quality_scores, trial_labels, metrics] = compute_trial_quality(trial_tensor, time_vec, cfg)
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       time_vec     - time vector in seconds
%       cfg          - config struct with baseline_start, baseline_end, qc_weights, etc.
%
%   Outputs:
%       quality_scores - trials x 1 composite quality scores
%       trial_labels   - cell array of 'green', 'yellow', 'red'
%       metrics        - struct with individual metric values

    baseline_window = [cfg.baseline_start, cfg.baseline_end];

    metrics.rms = compute_rms_metric(trial_tensor, time_vec, baseline_window);
    metrics.var = compute_variance_metric(trial_tensor, time_vec, baseline_window);
    metrics.p2p = compute_peak_to_peak_metric(trial_tensor, time_vec, baseline_window);
    metrics.kurt = compute_kurtosis_metric(trial_tensor, time_vec, baseline_window);

    if isfield(cfg, 'fs') && isfield(cfg, 'line_noise_freq')
        metrics.line_noise = compute_line_noise_ratio(trial_tensor, time_vec, ...
            cfg.fs, cfg.line_noise_freq, baseline_window);
    else
        metrics.line_noise = zeros(size(metrics.rms));
    end

    quality_scores = make_composite_quality_score(metrics, cfg.qc_weights);
    trial_labels = classify_trials(quality_scores, cfg.qc_green_threshold, cfg.qc_red_threshold);
end
