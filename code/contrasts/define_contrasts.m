function contrasts = define_contrasts(condition_labels, varargin)
% DEFINE_CONTRASTS Build contrast specifications from condition labels.
%
%   contrasts = define_contrasts(condition_labels)
%   contrasts = define_contrasts(condition_labels, 'type', 'all_pairwise')
%   contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs)
%
%   A general-purpose contrast builder for any experimental design.
%   Contrasts define which conditions to compare and how, enabling
%   the pipeline to run targeted statistical tests, separation analyses,
%   decoding, and visualization for each contrast independently.
%
%   Inputs:
%       condition_labels - cell array of condition strings per trial
%                          (e.g., {'pain','noPain','pain','noPain',...})
%
%   Name-Value Parameters:
%       'type'     - Contrast generation strategy:
%                    'all_pairwise'   - All pairs of conditions (default)
%                    'one_vs_rest'    - Each condition vs all others
%                    'first_vs_rest'  - First condition vs rest (control)
%                    'custom'         - User-provided contrast specs
%                    'sequential'     - Adjacent condition pairs
%                    'factorial'      - Factor-based contrasts
%       'specs'    - Cell array of custom contrast structs (for 'custom')
%       'factors'  - Struct defining factor levels (for 'factorial')
%       'baseline' - Which condition is baseline/control (string)
%       'weights'  - Custom weight vectors (for 'custom')
%
%   Output:
%       contrasts  - Struct array, each element:
%           .name       - Human-readable contrast name (e.g., 'pain > noPain')
%           .type       - 'pairwise', 'one_vs_rest', 'weighted', 'interaction'
%           .groups     - {groupA_labels, groupB_labels}
%           .weights    - [w1, w2, ...] weight per unique condition
%           .conditions - Unique condition names involved
%           .idx_A      - Logical mask for group A trials
%           .idx_B      - Logical mask for group B trials
%
%   Examples:
%       % All pairwise (default)
%       c = define_contrasts(labels);
%
%       % One condition vs rest
%       c = define_contrasts(labels, 'type', 'one_vs_rest');
%
%       % Control vs each condition
%       c = define_contrasts(labels, 'type', 'first_vs_rest', 'baseline', 'fixation');
%
%       % Custom contrasts
%       specs = {
%           struct('name', 'Word > Nonword', 'A', {{'word'}}, 'B', {{'nonword'}})
%           struct('name', 'Visual > Audio', 'A', {{'vis_word','vis_face'}}, 'B', {{'aud_word','aud_tone'}})
%       };
%       c = define_contrasts(labels, 'type', 'custom', 'specs', specs);
%
%       % Factorial (2x2 interaction)
%       factors.stimulus = {'word', 'nonword'};
%       factors.difficulty = {'easy', 'hard'};
%       c = define_contrasts(labels, 'type', 'factorial', 'factors', factors);

    p = inputParser;
    addRequired(p, 'condition_labels', @iscell);
    addParameter(p, 'type', 'all_pairwise', @ischar);
    addParameter(p, 'specs', {}, @iscell);
    addParameter(p, 'factors', struct(), @isstruct);
    addParameter(p, 'baseline', '', @ischar);
    addParameter(p, 'weights', [], @isnumeric);
    parse(p, condition_labels, varargin{:});

    unique_conds = unique(condition_labels, 'stable');
    n_conds = numel(unique_conds);
    n_trials = numel(condition_labels);

    switch lower(p.Results.type)
        case 'all_pairwise'
            contrasts = build_all_pairwise(condition_labels, unique_conds, n_trials);

        case 'one_vs_rest'
            contrasts = build_one_vs_rest(condition_labels, unique_conds, n_trials);

        case 'first_vs_rest'
            baseline = p.Results.baseline;
            if isempty(baseline)
                baseline = unique_conds{1};
            end
            contrasts = build_first_vs_rest(condition_labels, unique_conds, n_trials, baseline);

        case 'sequential'
            contrasts = build_sequential(condition_labels, unique_conds, n_trials);

        case 'custom'
            contrasts = build_custom(condition_labels, unique_conds, n_trials, p.Results.specs);

        case 'factorial'
            contrasts = build_factorial(condition_labels, unique_conds, n_trials, p.Results.factors);

        otherwise
            error('define_contrasts:unknownType', 'Unknown contrast type: %s', p.Results.type);
    end

    % Validate all contrasts — add n_A, n_B to every element first
    for i = 1:numel(contrasts)
        if ~isfield(contrasts, 'n_A')
            [contrasts.n_A] = deal(0);
            [contrasts.n_B] = deal(0);
        end
        contrasts(i) = validate_contrast(contrasts(i), n_trials);
    end

    fprintf('[Contrasts] Defined %d contrasts from %d conditions (%s)\n', ...
        numel(contrasts), n_conds, p.Results.type);
