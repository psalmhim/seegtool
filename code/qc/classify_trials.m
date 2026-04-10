function labels = classify_trials(composite_scores, green_thresh, red_thresh)
% CLASSIFY_TRIALS Classify trials by quality score using adaptive thresholds.
%
%   labels = classify_trials(composite_scores, green_thresh, red_thresh)
%
%   Uses MAD-based adaptive thresholds when fixed thresholds fail to
%   discriminate (e.g., when all trials fall in one category).
%
%   Inputs:
%       composite_scores - trials x 1 quality scores
%       green_thresh     - threshold for green trials
%       red_thresh       - threshold for red (rejected) trials
%
%   Outputs:
%       labels - cell array of 'green', 'yellow', or 'red' strings

    n_trials = numel(composite_scores);

    % Treat NaN scores as bad trials
    nan_mask = isnan(composite_scores);
    if any(nan_mask)
        composite_scores(nan_mask) = Inf;  % will be classified as red
    end

    % Check if fixed thresholds discriminate
    n_green = sum(composite_scores < green_thresh);
    n_red = sum(composite_scores >= red_thresh);
    n_yellow = n_trials - n_green - n_red;

    % If everything falls in one category, use adaptive thresholds
    if (n_green == n_trials || n_yellow == n_trials || n_red == n_trials) && n_trials > 5
        med_score = median(composite_scores);
        mad_score = median(abs(composite_scores - med_score));
        if mad_score == 0
            mad_score = std(composite_scores) * 0.6745;  % fallback
        end
        if mad_score > 0
            green_thresh = med_score + 2.0 * mad_score;
            red_thresh = med_score + 4.0 * mad_score;
        end
    end

    labels = cell(n_trials, 1);
    for k = 1:n_trials
        if composite_scores(k) < green_thresh
            labels{k} = 'green';
        elseif composite_scores(k) >= red_thresh
            labels{k} = 'red';
        else
            labels{k} = 'yellow';
        end
    end
end
