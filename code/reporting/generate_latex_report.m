function generate_latex_report(all_results, runs, output_dir, cfg)
% GENERATE_LATEX_REPORT Generate a journal-quality LaTeX report emphasizing
% condition-dependent significant changes across all tasks.
%
%   generate_latex_report(all_results, runs, output_dir, cfg)

    fprintf('[Report] Generating LaTeX report...\n');

    report_dir = fullfile(output_dir, 'reports', datestr(now, 'yyyymmdd_HHMMSS'));
    if ~isfolder(report_dir); mkdir(report_dir); end

    % Read template
    template_path = fullfile(fileparts(mfilename('fullpath')), 'templates', 'report_template.tex');
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
        generate_key_finding_latex(sig_info, n_runs));

    %% Task overview table (with significance coloring)
    task_rows = {};
    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);
        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if isfield(res, 'success') && res.success
            is_sig = check_task_significance(res);
            if is_sig
                task_rows{end+1} = sprintf('\\textcolor{sigcolor}{\\textbf{%s}} & \\textcolor{sigcolor}{\\textbf{%s}} & \\textcolor{sigcolor}{\\textbf{%d}} & \\textcolor{sigcolor}{\\textbf{%d}} & \\textcolor{sigcolor}{\\textbf{SIG}} \\\\', ...
                    runs(r).session, runs(r).task, res.n_trials, numel(res.conditions));
            else
                task_rows{end+1} = sprintf('%s & %s & %d & %d & OK \\\\', ...
                    runs(r).session, runs(r).task, res.n_trials, numel(res.conditions));
            end
        else
            task_rows{end+1} = sprintf('%s & %s & -- & -- & FAIL \\\\', ...
                runs(r).session, runs(r).task);
        end
    end
    template = strrep(template, '%%TASK_TABLE_ROWS%%', strjoin(task_rows, '\n'));

    %% Per-task sections with figures and significance emphasis
    per_task = {};
    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);
        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if ~isfield(res, 'success') || ~res.success; continue; end

        sec = generate_task_section_latex(res, runs(r), field, report_dir, cfg);
        per_task{end+1} = sec;
    end
    template = strrep(template, '%%PER_TASK_SECTIONS%%', strjoin(per_task, '\n\n'));

    %% Cross-task table
    [cross_latex, cross_csv, ~] = write_stats_table(all_results, runs);
    template = strrep(template, '%%CROSS_TASK_TABLE_ROWS%%', cross_latex);

    %% Cross-task text and significance summary
    cross_text = generate_cross_task_text(sig_info);
    template = strrep(template, '%%CROSS_TASK_TEXT%%', cross_text);

    %% Significance timeline
    timeline = generate_significance_timeline_latex(sig_info);
    template = strrep(template, '%%SIGNIFICANCE_TIMELINE%%', timeline);

    %% Interpretation
    interp = generate_interpretation_latex(sig_info, n_runs);
    template = strrep(template, '%%INTERPRETATION_TEXT%%', interp);

    %% Write output files
    tex_file = fullfile(report_dir, 'report.tex');
    fid = fopen(tex_file, 'w');
    fprintf(fid, '%s', template);
    fclose(fid);
    fprintf('[Report] LaTeX: %s\n', tex_file);

    % Save CSV
    csv_file = fullfile(report_dir, 'stats_summary.csv');
    fid = fopen(csv_file, 'w');
    fprintf(fid, '%s', cross_csv);
    fclose(fid);

    % Generate cross-task significance figure
    try
        plot_cross_task_significance(sig_info, report_dir);
    catch ME
        fprintf('[Report] Cross-task significance figure failed: %s\n', ME.message);
    end

    % Try to compile
    try
        [status, ~] = system(sprintf('cd "%s" && pdflatex -interaction=nonstopmode report.tex 2>/dev/null', report_dir));
        if status == 0
            % Run twice for TOC
            system(sprintf('cd "%s" && pdflatex -interaction=nonstopmode report.tex 2>/dev/null', report_dir));
            fprintf('[Report] PDF compiled: %s\n', fullfile(report_dir, 'report.pdf'));
        end
    catch
        fprintf('[Report] pdflatex not available; .tex file ready for manual compilation.\n');
    end
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
    if ~isfield(res, 'run_output'); return; end
    m = load_task_metrics(res.run_output);
    is_sig = m.is_sig;
