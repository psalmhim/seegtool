function [onset_time, onset_idx] = estimate_decoding_onset(accuracy_time, p_values, time_vec, alpha, n_consecutive)
% ESTIMATE_DECODING_ONSET Find first significant post-stimulus decoding timepoint.
%   Only searches for onset at t >= 0 (post-stimulus) to avoid spurious
%   pre-stimulus detections caused by noise.
    if nargin < 4, alpha = 0.05; end
    if nargin < 5, n_consecutive = 3; end

    % Only search post-stimulus timepoints (t >= 0)
    post_stim_mask = time_vec >= 0;
    post_indices = find(post_stim_mask);

    sig = p_values < alpha;
    count = 0;
    onset_idx = NaN;
    onset_time = NaN;

    for k = 1:numel(post_indices)
        t = post_indices(k);
        if sig(t)
            count = count + 1;
            if count >= n_consecutive
                onset_idx = post_indices(k - n_consecutive + 1);
                onset_time = time_vec(onset_idx);
                return;
            end
        else
            count = 0;
        end
    end
end
