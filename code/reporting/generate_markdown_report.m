function generate_markdown_report(all_results, runs, output_dir, cfg)
% GENERATE_MARKDOWN_REPORT Generate a journal-quality Markdown report emphasizing
% condition-dependent significant changes across all tasks.
%
%   generate_markdown_report(all_results, runs, output_dir, cfg)

    fprintf('[Report] Generating Markdown report...\n');

    report_dir = fullfile(output_dir, 'reports');
    if ~isfolder(report_dir); mkdir(report_dir); end

    % Find existing report dir (from LaTeX) or create new
    existing = dir(fullfile(report_dir, '20*'));
    if ~isempty(existing)
        report_dir = fullfile(report_dir, existing(end).name);
    else
        report_dir = fullfile(report_dir, datestr(now, 'yyyymmdd_HHMMSS'));
        mkdir(report_dir);
    end

    % Read template
    template_path = fullfile(fileparts(mfilename('fullpath')), 'templates', 'report_template.md');
    template = fileread(template_path);

    % Extract subject metadata
    [subject_id, fs, n_channels] = extract_subject_info(all_results);
    n_runs = numel(runs);
    unique_tasks = unique({runs.task});
    n_tasks = numel(unique_tasks);

    % Fill global placeholders
    template = strrep(template, '%%SUBJECT_ID%%', subject_id);
    template = strrep(template, '%%DATE%%', datestr(now, 'yyyy-mm-dd'));
    template = strrep(template, '%%N_TASKS%%', num2str(n_tasks));
    template = strrep(template, '%%N_RUNS%%', num2str(n_runs));
    template = strrep(template, '%%N_CHANNELS%%', num2str(n_channels));
    template = strrep(template, '%%FS%%', num2str(fs));
    template = strrep(template, '%%HIGHPASS%%', num2str(cfg.highpass_freq));
    template = strrep(template, '%%LOWPASS%%', num2str(cfg.lowpass_freq));
    template = strrep(template, '%%LINE_NOISE%%', num2str(cfg.line_noise_freq));
    template = strrep(template, '%%EPOCH_PRE%%', num2str(cfg.epoch_pre));
    template = strrep(template, '%%EPOCH_POST%%', num2str(cfg.epoch_post));
    template = strrep(template, '%%TF_CYCLES%%', num2str(cfg.n_cycles));
    template = strrep(template, '%%BASELINE_METHOD%%', cfg.baseline_norm_method);
    template = strrep(template, '%%N_LATENT_DIMS%%', num2str(cfg.n_latent_dims));
    template = strrep(template, '%%SMOOTH_MS%%', num2str(cfg.smooth_kernel_ms));
    template = strrep(template, '%%N_PERMS%%', num2str(cfg.n_permutations));
    template = strrep(template, '%%ALPHA%%', num2str(cfg.alpha));
    template = strrep(template, '%%N_FOLDS%%', num2str(cfg.n_folds));

    %% Analyze significance across all tasks
    sig_info = analyze_all_significance(all_results, runs);

    %% Key finding box
    template = strrep(template, '%%KEY_FINDING_BOX%%', ...
        generate_key_finding_md(sig_info, n_runs));

    %% Task table (with significance markers)
    task_rows = {};
    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);
        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if isfield(res, 'success') && res.success
            is_sig = check_task_significance(res);
            if is_sig
                task_rows{end+1} = sprintf('| **%s** | **%s** | **%d** | **%d** | **SIG** |', ...
                    runs(r).session, runs(r).task, res.n_trials, numel(res.conditions));
            else
                task_rows{end+1} = sprintf('| %s | %s | %d | %d | OK |', ...
                    runs(r).session, runs(r).task, res.n_trials, numel(res.conditions));
            end
        else
            task_rows{end+1} = sprintf('| %s | %s | -- | -- | FAIL |', ...
                runs(r).session, runs(r).task);
        end
    end
    template = strrep(template, '%%TASK_TABLE_ROWS%%', strjoin(task_rows, '\n'));

    %% Per-task sections
    per_task = {};
    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);
        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if ~isfield(res, 'success') || ~res.success; continue; end

        sec = generate_task_section_md(res, runs(r), field, report_dir);
        per_task{end+1} = sec;
    end
    template = strrep(template, '%%PER_TASK_SECTIONS%%', strjoin(per_task, '\n\n---\n\n'));

    %% Cross-task table
    [~, ~, cross_md] = write_stats_table(all_results, runs);
    template = strrep(template, '%%CROSS_TASK_TABLE_ROWS%%', cross_md);

    %% Cross-task text
    template = strrep(template, '%%CROSS_TASK_TEXT%%', ...
        generate_cross_task_text_md(sig_info));

    %% Significance timeline
    template = strrep(template, '%%SIGNIFICANCE_TIMELINE%%', ...
        generate_significance_timeline_md(sig_info));

    %% Interpretation
    template = strrep(template, '%%INTERPRETATION_TEXT%%', ...
        generate_interpretation_md(sig_info, n_runs));

    %% Write
    md_file = fullfile(report_dir, 'report.md');
    fid = fopen(md_file, 'w');
    fprintf(fid, '%s', template);
    fclose(fid);
    fprintf('[Report] Markdown: %s\n', md_file);