end


function sig_info = analyze_all_significance(all_results, runs)
% Collect significance information across all tasks.
% Loads actual metrics from stage files via load_task_metrics.
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

        d = struct();
        d.task = runs(r).task;
        d.session = runs(r).session;
        d.run = runs(r).run;
        d.is_sig = false;
        d.min_p = NaN;
        d.peak_sep = NaN;
        d.peak_acc = NaN;
        d.onset_ms = NaN;
        d.sig_windows = {};
        d.n_conditions = numel(res.conditions);
        d.conditions = res.conditions;

        % Load metrics from stage files
        if ~isfield(res, 'run_output'); sig_info.details{end+1} = d; continue; end
        m = load_task_metrics(res.run_output);

        d.min_p = m.min_p;
        d.peak_sep = m.peak_sep;

        if m.is_sig
            d.is_sig = true;
            sig_info.n_sig = sig_info.n_sig + 1;
            sig_info.tasks{end+1} = runs(r).task;

            % Find significant time windows from separation data
            if ~isempty(m.separation) && isfield(m.separation, 'p_values') ...
                    && isfield(m.separation, 'time_vec')
                sig_mask = m.separation.p_values < 0.05;
                d.sig_windows = find_contiguous_windows(m.separation.time_vec, sig_mask);
            end
        end

        if ~isnan(d.peak_sep) && d.peak_sep > sig_info.best_sep
            sig_info.best_sep = d.peak_sep;
            sig_info.best_task = runs(r).task;
            sig_info.best_p = d.min_p;
        end

        % Decoding
        d.peak_acc = m.peak_acc;
        if ~isnan(m.peak_acc) && m.peak_acc > sig_info.best_acc
            sig_info.best_acc = m.peak_acc;
        end
        d.onset_ms = m.onset_ms;
        if ~isnan(m.onset_ms) && m.onset_ms < sig_info.earliest_onset
            sig_info.earliest_onset = m.onset_ms;
        end

        sig_info.details{end+1} = d;
    end
end


function windows = find_contiguous_windows(time_vec, sig_mask)
% Find contiguous significant time windows.
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


function txt = generate_key_finding_latex(sig_info, n_runs)
    if sig_info.n_sig == 0
        txt = 'No tasks showed statistically significant condition separation at $p < 0.05$ (cluster-corrected).';
        return;
    end

    unique_sig = unique(sig_info.tasks);
    txt = sprintf(['\\textbf{%d out of %d tasks} showed statistically significant ', ...
        'condition-dependent neural dynamics: \\textbf{%s}. '], ...
        numel(unique_sig), n_runs, strjoin(unique_sig, ', '));

    txt = [txt, sprintf(['The strongest condition separation was observed in ', ...
        '\\textbf{%s} (peak separation = %.2f, $p_{\\min}$ = %.4f). '], ...
        sig_info.best_task, sig_info.best_sep, sig_info.best_p)];

    if sig_info.best_acc > 0
        txt = [txt, sprintf('Peak decoding accuracy reached \\textbf{%.1f\\%%}. ', ...
            sig_info.best_acc * 100)];
    end

    if sig_info.earliest_onset < Inf
        txt = [txt, sprintf('Earliest decoding onset: \\textbf{%.0f~ms} post-stimulus.', ...
            sig_info.earliest_onset)];
    end
end


