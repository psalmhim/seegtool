function [onset_time, onset_idx] = estimate_decoding_onset(accuracy_time, p_values, time_vec, alpha, n_consecutive)
% ESTIMATE_DECODING_ONSET Find first significant decoding timepoint.
    if nargin < 4, alpha = 0.05; end
    if nargin < 5, n_consecutive = 3; end
    sig = p_values < alpha;
    count = 0;
    onset_idx = NaN;
    onset_time = NaN;
    for t = 1:numel(sig)
        if sig(t)
            count = count + 1;
            if count >= n_consecutive
                onset_idx = t - n_consecutive + 1;
                onset_time = time_vec(onset_idx);
                return;
            end
        else
            count = 0;
        end
    end
end
