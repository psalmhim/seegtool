function weights = assign_trial_weights(labels)
% ASSIGN_TRIAL_WEIGHTS Assign numerical weights based on trial quality labels.
%
%   weights = assign_trial_weights(labels)
%
%   green = 1.0, yellow = 0.5, red = 0.0
%
%   Inputs:
%       labels - cell array of 'green', 'yellow', 'red' strings
%
%   Outputs:
%       weights - trials x 1 weight vector

    n_trials = numel(labels);
    weights = zeros(n_trials, 1);

    for k = 1:n_trials
        switch labels{k}
            case 'green'
                weights(k) = 1.0;
            case 'yellow'
                weights(k) = 0.5;
            case 'red'
                weights(k) = 0.0;
            otherwise
                warning('assign_trial_weights:unknownLabel', ...
                    'Unknown label "%s" for trial %d, assigning weight 0.', labels{k}, k);
                weights(k) = 0.0;
        end
    end
end