end


%% ======================================================================
%  Helper functions
%% ======================================================================

function [subject_id, fs, n_channels] = extract_subject_info(all_results)
    subject_id = '';
    fs = 0;
    n_channels = 0;
    first_field = fieldnames(all_results);
    if ~isempty(first_field)
        r1 = all_results.(first_field{1});
        if isfield(r1, 'meta') && isfield(r1.meta, 'subject')
            subject_id = r1.meta.subject;
        end
        if isfield(r1, 'fs'); fs = r1.fs; end
        if isfield(r1, 'n_channels'); n_channels = r1.n_channels; end
    end
end


function is_sig = check_task_significance(res)
    is_sig = false;
    if isfield(res, 'run_output')
        m = load_task_metrics(res.run_output);
        is_sig = m.is_sig;
    end
end


function sig_info = analyze_all_significance(all_results, runs)
% Same as in generate_latex_report — collect significance across tasks.
    sig_info = struct();
    sig_info.tasks = {};
    sig_info.n_sig = 0;
    sig_info.n_total = 0;
    sig_info.best_task = '';
    sig_info.best_sep = 0;
    sig_info.best_p = 1;
    sig_info.best_acc = 0;
    sig_info.earliest_onset = Inf;
    sig_info.details = {};

    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);
        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if ~isfield(res, 'success') || ~res.success; continue; end

        sig_info.n_total = sig_info.n_total + 1;

        % Load actual metrics from stage files
        m = load_task_metrics(res.run_output);

        d = struct();
        d.task = runs(r).task;
        d.session = runs(r).session;
        d.run = runs(r).run;
        d.is_sig = m.is_sig;
        d.min_p = m.min_p;
        d.peak_sep = m.peak_sep;
        d.peak_acc = m.peak_acc;
        d.onset_ms = m.onset_ms;
        d.sig_windows = {};
        d.n_conditions = numel(res.conditions);
        d.conditions = res.conditions;

        if d.is_sig
            sig_info.n_sig = sig_info.n_sig + 1;
            sig_info.tasks{end+1} = runs(r).task;
            if ~isempty(m.separation) && isfield(m.separation, 'p_values') && isfield(m.separation, 'time_vec')
                sig_mask = m.separation.p_values < 0.05;
                d.sig_windows = find_contiguous_windows(m.separation.time_vec, sig_mask);
            end
        end

        if d.peak_sep > sig_info.best_sep
            sig_info.best_sep = d.peak_sep;
            sig_info.best_task = runs(r).task;
            sig_info.best_p = d.min_p;
        end

        if ~isnan(m.peak_acc) && m.peak_acc > sig_info.best_acc
            sig_info.best_acc = m.peak_acc;
        end
        if ~isnan(m.onset_ms) && m.onset_ms < sig_info.earliest_onset
            sig_info.earliest_onset = m.onset_ms;
        end

        sig_info.details{end+1} = d;
    end
end


function windows = find_contiguous_windows(time_vec, sig_mask)
    windows = {};
    in_window = false;
    start_t = 0;
    for i = 1:numel(sig_mask)
        if sig_mask(i) && ~in_window
            in_window = true;
            start_t = time_vec(i);
        elseif ~sig_mask(i) && in_window
            in_window = false;
            windows{end+1} = [start_t * 1000, time_vec(i-1) * 1000];
        end
    end
    if in_window
        windows{end+1} = [start_t * 1000, time_vec(end) * 1000];
    end
