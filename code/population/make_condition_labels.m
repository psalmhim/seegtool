function [cond_labels, cond_indices] = make_condition_labels(events, trial_indices)
% MAKE_CONDITION_LABELS Create condition label vectors from events.
%
%   [cond_labels, cond_indices] = make_condition_labels(events, trial_indices)
%
%   Inputs:
%       events        - struct array with field 'condition'
%       trial_indices - indices into events to use (default: all)
%
%   Outputs:
%       cond_labels  - cell array of condition strings per trial
%       cond_indices - struct with condition names as fields, containing trial indices

    if nargin < 2 || isempty(trial_indices)
        trial_indices = 1:numel(events);
    end

    n_trials = numel(trial_indices);
    cond_labels = cell(n_trials, 1);

    for i = 1:n_trials
        cond_labels{i} = events(trial_indices(i)).condition;
    end

    unique_conds = unique(cond_labels);
    cond_indices = struct();
    for c = 1:numel(unique_conds)
        field_name = matlab.lang.makeValidName(unique_conds{c});
        cond_indices.(field_name) = find(strcmp(cond_labels, unique_conds{c}));
    end
end
