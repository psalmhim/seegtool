function hfa_feats = extract_hfa_features(tf_power, freqs, time_vec, hfa_range, baseline_window)
% EXTRACT_HFA_FEATURES Extract baseline-normalized HFA timecourses.
%
%   hfa_feats = extract_hfa_features(tf_power, freqs, time_vec, hfa_range, baseline_window)
%
%   Inputs:
%       tf_power        - trials x channels x freqs x time
%       freqs           - frequency vector
%       time_vec        - time vector
%       hfa_range       - [f_low, f_high] for HFA (default: [70, 150])
%       baseline_window - [start_time, end_time] in seconds
%
%   Outputs:
%       hfa_feats - trials x channels x time (baseline-normalized)

    if nargin < 4 || isempty(hfa_range)
        hfa_range = [70, 150];
    end

    hfa_raw = compute_high_frequency_activity(tf_power, freqs, hfa_range);

    if nargin >= 5 && ~isempty(baseline_window)
        base_idx = time_vec >= baseline_window(1) & time_vec <= baseline_window(2);
        base_mean = mean(hfa_raw(:, :, base_idx), 3);
        base_mean(base_mean == 0) = eps;
        hfa_feats = 10 * log10(hfa_raw ./ base_mean);
    else
        hfa_feats = hfa_raw;
    end
end