end


function txt = generate_key_finding_md(sig_info, n_runs)
    if sig_info.n_sig == 0
        txt = 'No tasks showed statistically significant condition separation at p < 0.05 (cluster-corrected).';
        return;
    end

    unique_sig = unique(sig_info.tasks);
    txt = sprintf('**%d out of %d tasks** showed significant condition-dependent neural dynamics: **%s**. ', ...
        numel(unique_sig), n_runs, strjoin(unique_sig, ', '));
    txt = [txt, sprintf('Strongest separation in **%s** (peak = %.2f, p = %.4f). ', ...
        sig_info.best_task, sig_info.best_sep, sig_info.best_p)];
    if sig_info.best_acc > 0
        txt = [txt, sprintf('Peak decoding: **%.1f%%**. ', sig_info.best_acc * 100)];
    end
    if sig_info.earliest_onset < Inf
        txt = [txt, sprintf('Earliest onset: **%.0f ms**.', sig_info.earliest_onset)];
    end
end


function sec = generate_task_section_md(res, run, field, report_dir)
    task = run.task;
    parts = {};

    parts{end+1} = sprintf('### %s (ses-%s, run-%s)', task, run.session, run.run);
    parts{end+1} = sprintf('**%d trials, %d conditions** (%s)', ...
        res.n_trials, numel(res.conditions), strjoin(res.conditions, ', '));

    if isfield(run, 'description')
        parts{end+1} = sprintf('*%s*', run.description);
    end

    % Load actual metrics from stage files
    m = load_task_metrics(res.run_output);

    % Significance callout
    if m.is_sig && ~isempty(m.separation)
        stars = p_to_stars(m.min_p);
        parts{end+1} = sprintf(['> **SIGNIFICANT CONDITION SEPARATION DETECTED** %s\n', ...
            '> Peak separation: %.2f | p_min = %.4f | ', ...
            'Conditions (%s) show distinct neural dynamics.'], ...
            stars, m.peak_sep, m.min_p, strjoin(res.conditions, ' vs '));
    end

    % Figure references
    fig_types = {'erp', 'tf_power', 'latent_2d', 'separation', 'decoding', ...
                 'statistics', 'roi_trajectories'};
    fig_labels = {'Event-Related Potentials', 'Time-Frequency Power', ...
                  'Latent Neural Trajectories', 'Condition Separation', ...
                  'Neural Decoding', 'Statistical Evidence', 'ROI Trajectories'};

    for fi = 1:numel(fig_types)
        png_path = fullfile(field, 'figures', 'png', [fig_types{fi} '.png']);
        full_png = fullfile(report_dir, png_path);
        if isfile(full_png)
            cap = write_figure_caption(fig_types{fi}, res, task);
            parts{end+1} = sprintf('**%s**\n\n![%s](%s)\n\n*%s*', ...
                fig_labels{fi}, fig_labels{fi}, png_path, cap);
        end
    end

    % Significance details
    if m.is_sig && ~isempty(m.separation) && isfield(m.separation, 'time_vec')
        parts{end+1} = '#### Significance Details';

        sig_mask = m.separation.p_values < 0.05;
        windows = find_contiguous_windows(m.separation.time_vec, sig_mask);
        if ~isempty(windows)
            win_strs = {};
            for w = 1:numel(windows)
                win_strs{w} = sprintf('%.0f-%.0f ms', windows{w}(1), windows{w}(2));
            end
            parts{end+1} = sprintf('**Significant time windows:** %s', strjoin(win_strs, ', '));
        end

        [peak_val, peak_idx] = max(m.separation.index);
        peak_t = m.separation.time_vec(peak_idx) * 1000;
        parts{end+1} = sprintf('**Peak condition separation:** %.2f at %.0f ms (p = %.4f)', ...
            peak_val, peak_t, m.min_p);
    end

    % Decoding
    if ~isnan(m.peak_acc)
        parts{end+1} = sprintf('**Peak decoding accuracy:** %.1f%%', m.peak_acc * 100);
        if ~isnan(m.onset_ms)
            parts{end+1} = sprintf('**Decoding onset:** %.0f ms', m.onset_ms);
        end
    end

    % Contrast summary
    if m.n_total_contrasts > 0
        parts{end+1} = sprintf('**Contrasts:** %d/%d significant', m.n_sig_contrasts, m.n_total_contrasts);
    end

    % TF multivariate
    if m.n_tf_clusters > 0
        parts{end+1} = sprintf('**TF clusters:** %d significant', m.n_tf_clusters);
    end
    if ~isnan(m.tf_mvpa_acc)
        parts{end+1} = sprintf('**TF-MVPA peak accuracy:** %.1f%%', m.tf_mvpa_acc * 100);
    end

    % Contrast analysis figure
    png_path = fullfile(field, 'figures', 'png', 'contrasts.png');
    full_png = fullfile(report_dir, png_path);
    if isfile(full_png)
        parts{end+1} = sprintf(['**Contrast Analysis**\n\n', ...
            '![Contrast Summary](%s)\n\n', ...
            '*Per-contrast separation and decoding with significance shading.*'], ...
            png_path);
    end

    sec = strjoin(parts, '\n\n');