function sec = generate_task_section_latex(res, run, field, report_dir, cfg)
% Generate a per-task LaTeX section with significance emphasis.
% Loads actual metrics from stage files via load_task_metrics.
    task = run.task;
    parts = {};

    parts{end+1} = sprintf('\\subsection{%s (ses-%s, run-%s)}', ...
        strrep(task, '_', '\_'), run.session, run.run);

    % Task overview with conditions
    parts{end+1} = sprintf('\\textbf{%d trials, %d conditions} (%s).', ...
        res.n_trials, numel(res.conditions), strjoin(res.conditions, ', '));

    if isfield(run, 'description')
        parts{end+1} = sprintf('\\textit{%s}', run.description);
    end

    % Load metrics from stage files
    m = struct('is_sig', false, 'peak_sep', NaN, 'min_p', NaN, ...
               'peak_acc', NaN, 'onset_ms', NaN, 'separation', [], ...
               'decoding', [], 'n_sig_contrasts', 0, 'n_total_contrasts', 0, ...
               'n_tf_clusters', 0, 'tf_mvpa_acc', NaN, 'eff_dim', NaN, 'jpca_r2', NaN);
    if isfield(res, 'run_output')
        m = load_task_metrics(res.run_output);
    end

    % Significance callout box
    if m.is_sig
        stars = p_to_stars(m.min_p);
        parts{end+1} = sprintf(['\\begin{tcolorbox}[colback=sigbg, colframe=sigcolor]\n', ...
            '\\textcolor{sigcolor}{\\textbf{SIGNIFICANT CONDITION SEPARATION DETECTED}} %s\\\\\n', ...
            'Peak separation: %.2f | $p_{\\min}$ = %.4f | ', ...
            'Conditions (%s) show distinct neural dynamics.\\end{tcolorbox}'], ...
            stars, m.peak_sep, m.min_p, strjoin(res.conditions, ' vs '));
    end

    % Generate figures
    try
        generate_publication_figures(res, fullfile(report_dir, field), cfg);
    catch ME
        fprintf('[Report] Figure generation failed for %s: %s\n', field, ME.message);
    end

    % Figure references with captions
    fig_types = {'erp', 'tf_power', 'latent_2d', 'separation', 'decoding', ...
                 'statistics', 'roi_trajectories'};
    fig_labels = {'Event-Related Potentials', 'Time-Frequency Power', ...
                  'Latent Neural Trajectories', 'Condition Separation', ...
                  'Neural Decoding', 'Statistical Evidence', 'ROI Trajectories'};

    for fi = 1:numel(fig_types)
        fig_path = fullfile(field, 'figures', 'pdf', [fig_types{fi} '.pdf']);
        full_fig = fullfile(report_dir, fig_path);
        if isfile(full_fig)
            cap = write_figure_caption(fig_types{fi}, res, task);
            parts{end+1} = sprintf(['\\begin{figure}[H]\\centering\n', ...
                '\\includegraphics[width=\\textwidth]{%s}\n', ...
                '\\caption{\\textbf{%s.} %s}\n', ...
                '\\end{figure}'], fig_path, fig_labels{fi}, cap);
        end
    end

    % Significance detail panel
    if m.is_sig
        parts{end+1} = '\subsubsection*{Significance Details}';

        % Time windows from separation data
        if ~isempty(m.separation) && isfield(m.separation, 'p_values') ...
                && isfield(m.separation, 'time_vec')
            sig_mask = m.separation.p_values < 0.05;
            windows = find_contiguous_windows(m.separation.time_vec, sig_mask);
            if ~isempty(windows)
                win_strs = {};
                for w = 1:numel(windows)
                    win_strs{w} = sprintf('%.0f--%.0f~ms', windows{w}(1), windows{w}(2));
                end
                parts{end+1} = sprintf('\\textcolor{sigcolor}{Significant time windows:} %s', ...
                    strjoin(win_strs, ', '));
            end

            % Peak separation timing
            [peak_val, peak_idx] = max(m.separation.index);
            peak_t = m.separation.time_vec(peak_idx) * 1000;
            parts{end+1} = sprintf(['\\textcolor{sigcolor}{Peak condition separation:} ', ...
                '%.2f at %.0f~ms post-stimulus ($p$ = %.4f)'], ...
                peak_val, peak_t, m.min_p);
        end
    end

    % Decoding summary
    if ~isnan(m.peak_acc)
        parts{end+1} = sprintf('\\textbf{Peak decoding accuracy:} %.1f\\%%', m.peak_acc * 100);
        if ~isnan(m.onset_ms)
            parts{end+1} = sprintf('\\textbf{Decoding onset:} %.0f~ms', m.onset_ms);
        end
    end

    % Dynamics summary
    if ~isnan(m.eff_dim)
        parts{end+1} = sprintf('\\textbf{Effective dimensionality:} %.1f', m.eff_dim);
    end
    if ~isnan(m.jpca_r2)
        parts{end+1} = sprintf('\\textbf{jPCA $R^2$:} %.3f', m.jpca_r2);
    end

    % Contrast analysis results
    if m.n_total_contrasts > 0
        parts{end+1} = sprintf('\\textbf{Contrasts:} %d/%d significant', ...
            m.n_sig_contrasts, m.n_total_contrasts);
    end

    % TF multivariate stats
    if m.n_tf_clusters > 0
        parts{end+1} = sprintf('\\textbf{TF clusters:} %d significant', m.n_tf_clusters);
    end
    if ~isnan(m.tf_mvpa_acc)
        parts{end+1} = sprintf('\\textbf{TF MVPA accuracy:} %.1f\\%%', m.tf_mvpa_acc * 100);
    end

    % Contrast figure reference
    fig_path = fullfile(field, 'figures', 'pdf', 'contrasts.pdf');
    full_fig = fullfile(report_dir, fig_path);
    if isfile(full_fig)
        parts{end+1} = sprintf(['\\begin{figure}[H]\\centering\n', ...
            '\\includegraphics[width=\\textwidth]{%s}\n', ...
            '\\caption{\\textbf{Contrast Analysis.} ', ...
            'Per-contrast separation indices and decoding accuracy with ', ...
            'significance shading. Bottom: significance summary (-log10 p).}\n', ...
            '\\end{figure}'], fig_path);
    end

    sec = strjoin(parts, '\n\n');
