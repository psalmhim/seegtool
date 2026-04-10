function html_file = generate_dashboard(results_dir, runs, varargin)
% GENERATE_DASHBOARD Create an HTML dashboard for pipeline status and results.
%
%   html_file = generate_dashboard(results_dir, runs)
%   html_file = generate_dashboard(..., 'output_dir', dir, 'open', true)
%
%   Scans the results directory, checks processing status for each run,
%   extracts key metrics, and generates a self-contained HTML dashboard
%   with embedded figure thumbnails.
%
%   Inputs:
%       results_dir - path to derivatives/seegring/sub-XXX/
%       runs        - struct array from define_all_runs()
%
%   Name-Value:
%       'output_dir'  - where to save HTML (default: results_dir)
%       'subject'     - subject ID string (default: extracted from path)
%       'open'        - open in browser after generation (default: true)
%
%   Output:
%       html_file - path to generated HTML file

    p = inputParser;
    addParameter(p, 'output_dir', results_dir);
    addParameter(p, 'subject', '');
    addParameter(p, 'open', true);
    parse(p, varargin{:});

    output_dir = p.Results.output_dir;
    if ~isfolder(output_dir); mkdir(output_dir); end

    subject = p.Results.subject;
    if isempty(subject)
        [~, folder_name] = fileparts(results_dir);
        subject = strrep(folder_name, 'sub-', '');
    end

    % Check pipeline status
    fprintf('[Dashboard] Scanning results for %d runs...\n', numel(runs));
    status = check_pipeline_status(results_dir, runs);

    % Generate HTML
    html = build_html(status, subject, results_dir);

    % Write file
    html_file = fullfile(output_dir, 'dashboard.html');
    fid = fopen(html_file, 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', html);
    fclose(fid);

    fprintf('[Dashboard] Generated: %s\n', html_file);

    % Open in browser
    if p.Results.open
        if ismac
            system(sprintf('open "%s"', html_file));
        elseif isunix
            system(sprintf('xdg-open "%s"', html_file));
        elseif ispc
            system(sprintf('start "%s"', html_file));
        end
    end
end


function html = build_html(status, subject, results_dir)
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    % Compute summary stats
    n_total = numel(status);
    n_complete = sum([status.success]);
    n_with_results = sum([status.has_results]);

    html = sprintf(['<!DOCTYPE html>\n<html lang="en">\n<head>\n' ...
        '<meta charset="UTF-8">\n' ...
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n' ...
        '<title>SEEG Pipeline Dashboard - %s</title>\n' ...
        '%s\n</head>\n<body>\n'], subject, get_css());

    % Header
    html = [html, sprintf(['<div class="header">\n' ...
        '<h1>SEEG Population Dynamics Dashboard</h1>\n' ...
        '<div class="subtitle">Subject: <strong>%s</strong> | ' ...
        'Generated: %s | Results: <code>%s</code></div>\n' ...
        '</div>\n'], subject, timestamp, results_dir)];

    % Summary cards
    html = [html, build_summary_cards(status, n_total, n_complete, n_with_results)];

    % Pipeline overview table
    html = [html, build_overview_table(status)];

    % Stage matrix
    html = [html, build_stage_matrix(status)];

    % Metrics comparison
    html = [html, build_metrics_section(status)];

    % Per-run detail sections with figures
    html = [html, build_run_details(status)];

    % Footer
    html = [html, sprintf(['<div class="footer">\n' ...
        'SEEG Population Dynamics Pipeline | seegring | %s\n' ...
        '</div>\n</body>\n</html>\n'], timestamp)];
end


function html = build_summary_cards(status, n_total, n_complete, n_with_results)
    % Count significant results
    n_sig = 0;
    peak_sep = 0;
    best_task = 'N/A';
    for i = 1:numel(status)
        if isfield(status(i).metrics, 'separation_p') && status(i).metrics.separation_p < 0.05
            n_sig = n_sig + 1;
        end
        if isfield(status(i).metrics, 'peak_separation')
            if status(i).metrics.peak_separation > peak_sep
                peak_sep = status(i).metrics.peak_separation;
                best_task = status(i).task;
            end
        end
    end

    pct = 0;
    if n_total > 0
        pct = round(100 * n_complete / n_total);
    end

    color_class = 'card-red';
    if pct == 100
        color_class = 'card-green';
    elseif pct > 50
        color_class = 'card-yellow';
    end

    html = '<div class="cards">\n';
    html = [html, sprintf(['<div class="card %s">\n' ...
        '<div class="card-value">%d / %d</div>\n' ...
        '<div class="card-label">Runs Complete (%d%%)</div>\n' ...
        '</div>\n'], color_class, n_complete, n_total, pct)];

    html = [html, sprintf(['<div class="card card-blue">\n' ...
        '<div class="card-value">%d</div>\n' ...
        '<div class="card-label">Significant Tasks (p<0.05)</div>\n' ...
        '</div>\n'], n_sig)];

    html = [html, sprintf(['<div class="card card-purple">\n' ...
        '<div class="card-value">%.2f</div>\n' ...
        '<div class="card-label">Peak Separation (%s)</div>\n' ...
        '</div>\n'], peak_sep, best_task)];

    total_figs = 0;
    for i = 1:numel(status)
        total_figs = total_figs + numel(status(i).figures);
    end
    html = [html, sprintf(['<div class="card card-teal">\n' ...
        '<div class="card-value">%d</div>\n' ...
        '<div class="card-label">Total Figures Generated</div>\n' ...
        '</div>\n'], total_figs)];

    html = [html, '</div>\n'];
end


function html = build_overview_table(status)
    html = ['<div class="section">\n' ...
        '<h2>Pipeline Overview</h2>\n' ...
        '<table>\n<thead>\n<tr>\n' ...
        '<th>#</th><th>Session</th><th>Task</th><th>Run</th>' ...
        '<th>Status</th><th>Stages</th><th>Trials</th><th>Channels</th>' ...
        '<th>Conditions</th><th>Last Modified</th><th>Size (MB)</th>\n' ...
        '</tr>\n</thead>\n<tbody>\n'];

    for i = 1:numel(status)
        s = status(i);

        if s.success
            status_badge = '<span class="badge badge-green">Complete</span>';
        elseif s.has_results
            status_badge = '<span class="badge badge-yellow">Partial</span>';
        else
            status_badge = '<span class="badge badge-red">Not Run</span>';
        end

        stages_str = sprintf('%d/%d', s.n_stages_complete, s.n_stages_total);
        trials_str = get_metric_str(s.metrics, 'n_trials', '%d');
        ch_str = get_metric_str(s.metrics, 'n_channels', '%d');
        cond_str = get_metric_str(s.metrics, 'n_conditions', '%d');

        html = [html, sprintf(['<tr>\n' ...
            '<td>%d</td><td>%s</td><td><strong>%s</strong></td><td>%s</td>' ...
            '<td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>' ...
            '<td>%s</td><td>%.1f</td>\n</tr>\n'], ...
            i, s.session, s.task, s.run, status_badge, stages_str, ...
            trials_str, ch_str, cond_str, s.last_modified_str, s.file_size_mb)];
    end

    html = [html, '</tbody>\n</table>\n</div>\n'];
end


function html = build_stage_matrix(status)
    stage_names = {'BIDS', 'Preproc', 'Epoch', 'QC', 'ERP', 'TF', ...
        'Phase', 'Stats', 'Pop', 'Latent', 'Geom', 'Dyn', ...
        'Decode', 'Contrast', 'Uncert', 'ROI', 'Viz'};
    stage_fields = {'bids_loaded', 'preprocessed', 'epoched', 'qc', ...
        'erp', 'timefreq', 'phase', 'stats', 'population', 'latent', ...
        'geometry', 'dynamics', 'decoding', 'contrasts', 'uncertainty', ...
        'roi', 'visualization'};

    html = ['<div class="section">\n' ...
        '<h2>Stage Completion Matrix</h2>\n' ...
        '<table class="stage-matrix">\n<thead>\n<tr>\n<th>Task</th>'];

    for j = 1:numel(stage_names)
        html = [html, sprintf('<th class="rotate"><div>%s</div></th>', stage_names{j})];
    end
    html = [html, '</tr>\n</thead>\n<tbody>\n'];

    for i = 1:numel(status)
        s = status(i);
        label = sprintf('%s (r%s)', s.task, s.run);
        html = [html, sprintf('<tr>\n<td><strong>%s</strong></td>', label)];

        if s.has_results && isstruct(s.stages)
            for j = 1:numel(stage_fields)
                if isfield(s.stages, stage_fields{j}) && s.stages.(stage_fields{j})
                    html = [html, '<td class="stage-done">&#10003;</td>'];
                else
                    html = [html, '<td class="stage-missing">&#10007;</td>'];
                end
            end
        else
            for j = 1:numel(stage_fields)
                html = [html, '<td class="stage-na">-</td>'];
            end
        end
        html = [html, '</tr>\n'];
    end

    html = [html, '</tbody>\n</table>\n</div>\n'];
end


function html = build_metrics_section(status)
    html = ['<div class="section">\n' ...
        '<h2>Key Metrics Comparison</h2>\n' ...
        '<table>\n<thead>\n<tr>\n' ...
        '<th>Task</th><th>Run</th><th>Peak Sep.</th><th>Sep. p-val</th>' ...
        '<th>Peak Decode</th><th>Decode Onset (ms)</th>' ...
        '<th>Expl. Var. (%)</th><th>jPCA R&sup2;</th>' ...
        '<th>Contrasts (sig/total)</th>\n' ...
        '</tr>\n</thead>\n<tbody>\n'];

    for i = 1:numel(status)
        s = status(i);
        m = s.metrics;

        sep_str = get_metric_str(m, 'peak_separation', '%.3f');
        p_str = get_metric_str(m, 'separation_p', '%.4f');
        dec_str = get_metric_str(m, 'peak_decoding', '%.1f%%');
        onset_str = get_metric_str(m, 'decoding_onset', '%.0f');
        var_str = '';
        if isfield(m, 'explained_var')
            var_str = sprintf('%.1f', m.explained_var * 100);
        end
        jpca_str = get_metric_str(m, 'jpca_r2', '%.3f');

        con_str = '-';
        if isfield(m, 'n_contrasts')
            sig_c = 0;
            if isfield(m, 'n_sig_contrasts')
                sig_c = m.n_sig_contrasts;
            end
            con_str = sprintf('%d / %d', sig_c, m.n_contrasts);
        end

        % Highlight significant rows
        row_class = '';
        if isfield(m, 'separation_p') && m.separation_p < 0.05
            row_class = ' class="sig-row"';
        end

        html = [html, sprintf(['<tr%s>\n' ...
            '<td><strong>%s</strong></td><td>%s</td>' ...
            '<td>%s</td><td>%s</td><td>%s</td><td>%s</td>' ...
            '<td>%s</td><td>%s</td><td>%s</td>\n</tr>\n'], ...
            row_class, s.task, s.run, sep_str, p_str, dec_str, ...
            onset_str, var_str, jpca_str, con_str)];
    end

    html = [html, '</tbody>\n</table>\n</div>\n'];
end


function html = build_run_details(status)
    html = '<div class="section">\n<h2>Per-Run Details & Figures</h2>\n';

    for i = 1:numel(status)
        s = status(i);

        if s.success
            badge = '<span class="badge badge-green">Complete</span>';
        elseif s.has_results
            badge = '<span class="badge badge-yellow">Partial</span>';
        else
            badge = '<span class="badge badge-red">Not Run</span>';
        end

        html = [html, sprintf(['<div class="run-section">\n' ...
            '<h3>%d. %s (run-%s) %s</h3>\n' ...
            '<p class="run-desc">%s</p>\n'], ...
            i, s.task, s.run, badge, s.description)];

        % Conditions list
        if isfield(s.metrics, 'conditions') && ~isempty(s.metrics.conditions)
            conds = s.metrics.conditions;
            html = [html, '<div class="conditions"><strong>Conditions:</strong> '];
            for c = 1:numel(conds)
                html = [html, sprintf('<span class="cond-tag">%s</span> ', conds{c})];
            end
            html = [html, '</div>\n'];
        end

        % Quick metrics
        if s.has_results
            html = [html, '<div class="quick-metrics">\n'];
            if isfield(s.metrics, 'n_trials')
                html = [html, sprintf('<span class="qm">Trials: %d</span>', s.metrics.n_trials)];
            end
            if isfield(s.metrics, 'n_channels')
                html = [html, sprintf('<span class="qm">Channels: %d</span>', s.metrics.n_channels)];
            end
            if isfield(s.metrics, 'peak_separation')
                html = [html, sprintf('<span class="qm">Peak Sep: %.3f</span>', s.metrics.peak_separation)];
            end
            if isfield(s.metrics, 'peak_decoding')
                html = [html, sprintf('<span class="qm">Peak Acc: %.1f%%</span>', s.metrics.peak_decoding)];
            end
            html = [html, '</div>\n'];
        end

        % Figures gallery
        figs = s.figures;
        if ~isempty(figs)
            html = [html, '<div class="fig-gallery">\n'];
            for f = 1:numel(figs)
                [~, fname, ext] = fileparts(figs{f});
                % Use file:// protocol for local images
                fig_uri = ['file://' strrep(figs{f}, ' ', '%20')];
                html = [html, sprintf(['<div class="fig-card">\n' ...
                    '<a href="%s" target="_blank">' ...
                    '<img src="%s" alt="%s" loading="lazy"></a>\n' ...
                    '<div class="fig-label">%s</div>\n' ...
                    '</div>\n'], fig_uri, fig_uri, fname, fname)];
            end
            html = [html, '</div>\n'];
        elseif ~s.has_results
            html = [html, '<p class="no-data">No results available. Run the pipeline first.</p>\n'];
        else
            html = [html, '<p class="no-data">No figures generated yet.</p>\n'];
        end

        html = [html, '</div>\n'];  % close run-section
    end

    html = [html, '</div>\n'];
end


function str = get_metric_str(metrics, field, fmt)
    if isfield(metrics, field) && ~isempty(metrics.(field))
        str = sprintf(fmt, metrics.(field));
    else
        str = '-';
    end
end


function css = get_css()
    css = ['<style>\n' ...
        ':root {\n' ...
        '  --bg: #0d1117; --surface: #161b22; --border: #30363d;\n' ...
        '  --text: #e6edf3; --muted: #8b949e; --accent: #58a6ff;\n' ...
        '  --green: #3fb950; --yellow: #d29922; --red: #f85149;\n' ...
        '  --purple: #bc8cff; --teal: #39d2c0; --blue: #58a6ff;\n' ...
        '}\n' ...
        '* { margin: 0; padding: 0; box-sizing: border-box; }\n' ...
        'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;\n' ...
        '  background: var(--bg); color: var(--text); line-height: 1.5; padding: 20px; }\n' ...
        'code { background: var(--surface); padding: 2px 6px; border-radius: 4px; font-size: 0.85em; }\n' ...
        '.header { text-align: center; padding: 30px 0 20px; border-bottom: 1px solid var(--border); margin-bottom: 30px; }\n' ...
        '.header h1 { font-size: 1.8em; color: var(--accent); }\n' ...
        '.subtitle { color: var(--muted); margin-top: 8px; font-size: 0.9em; }\n' ...
        '.cards { display: flex; gap: 16px; flex-wrap: wrap; margin-bottom: 30px; }\n' ...
        '.card { flex: 1; min-width: 200px; background: var(--surface); border-radius: 12px;\n' ...
        '  padding: 20px; text-align: center; border: 1px solid var(--border); }\n' ...
        '.card-value { font-size: 2em; font-weight: 700; }\n' ...
        '.card-label { color: var(--muted); font-size: 0.85em; margin-top: 4px; }\n' ...
        '.card-green .card-value { color: var(--green); }\n' ...
        '.card-yellow .card-value { color: var(--yellow); }\n' ...
        '.card-red .card-value { color: var(--red); }\n' ...
        '.card-blue .card-value { color: var(--blue); }\n' ...
        '.card-purple .card-value { color: var(--purple); }\n' ...
        '.card-teal .card-value { color: var(--teal); }\n' ...
        '.section { margin-bottom: 30px; }\n' ...
        '.section h2 { font-size: 1.3em; margin-bottom: 16px; color: var(--accent);\n' ...
        '  border-bottom: 1px solid var(--border); padding-bottom: 8px; }\n' ...
        'table { width: 100%; border-collapse: collapse; background: var(--surface);\n' ...
        '  border-radius: 8px; overflow: hidden; }\n' ...
        'th { background: #1c2128; color: var(--muted); font-weight: 600; font-size: 0.8em;\n' ...
        '  text-transform: uppercase; letter-spacing: 0.5px; }\n' ...
        'th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid var(--border); }\n' ...
        'tr:hover { background: #1c2128; }\n' ...
        '.sig-row { background: rgba(63, 185, 80, 0.08) !important; }\n' ...
        '.sig-row td { color: var(--green); }\n' ...
        '.badge { padding: 3px 10px; border-radius: 12px; font-size: 0.75em; font-weight: 600; }\n' ...
        '.badge-green { background: rgba(63,185,80,0.15); color: var(--green); }\n' ...
        '.badge-yellow { background: rgba(210,153,34,0.15); color: var(--yellow); }\n' ...
        '.badge-red { background: rgba(248,81,73,0.15); color: var(--red); }\n' ...
        '.stage-matrix th.rotate { height: 100px; white-space: nowrap; }\n' ...
        '.stage-matrix th.rotate > div { transform: rotate(-60deg); width: 30px; }\n' ...
        '.stage-matrix td { text-align: center; font-size: 1.1em; padding: 6px; }\n' ...
        '.stage-done { color: var(--green); font-weight: bold; }\n' ...
        '.stage-missing { color: var(--red); opacity: 0.6; }\n' ...
        '.stage-na { color: var(--muted); opacity: 0.3; }\n' ...
        '.run-section { background: var(--surface); border-radius: 12px; padding: 20px;\n' ...
        '  margin-bottom: 20px; border: 1px solid var(--border); }\n' ...
        '.run-section h3 { margin-bottom: 8px; }\n' ...
        '.run-desc { color: var(--muted); font-size: 0.9em; margin-bottom: 12px; }\n' ...
        '.conditions { margin-bottom: 12px; }\n' ...
        '.cond-tag { background: rgba(88,166,255,0.12); color: var(--accent); padding: 2px 8px;\n' ...
        '  border-radius: 6px; font-size: 0.85em; margin-right: 4px; display: inline-block; margin-bottom: 4px; }\n' ...
        '.quick-metrics { display: flex; gap: 16px; flex-wrap: wrap; margin-bottom: 12px; }\n' ...
        '.qm { background: var(--bg); padding: 4px 12px; border-radius: 6px; font-size: 0.85em;\n' ...
        '  border: 1px solid var(--border); }\n' ...
        '.fig-gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));\n' ...
        '  gap: 12px; }\n' ...
        '.fig-card { background: var(--bg); border-radius: 8px; overflow: hidden;\n' ...
        '  border: 1px solid var(--border); transition: transform 0.2s; }\n' ...
        '.fig-card:hover { transform: translateY(-2px); border-color: var(--accent); }\n' ...
        '.fig-card img { width: 100%; height: 180px; object-fit: contain; background: #fff; padding: 4px; }\n' ...
        '.fig-label { padding: 6px 10px; font-size: 0.8em; color: var(--muted); text-align: center;\n' ...
        '  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }\n' ...
        '.no-data { color: var(--muted); font-style: italic; font-size: 0.9em; }\n' ...
        '.footer { text-align: center; color: var(--muted); font-size: 0.8em; padding: 30px 0;\n' ...
        '  border-top: 1px solid var(--border); margin-top: 20px; }\n' ...
        '@media (max-width: 768px) {\n' ...
        '  .cards { flex-direction: column; }\n' ...
        '  .fig-gallery { grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); }\n' ...
        '}\n' ...
        '</style>\n'];
end
