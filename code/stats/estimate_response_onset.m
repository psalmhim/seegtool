function [onset_time, onset_idx] = estimate_response_onset(signal, time_vec, baseline_window, method)
% ESTIMATE_RESPONSE_ONSET Estimate earliest significant response onset.
%
%   [onset_time, onset_idx] = estimate_response_onset(signal, time_vec, baseline_window, method)
%
%   Inputs:
%       signal          - 1 x time signal
%       time_vec        - time vector in seconds
%       baseline_window - [start, end] in seconds
%       method          - 'threshold' (default) or 'permutation'
%
%   Outputs:
%       onset_time - onset time in seconds (NaN if none found)
%       onset_idx  - sample index

    if nargin < 4, method = 'threshold'; end

    base_idx = time_vec >= baseline_window(1) & time_vec <= baseline_window(2);
    base_signal = signal(base_idx);
    base_mean = mean(base_signal);
    base_std = std(base_signal);

    n_consecutive = 3;
    threshold_z = 3;

    post_idx = find(time_vec > 0);

    switch lower(method)
        case 'threshold'
            exceed = abs(signal(post_idx) - base_mean) > threshold_z * base_std;
            onset_idx_local = find_consecutive(exceed, n_consecutive);
            if isempty(onset_idx_local)
                onset_time = NaN;
                onset_idx = NaN;
            else
                onset_idx = post_idx(onset_idx_local);
                onset_time = time_vec(onset_idx);
            end

        case 'permutation'
            onset_time = NaN;
            onset_idx = NaN;
            % Simplified: use threshold method as fallback
            exceed = abs(signal(post_idx) - base_mean) > threshold_z * base_std;
            onset_idx_local = find_consecutive(exceed, n_consecutive);
            if ~isempty(onset_idx_local)
                onset_idx = post_idx(onset_idx_local);
                onset_time = time_vec(onset_idx);
            end
    end
end

function idx = find_consecutive(mask, n)
    idx = [];
    count = 0;
    for i = 1:numel(mask)
        if mask(i)
            count = count + 1;
            if count >= n
                idx = i - n + 1;
                return;
            end
        else
            count = 0;
        end
    end
end