end


function txt = generate_cross_task_text(sig_info)
    if sig_info.n_sig == 0
        txt = 'No tasks showed statistically significant condition separation at the corrected threshold.';
        return;
    end

    unique_sig = unique(sig_info.tasks);
    txt = sprintf(['\\textbf{Significant condition-dependent neural dynamics} were observed in ', ...
        '\\textcolor{sigcolor}{%d/%d tasks}: %s. '], ...
        numel(unique_sig), sig_info.n_total, strjoin(unique_sig, ', '));

    txt = [txt, sprintf(['The strongest condition separation was found in \\textbf{%s} ', ...
        '(peak separation = %.2f, $p_{\\min}$ = %.4f). '], ...
        sig_info.best_task, sig_info.best_sep, sig_info.best_p)];

    if sig_info.best_acc > 0
        txt = [txt, sprintf('Peak cross-validated decoding accuracy: %.1f\\%%. ', ...
            sig_info.best_acc * 100)];
    end

    if sig_info.earliest_onset < Inf
        txt = [txt, sprintf('Earliest condition discrimination onset: %.0f~ms post-stimulus.', ...
            sig_info.earliest_onset)];
    end
end


function txt = generate_significance_timeline_latex(sig_info)
% Generate a text-based significance timeline showing when each task
% shows significant condition differences.
    parts = {};
    parts{end+1} = '\subsubsection*{Temporal Profiles of Condition Discrimination}';

    has_any = false;
    for i = 1:numel(sig_info.details)
        d = sig_info.details{i};
        if ~d.is_sig; continue; end
        has_any = true;

        win_strs = {};
        for w = 1:numel(d.sig_windows)
            win_strs{w} = sprintf('%.0f--%.0f~ms', d.sig_windows{w}(1), d.sig_windows{w}(2));
        end

        parts{end+1} = sprintf(['\\textbf{%s} (ses-%s, run-%s): ', ...
            '\\textcolor{sigcolor}{%s} ', ...
            '| Peak sep. = %.2f | $p_{\\min}$ = %.4f'], ...
            d.task, d.session, d.run, ...
            strjoin(win_strs, '; '), d.peak_sep, d.min_p);
    end

    if ~has_any
        parts{end+1} = 'No tasks showed significant condition-dependent time windows.';
    end

    txt = strjoin(parts, '\n\n');
end


