function p2p_vals = compute_peak_to_peak_metric(trial_tensor, time_vec, baseline_window)
% COMPUTE_PEAK_TO_PEAK_METRIC Compute peak-to-peak amplitude in baseline.
%
%   p2p_vals = compute_peak_to_peak_metric(trial_tensor, time_vec, baseline_window)
%
%   P2P = max(x) - min(x) within baseline window.
%
%   Inputs:
%       trial_tensor    - trials x channels x time
%       time_vec        - time vector in seconds
%       baseline_window - [start_time, end_time] in seconds
%
%   Outputs:
%       p2p_vals - trials x channels matrix

    base_idx = time_vec >= baseline_window(1) & time_vec <= baseline_window(2);
    base_data = trial_tensor(:, :, base_idx);
    p2p_vals = squeeze(max(base_data, [], 3) - min(base_data, [], 3));
end
