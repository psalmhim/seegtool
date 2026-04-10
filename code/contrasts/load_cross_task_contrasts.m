function cross_contrasts = load_cross_task_contrasts(contrast_dir)
% LOAD_CROSS_TASK_CONTRASTS Parse cross-task contrasts from per-task JSON files.
%
%   cross_contrasts = load_cross_task_contrasts(contrast_dir)
%
%   Reads all task JSON files in contrast_dir and extracts cross_task_contrasts
%   fields. Returns a struct array ready for run_cross_task_analysis.
%
%   Each element has:
%       .name           - contrast name
%       .description    - human-readable description
%       .task_A         - struct with .task, .session, .run fields
%       .task_B         - struct with .task, .session, .run fields
%       .weight_A       - weight for task A (default 1)
%       .weight_B       - weight for task B (default -1)
%       .source_task    - which JSON file defined this contrast
%       .priority       - analysis priority (default 1)

    cross_contrasts = struct([]);

    if ~isfolder(contrast_dir)
        fprintf('[CrossContrast] Directory not found: %s\n', contrast_dir);
        return;
    end

    json_files = dir(fullfile(contrast_dir, '*_analysis_contrast.json'));
    if isempty(json_files)
        fprintf('[CrossContrast] No contrast JSON files found.\n');
        return;
    end

    % Task label to session/run mapping
    task_map = build_task_map();

    idx = 0;
    seen = {};  % avoid duplicate contrasts

    for f = 1:numel(json_files)
        filepath = fullfile(contrast_dir, json_files(f).name);
        try
            raw = fileread(filepath);
            cfg = jsondecode(raw);
        catch ME
            fprintf('[CrossContrast] Failed to parse %s: %s\n', json_files(f).name, ME.message);
            continue;
        end

        source_task = '';
        if isfield(cfg, 'task')
            source_task = cfg.task;
        end

        if ~isfield(cfg, 'cross_task_contrasts')
            continue;
        end

        xtc = cfg.cross_task_contrasts;
        if isstruct(xtc)
            xtc_cell = num2cell(xtc);
        elseif iscell(xtc)
            xtc_cell = xtc;
        else
            continue;
        end

        for ci = 1:numel(xtc_cell)
            if iscell(xtc_cell)
                c = xtc_cell{ci};
            else
                c = xtc_cell(ci);
            end

            name = '';
            if isfield(c, 'name')
                name = c.name;
            end

            % Skip duplicates (same contrast defined in both task JSONs)
            if any(strcmp(seen, name))
                continue;
            end
            seen{end+1} = name;

            ref_task = '';
            if isfield(c, 'reference_task')
                ref_task = c.reference_task;
            end

            desc = '';
            if isfield(c, 'description')
                desc = c.description;
            end

            priority = 1;
            if isfield(c, 'priority')
                priority = c.priority;
            end

            % Resolve task A (source) and task B (reference)
            task_A = resolve_task(source_task, task_map);
            task_B = resolve_task(ref_task, task_map);

            if isempty(task_A.task) || isempty(task_B.task)
                fprintf('[CrossContrast] Cannot resolve tasks for "%s": %s vs %s\n', ...
                    name, source_task, ref_task);
                continue;
            end

            idx = idx + 1;
            cross_contrasts(idx).name = name;
            cross_contrasts(idx).description = desc;
            cross_contrasts(idx).task_A = task_A;
            cross_contrasts(idx).task_B = task_B;
            cross_contrasts(idx).weight_A = 1;
            cross_contrasts(idx).weight_B = -1;
            cross_contrasts(idx).source_task = source_task;
            cross_contrasts(idx).priority = priority;

            % Store neuroimaging expectations if available
            if isfield(c, 'neuroimaging_implication')
                cross_contrasts(idx).expected_effect = c.neuroimaging_implication;
            else
                cross_contrasts(idx).expected_effect = '';
            end
        end
    end

    % Sort by priority
    if ~isempty(cross_contrasts)
        [~, order] = sort([cross_contrasts.priority]);
        cross_contrasts = cross_contrasts(order);
        fprintf('[CrossContrast] Loaded %d cross-task contrasts from %d JSON files.\n', ...
            numel(cross_contrasts), numel(json_files));
    end
end


function task_map = build_task_map()
% Known task label -> session/run mapping for EP01AN96M1047
    task_map = struct();
    task_map.lexicaldecision = struct('session', 'task01', 'run', '01');
    task_map.shapecontrol    = struct('session', 'task02', 'run', '01');
    task_map.sentencenoun    = struct('session', 'task03', 'run', '01');
    task_map.sentencegrammar = struct('session', 'task04', 'run', '01');
    task_map.saliencepain    = struct('session', 'task05', 'run', '01');
    task_map.balloonwatching = struct('session', 'task06', 'run', '01');
    task_map.viseme          = struct('session', 'task08', 'run', '01');
    task_map.visemegen       = struct('session', 'task08', 'run', '01');
    task_map.visualrhythm    = struct('session', 'task10', 'run', '02');
end


function info = resolve_task(task_label, task_map)
% Resolve a task label to session/run info.
    info = struct('task', '', 'session', '', 'run', '');
    if isempty(task_label)
        return;
    end
    fname = matlab.lang.makeValidName(task_label);
    if isfield(task_map, fname)
        m = task_map.(fname);
        info.task = task_label;
        info.session = m.session;
        info.run = m.run;
    else
        info.task = task_label;
        info.session = '';
        info.run = '01';
    end
end
