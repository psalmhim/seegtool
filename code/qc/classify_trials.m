function labels = classify_trials(composite_scores, green_thresh, red_thresh)
% CLASSIFY_TRIALS Classify trials by quality score.
%
%   labels = classify_trials(composite_scores, green_thresh, red_thresh)
%
%   Classification: green (< green_thresh), yellow (between), red (> red_thresh)
%
%   Inputs:
%       composite_scores - trials x 1 quality scores
%       green_thresh     - threshold for green trials
%       red_thresh       - threshold for red (rejected) trials
%
%   Outputs:
%       labels - cell array of 'green', 'yellow', or 'red' strings

    n_trials = numel(composite_scores);
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