end


%% ======================================================================
%  Builders
%% ======================================================================

function contrasts = build_all_pairwise(labels, conds, n_trials)
    n = numel(conds);
    k = 0;
    contrasts = [];
    for i = 1:n
        for j = (i+1):n
            k = k + 1;
            c = make_pairwise(labels, conds{i}, conds{j}, n_trials);
            if isempty(contrasts)
                contrasts = c;
            else
                contrasts(k) = c;
            end
        end
    end
    if isempty(contrasts)
        contrasts = empty_contrast_array();
    end
end


function contrasts = build_one_vs_rest(labels, conds, n_trials)
    contrasts = [];
    for i = 1:numel(conds)
        rest = conds;
        rest(i) = [];
        c = struct();
        c.name = sprintf('%s > rest', conds{i});
        c.type = 'one_vs_rest';
        c.groups = {{conds{i}}, rest};
        c.conditions = conds;
        c.idx_A = ismember(labels, conds(i));
        c.idx_B = ~c.idx_A;
        c.weights = build_weight_vector(conds, {conds{i}}, rest);
        if isempty(contrasts)
            contrasts = c;
        else
            contrasts(end+1) = c;
        end
    end
    if isempty(contrasts)
        contrasts = empty_contrast_array();
    end
end


function contrasts = build_first_vs_rest(labels, conds, n_trials, baseline)
    contrasts = [];
    for i = 1:numel(conds)
        if strcmp(conds{i}, baseline); continue; end
        c = make_pairwise(labels, conds{i}, baseline, n_trials);
        c.name = sprintf('%s > %s', conds{i}, baseline);
        c.type = 'vs_baseline';
        if isempty(contrasts)
            contrasts = c;
        else
            contrasts(end+1) = c;
        end
    end
    if isempty(contrasts)
        contrasts = empty_contrast_array();
    end
end


function contrasts = build_sequential(labels, conds, n_trials)
    contrasts = [];
    for i = 1:(numel(conds)-1)
        c = make_pairwise(labels, conds{i}, conds{i+1}, n_trials);
        if isempty(contrasts)
            contrasts = c;
        else
            contrasts(end+1) = c;
        end
    end
    if isempty(contrasts)
        contrasts = empty_contrast_array();
    end
end


function contrasts = build_custom(labels, conds, n_trials, specs)
    contrasts = [];
    for i = 1:numel(specs)
        s = specs{i};
        c = struct();
        c.name = s.name;
        c.type = 'custom';

        % A and B are cell arrays of condition names
        if isfield(s, 'A') && isfield(s, 'B')
            group_a = s.A;
            group_b = s.B;
        elseif isfield(s, 'groups')
            group_a = s.groups{1};
            group_b = s.groups{2};
        else
            error('define_contrasts:badSpec', 'Custom spec %d needs A/B or groups field.', i);
        end

        c.groups = {group_a, group_b};
        c.conditions = union(group_a, group_b);
        c.idx_A = ismember(labels, group_a);
        c.idx_B = ismember(labels, group_b);
        c.weights = build_weight_vector(conds, group_a, group_b);

        if isempty(contrasts)
            contrasts = c;
        else
            contrasts(end+1) = c;
        end
    end
    if isempty(contrasts)
        contrasts = empty_contrast_array();
    end
end


