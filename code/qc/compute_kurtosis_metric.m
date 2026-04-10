function kurt_vals = compute_kurtosis_metric(trial_tensor, time_vec, baseline_window)
% COMPUTE_KURTOSIS_METRIC Compute kurtosis in baseline window.
%
%   kurt_vals = compute_kurtosis_metric(trial_tensor, time_vec, baseline_window)
%
%   Inputs:
%       trial_tensor    - trials x channels x time
%       time_vec        - time vector in seconds
%       baseline_window - [start_time, end_time] in seconds
%
%   Outputs:
%       kurt_vals - trials x channels matrix

    base_idx = time_vec >= baseline_window(1) & time_vec <= baseline_window(2);
    base_data = trial_tensor(:, :, base_idx);

    n_trials = size(base_data, 1);
    n_channels = size(base_data, 2);
    kurt_vals = zeros(n_trials, n_channels);

    for k = 1:n_trials
        for ch = 1:n_channels
            kurt_vals(k, ch) = kurtosis(squeeze(base_data(k, ch, :)));
        end
    end
end
