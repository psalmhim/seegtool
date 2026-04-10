function tf_norm = baseline_normalize_tf(tf_power, time_vec, baseline_window, method)
% BASELINE_NORMALIZE_TF Normalize TF power relative to baseline.
%
%   tf_norm = baseline_normalize_tf(tf_power, time_vec, baseline_window, method)
%
%   Inputs:
%       tf_power        - trials x channels x freqs x time (or channels x freqs x time)
%       time_vec        - time vector in seconds
%       baseline_window - [start_time, end_time] in seconds
%       method          - 'db', 'zscore', or 'percent' (default: 'db')
%
%   Outputs:
%       tf_norm - normalized TF power, same size as input

    if nargin < 4 || isempty(method)
        method = 'db';
    end

    base_idx = time_vec >= baseline_window(1) & time_vec <= baseline_window(2);
    ndims_tf = ndims(tf_power);

    if ndims_tf == 4
        base_mean = mean(tf_power(:, :, :, base_idx), 4);
        base_std = std(tf_power(:, :, :, base_idx), 0, 4);
    elseif ndims_tf == 3
        base_mean = mean(tf_power(:, :, base_idx), 3);
        base_std = std(tf_power(:, :, base_idx), 0, 3);
    else
        base_mean = mean(tf_power(:, base_idx), 2);
        base_std = std(tf_power(:, base_idx), 0, 2);
    end

    base_mean(base_mean == 0) = eps;
    base_std(base_std == 0) = eps;

    switch lower(method)
        case 'db'
            tf_norm = 10 * log10(tf_power ./ base_mean);
        case 'zscore'
            tf_norm = (tf_power - base_mean) ./ base_std;
        case 'percent'
            tf_norm = 100 * (tf_power - base_mean) ./ base_mean;
        otherwise
            error('baseline_normalize_tf:invalidMethod', 'Unknown method: %s', method);
    end
end