end


function txt = generate_cross_task_text_md(sig_info)
    if sig_info.n_sig == 0
        txt = 'No tasks showed statistically significant condition separation.';
        return;
    end

    unique_sig = unique(sig_info.tasks);
    txt = sprintf('**Significant condition-dependent neural dynamics** in **%d/%d tasks**: %s. ', ...
        numel(unique_sig), sig_info.n_total, strjoin(unique_sig, ', '));
    txt = [txt, sprintf('Strongest separation in **%s** (peak = %.2f, p = %.4f). ', ...
        sig_info.best_task, sig_info.best_sep, sig_info.best_p)];
    if sig_info.best_acc > 0
        txt = [txt, sprintf('Peak decoding: **%.1f%%**. ', sig_info.best_acc * 100)];
    end
    if sig_info.earliest_onset < Inf
        txt = [txt, sprintf('Earliest onset: **%.0f ms**.', sig_info.earliest_onset)];
    end
end


function txt = generate_significance_timeline_md(sig_info)
    parts = {};
    parts{end+1} = '#### Temporal Profiles of Condition Discrimination';

    has_any = false;
    for i = 1:numel(sig_info.details)
        d = sig_info.details{i};
        if ~d.is_sig; continue; end
        has_any = true;

        win_strs = {};
        for w = 1:numel(d.sig_windows)
            win_strs{w} = sprintf('%.0f-%.0f ms', d.sig_windows{w}(1), d.sig_windows{w}(2));
        end

        parts{end+1} = sprintf('- **%s** (ses-%s, run-%s): **%s** | Peak sep. = %.2f | p = %.4f', ...
            d.task, d.session, d.run, strjoin(win_strs, '; '), d.peak_sep, d.min_p);
    end

    if ~has_any
        parts{end+1} = 'No tasks showed significant condition-dependent time windows.';
    end

    txt = strjoin(parts, '\n');
end


function txt = generate_interpretation_md(sig_info, n_runs)
    parts = {};

    if sig_info.n_sig == 0
        parts{end+1} = ['The absence of significant condition separation may reflect: ', ...
            '(1) insufficient trial counts; (2) homogeneous neural responses across conditions; ', ...
            'or (3) condition differences in dimensions not captured by the current analysis.'];
    else
        unique_sig = unique(sig_info.tasks);
        parts{end+1} = sprintf(['**%d out of %d tasks** showed condition-dependent neural dynamics, ', ...
            'indicating that the sampled SEEG channels capture brain regions that ', ...
            'differentially process task-relevant information.'], ...
            numel(unique_sig), n_runs);

        for i = 1:numel(sig_info.details)
            d = sig_info.details{i};
            if ~d.is_sig; continue; end

            if ~isempty(d.sig_windows)
                first_win = d.sig_windows{1};
                if first_win(1) < 100
                    timing = 'early (pre-100ms)';
                elseif first_win(1) < 300
                    timing = 'mid-latency (100-300ms)';
                else
                    timing = 'late (post-300ms)';
                end
                parts{end+1} = sprintf('- **%s**: %s condition separation onset (%d conditions: %s)', ...
                    d.task, timing, d.n_conditions, strjoin(d.conditions, ', '));
            end
        end
    end

    txt = strjoin(parts, '\n');
end


function stars = p_to_stars(p)
    if p < 0.001
        stars = '***';
    elseif p < 0.01
        stars = '**';
    elseif p < 0.05
        stars = '*';
    else
        stars = 'n.s.';
    end
end
