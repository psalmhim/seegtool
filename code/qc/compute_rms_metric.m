function rms_vals = compute_rms_metric(trial_tensor, time_vec, baseline_window)
% COMPUTE_RMS_METRIC Compute RMS amplitude in baseline window.
%
%   rms_vals = compute_rms_metric(trial_tensor, time_vec, baseline_window)
%
%   Inputs:
%       trial_tensor    - trials x channels x time
%       time_vec        - time vector in seconds
%       baseline_window - [start_time, end_time] in seconds
%
%   Outputs:
%       rms_vals - trials x channels matrix of RMS values

    base_idx = time_vec >= baseline_window(1) & time_vec <= baseline_window(2);
    base_data = trial_tensor(:, :, base_idx);
    rms_vals = squeeze(sqrt(mean(base_data.^2, 3)));
end