function txt = generate_interpretation_latex(sig_info, n_runs)
    parts = {};

    if sig_info.n_sig == 0
        parts{end+1} = ['The absence of significant condition separation across all tasks ', ...
            'may reflect: (1) insufficient trial counts for reliable estimation; ', ...
            '(2) homogeneous neural responses across conditions in the sampled brain regions; ', ...
            'or (3) condition differences that manifest in dimensions not captured by the ', ...
            'current latent space dimensionality.'];
    else
        unique_sig = unique(sig_info.tasks);
        parts{end+1} = sprintf(['\\textbf{%d out of %d tasks} showed condition-dependent ', ...
            'neural dynamics, indicating that the sampled SEEG channels capture ', ...
            'brain regions that differentially process task-relevant information.'], ...
            numel(unique_sig), n_runs);

        % Identify patterns
        for i = 1:numel(sig_info.details)
            d = sig_info.details{i};
            if ~d.is_sig; continue; end

            timing = '';
            if ~isempty(d.sig_windows)
                first_win = d.sig_windows{1};
                if first_win(1) < 100
                    timing = 'early (pre-100ms)';
                elseif first_win(1) < 300
                    timing = 'mid-latency (100--300ms)';
                else
                    timing = 'late (post-300ms)';
                end
            end

            if ~isempty(timing)
                parts{end+1} = sprintf(['\\textbf{%s}: %s condition separation onset suggests ', ...
                    '%s processing of the %d experimental conditions (%s).'], ...
                    d.task, timing, timing, d.n_conditions, strjoin(d.conditions, ', '));
            end
        end
    end

    txt = strjoin(parts, '\n\n');
end


function plot_cross_task_significance(sig_info, report_dir)
% Generate a cross-task significance overview figure.
    if isempty(sig_info.details); return; end

    s = nature_style();
    n_tasks = numel(sig_info.details);

    fig = figure('Name', 'CrossTask', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.double_col, 0.5 + 0.35 * n_tasks], ...
        'Color', s.figure.background, 'Visible', 'off');
    ax = axes(fig);
    hold(ax, 'on');

    colors = nature_colors(2);

    for i = 1:n_tasks
        d = sig_info.details{i};
        y = n_tasks - i + 1;

        if d.is_sig
            col = colors(1, :);
            fw = 'bold';
        else
            col = s.colors.nonsig;
            fw = 'normal';
        end

        % Task label
        text(ax, -0.02, y, sprintf('%s (r%s)', d.task, d.run), ...
            'FontSize', s.font.tick_label, 'FontName', s.font.family, ...
            'HorizontalAlignment', 'right', 'FontWeight', fw, 'Color', col);

        % Significance windows
        if d.is_sig && ~isempty(d.sig_windows)
            for w = 1:numel(d.sig_windows)
                win = d.sig_windows{w};
                fill(ax, [win(1) win(2) win(2) win(1)] / 1000, ...
                    [y-0.35 y-0.35 y+0.35 y+0.35], ...
                    s.colors.significance, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
            end
        end

        % Separation index bar
        if ~isnan(d.peak_sep)
            bar_len = min(d.peak_sep / 5, 1);  % normalize
            fill(ax, [0 bar_len bar_len 0], ...
                [y-0.15 y-0.15 y+0.15 y+0.15], col, ...
                'EdgeColor', 'none', 'FaceAlpha', 0.3);
        end
    end

    xline(ax, 0, '-', 'Color', s.colors.black, 'LineWidth', s.line.reference);
    xlabel(ax, 'Time (s)');
    title(ax, 'Condition-Dependent Significance Across Tasks', ...
        'FontSize', s.font.title, 'FontName', s.font.family);
    ylim(ax, [0.3, n_tasks + 0.7]);
    set(ax, 'YTick', []);
    apply_nature_style(ax, s);

    % Export
    fig_dir = fullfile(report_dir, 'figures');
    if ~isfolder(fig_dir); mkdir(fig_dir); end
    export_figure(fig, fullfile(fig_dir, 'cross_task_significance'), s, ...
        'width', 'double');
    export_figure(fig, fullfile(fig_dir, 'cross_task_significance'), s, ...
        'width', 'double', 'formats', {'png'});
    close(fig);
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