function contrasts = build_factorial(labels, conds, n_trials, factors)
% Build main effects and interaction contrasts from factorial design.
    factor_names = fieldnames(factors);
    n_factors = numel(factor_names);
    contrasts = [];

    if n_factors < 2
        error('define_contrasts:factorial', 'Factorial requires at least 2 factors.');
    end

    % Parse condition labels into factor levels
    % Assume condition labels are formatted as "level1_level2" or use
    % the factor struct to map conditions to levels
    factor_map = parse_factor_levels(labels, factors, factor_names);

    % Main effects
    for f = 1:n_factors
        fname = factor_names{f};
        levels = factors.(fname);
        for i = 1:numel(levels)
            for j = (i+1):numel(levels)
                c = struct();
                c.name = sprintf('%s: %s > %s', fname, levels{i}, levels{j});
                c.type = 'main_effect';
                c.conditions = conds;

                c.idx_A = false(1, n_trials);
                c.idx_B = false(1, n_trials);
                for t = 1:n_trials
                    if isfield(factor_map, 'trial_factors') && ...
                            numel(factor_map.trial_factors) >= t
                        tf = factor_map.trial_factors(t);
                        if isfield(tf, fname)
                            if strcmp(tf.(fname), levels{i})
                                c.idx_A(t) = true;
                            elseif strcmp(tf.(fname), levels{j})
                                c.idx_B(t) = true;
                            end
                        end
                    end
                end

                c.groups = {{levels{i}}, {levels{j}}};
                c.weights = zeros(1, numel(conds));

                if isempty(contrasts)
                    contrasts = c;
                else
                    contrasts(end+1) = c;
                end
            end
        end
    end

    % Interaction (2-way only for now)
    if n_factors >= 2
        f1 = factor_names{1};
        f2 = factor_names{2};
        l1 = factors.(f1);
        l2 = factors.(f2);

        if numel(l1) == 2 && numel(l2) == 2
            c = struct();
            c.name = sprintf('%s x %s interaction', f1, f2);
            c.type = 'interaction';
            c.conditions = conds;

            % Interaction: (A1B1 - A1B2) - (A2B1 - A2B2)
            c.idx_A = false(1, n_trials);
            c.idx_B = false(1, n_trials);
            for t = 1:n_trials
                if isfield(factor_map, 'trial_factors') && ...
                        numel(factor_map.trial_factors) >= t
                    tf = factor_map.trial_factors(t);
                    if isfield(tf, f1) && isfield(tf, f2)
                        is_f1_1 = strcmp(tf.(f1), l1{1});
                        is_f2_1 = strcmp(tf.(f2), l2{1});
                        % Group A: concordant (A1B1 + A2B2)
                        % Group B: discordant (A1B2 + A2B1)
                        if (is_f1_1 && is_f2_1) || (~is_f1_1 && ~is_f2_1)
                            c.idx_A(t) = true;
                        else
                            c.idx_B(t) = true;
                        end
                    end
                end
            end

            c.groups = {{'concordant'}, {'discordant'}};
            c.weights = zeros(1, numel(conds));

            if isempty(contrasts)
                contrasts = c;
            else
                contrasts(end+1) = c;
            end
        end
    end

    if isempty(contrasts)
        contrasts = empty_contrast_array();
    end
end


%% ======================================================================
%  Utilities
%% ======================================================================

function c = make_pairwise(labels, cond_a, cond_b, ~)
    c = struct();
    c.name = sprintf('%s > %s', cond_a, cond_b);
    c.type = 'pairwise';
    c.groups = {{cond_a}, {cond_b}};
    c.conditions = {cond_a, cond_b};
    c.idx_A = strcmp(labels, cond_a);
    c.idx_B = strcmp(labels, cond_b);
    c.weights = [1, -1];
end


function w = build_weight_vector(all_conds, group_a, group_b)
    w = zeros(1, numel(all_conds));
    n_a = numel(group_a);
    n_b = numel(group_b);
    for i = 1:numel(all_conds)
        if ismember(all_conds{i}, group_a)
            w(i) = 1 / n_a;
        elseif ismember(all_conds{i}, group_b)
            w(i) = -1 / n_b;
        end
    end
end


function c = validate_contrast(c, n_trials)
    if numel(c.idx_A) ~= n_trials
        c.idx_A = false(1, n_trials);
    end
    if numel(c.idx_B) ~= n_trials
        c.idx_B = false(1, n_trials);
    end
    c.n_A = sum(c.idx_A);
    c.n_B = sum(c.idx_B);
end


function contrasts = empty_contrast_array()
    contrasts = struct('name', {}, 'type', {}, 'groups', {}, ...
        'conditions', {}, 'idx_A', {}, 'idx_B', {}, 'weights', {});
end


function fm = parse_factor_levels(labels, factors, factor_names)
% Parse trial labels into factor assignments.
% Attempts to match by substring: if label contains a factor level string.
    fm.trial_factors = struct();
    for t = 1:numel(labels)
        lbl = labels{t};
        for f = 1:numel(factor_names)
            fname = factor_names{f};
            levels = factors.(fname);
            matched = '';
            for lv = 1:numel(levels)
                if contains(lower(lbl), lower(levels{lv}))
                    matched = levels{lv};
                    break;
                end
            end
            fm.trial_factors(t).(fname) = matched;
        end
    end
end
