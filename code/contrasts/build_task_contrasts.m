function contrasts = build_task_contrasts(task_name, condition_labels, varargin)
% BUILD_TASK_CONTRASTS Build task-appropriate contrasts automatically.
%
%   contrasts = build_task_contrasts(task_name, condition_labels)
%   contrasts = build_task_contrasts(task_name, condition_labels, 'override', specs)
%
%   Returns sensible default contrasts for each known task, or falls back
%   to all_pairwise for unknown tasks. User overrides always take priority.
%
%   This function makes the pipeline general: adding a new task only
%   requires adding a case here (or providing custom specs).
%
%   Inputs:
%       task_name        - task identifier string
%       condition_labels - cell array of condition labels per trial
%
%   Name-Value:
%       'override'  - cell array of custom contrast specs (always used if given)
%       'type'      - override the auto-detected contrast type
%
%   Output:
%       contrasts - struct array from define_contrasts()

    p = inputParser;
    addParameter(p, 'override', {}, @iscell);
    addParameter(p, 'type', '', @ischar);
    parse(p, varargin{:});

    % User override takes priority
    if ~isempty(p.Results.override)
        contrasts = define_contrasts(condition_labels, 'type', 'custom', ...
            'specs', p.Results.override);
        return;
    end

    if ~isempty(p.Results.type)
        contrasts = define_contrasts(condition_labels, 'type', p.Results.type);
        return;
    end

    unique_conds = unique(condition_labels, 'stable');
    n_conds = numel(unique_conds);

    % Default: all pairwise for 2-4 conditions, one_vs_rest for 5+
    default_type = 'all_pairwise';
    if n_conds >= 5
        default_type = 'one_vs_rest';
    end

    % Task-specific contrast definitions
    switch lower(task_name)
        case 'lexicaldecision'
            % Correct vs incorrect (lexical access success)
            if any(strcmp(unique_conds, 'correct')) && any(strcmp(unique_conds, 'incorrect'))
                specs = {struct('name', 'Correct > Incorrect', ...
                    'A', {{'correct'}}, 'B', {{'incorrect'}})};
                contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs);
            elseif any(contains(unique_conds, 'word'))
                specs = {struct('name', 'Word > Nonword', ...
                    'A', {unique_conds(contains(unique_conds, 'word') & ~contains(unique_conds, 'nonword'))}, ...
                    'B', {unique_conds(contains(unique_conds, 'nonword'))})};
                contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs);
            else
                contrasts = define_contrasts(condition_labels, 'type', default_type);
            end

        case 'saliencepain'
            % Pain vs noPain (core contrast)
            if any(strcmp(unique_conds, 'yesPain')) && any(strcmp(unique_conds, 'noPain'))
                specs = {struct('name', 'Pain > NoPain', ...
                    'A', {{'yesPain'}}, 'B', {{'noPain'}})};
                contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs);
            else
                contrasts = define_contrasts(condition_labels, 'type', default_type);
            end

        case {'sentencenoun', 'sentencegrammar'}
            % Correct vs incorrect (N400/P600-like)
            if any(strcmp(unique_conds, 'correct')) && any(strcmp(unique_conds, 'incorrect'))
                specs = {struct('name', 'Correct > Incorrect', ...
                    'A', {{'correct'}}, 'B', {{'incorrect'}})};
                contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs);
            else
                contrasts = define_contrasts(condition_labels, 'type', 'all_pairwise');
            end

        case 'balloonwatching'
            % Pop vs noPop: prediction error signal
            if any(strcmp(unique_conds, 'yes pop')) && any(strcmp(unique_conds, 'no pop'))
                specs = {struct('name', 'Pop > NoPop', ...
                    'A', {{'yes pop'}}, 'B', {{'no pop'}})};
                contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs);
            else
                contrasts = define_contrasts(condition_labels, 'type', default_type);
            end

        case 'viseme'
            % Visual speech categories: all pairwise for <=4, one_vs_rest for more
            contrasts = define_contrasts(condition_labels, 'type', default_type);

        case 'visemegen'
            % Speech vs nonspeech (talker generalization)
            if any(strcmp(unique_conds, 'speech')) && any(strcmp(unique_conds, 'nonspeech'))
                specs = {struct('name', 'Speech > Nonspeech', ...
                    'A', {{'speech'}}, 'B', {{'nonspeech'}})};
                contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs);
            else
                contrasts = define_contrasts(condition_labels, 'type', default_type);
            end

        case 'visualrhythm'
            % Key contrasts: speech vs scrambled, sine conditions vs rest
            specs = {};
            if any(strcmp(unique_conds, 'speech')) && any(strcmp(unique_conds, 'scrambled'))
                specs{end+1} = struct('name', 'Speech > Scrambled', ...
                    'A', {{'speech'}}, 'B', {{'scrambled'}});
            end
            if any(strcmp(unique_conds, 'sine_fast')) && any(strcmp(unique_conds, 'rest'))
                specs{end+1} = struct('name', 'SineFast > Rest', ...
                    'A', {{'sine_fast'}}, 'B', {{'rest'}});
            end
            if any(strcmp(unique_conds, 'sine_slow')) && any(strcmp(unique_conds, 'rest'))
                specs{end+1} = struct('name', 'SineSlow > Rest', ...
                    'A', {{'sine_slow'}}, 'B', {{'rest'}});
            end
            if any(strcmp(unique_conds, 'sine_fast')) && any(strcmp(unique_conds, 'sine_slow'))
                specs{end+1} = struct('name', 'SineFast > SineSlow', ...
                    'A', {{'sine_fast'}}, 'B', {{'sine_slow'}});
            end
            if any(strcmp(unique_conds, 'speech')) && any(strcmp(unique_conds, 'rest'))
                specs{end+1} = struct('name', 'Speech > Rest', ...
                    'A', {{'speech'}}, 'B', {{'rest'}});
            end
            if ~isempty(specs)
                contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs);
            else
                contrasts = define_contrasts(condition_labels, 'type', default_type);
            end

        case 'shapecontrol'
            % Shape control task
            contrasts = define_contrasts(condition_labels, 'type', default_type);

        otherwise
            % Unknown task: use smart default
            fprintf('[Contrasts] Unknown task "%s", using %s\n', task_name, default_type);
            contrasts = define_contrasts(condition_labels, 'type', default_type);
    end

    % If only 1 condition, return empty
    if n_conds < 2
        fprintf('[Contrasts] Single condition — no contrasts possible\n');
        contrasts = struct('name', {}, 'type', {}, 'groups', {}, ...
            'conditions', {}, 'idx_A', {}, 'idx_B', {}, 'weights', {});
    end
end
