function var_vals = compute_variance_metric(trial_tensor, time_vec, baseline_window)
% COMPUTE_VARIANCE_METRIC Compute signal variance in baseline window.
%
%   var_vals = compute_variance_metric(trial_tensor, time_vec, baseline_window)
%
%   Inputs:
%       trial_tensor    - trials x channels x time
%       time_vec        - time vector in seconds
%       baseline_window - [start_time, end_time] in seconds
%
%   Outputs:
%       var_vals - trials x channels matrix

    base_idx = time_vec >= baseline_window(1) & time_vec <= baseline_window(2);
    base_data = trial_tensor(:, :, base_idx);
    var_vals = squeeze(var(base_data, 0, 3));
end
