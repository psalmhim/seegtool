function [latex_str, csv_str, md_str] = write_stats_table(all_results, runs)
% WRITE_STATS_TABLE Generate condition discrimination summary tables.
%
%   [latex_str, csv_str, md_str] = write_stats_table(all_results, runs)
%
%   Loads actual results from stage files on disk (not summary struct).
%   Tables include: peak separation, p-values (with significance stars),
%   peak decoding accuracy, onset latency, effective dimensionality, jPCA R2,
%   contrasts, TF clusters, MVPA accuracy.

    header = {'Task', 'Trials', 'Conds', 'PeakSep', 'p_min', 'Sig', ...
              'PeakAcc(%)', 'OnsetMs', 'EffDim', 'jPCA_R2', 'Contrasts', 'TFClust', 'MVPA(%)'};

    rows = {};
    for r = 1:numel(runs)
        run_id = sprintf('%s_%s_run-%s', runs(r).session, runs(r).task, runs(r).run);
        field = matlab.lang.makeValidName(run_id);

        if ~isfield(all_results, field); continue; end
        res = all_results.(field);
        if ~isfield(res, 'success') || ~res.success; continue; end

        row = struct();
        row.task = runs(r).task;
        row.trials = res.n_trials;
        row.conditions = numel(res.conditions);

        % Load metrics from stage files
        m = load_task_metrics(res.run_output);
        row.peak_sep = m.peak_sep;
        row.sep_p = m.min_p;
        row.peak_acc = m.peak_acc;
        row.onset_ms = m.onset_ms;
        row.eff_dim = m.eff_dim;
        row.jpca_r2 = m.jpca_r2;
        row.contrasts_str = sprintf('%d/%d', m.n_sig_contrasts, m.n_total_contrasts);
        row.n_tf_clusters = m.n_tf_clusters;
        row.tf_mvpa_acc = m.tf_mvpa_acc;

        rows{end+1} = row;
    end

    %% LaTeX
    latex_lines = {};
    for i = 1:numel(rows)
        r = rows{i};
        is_sig = ~isnan(r.sep_p) && r.sep_p < 0.05;
        stars = p_to_stars_latex(r.sep_p);

        acc_str = format_nan(r.peak_acc * 100, '%.1f');
        onset_str = format_nan(r.onset_ms, '%.0f');
        dim_str = format_nan(r.eff_dim, '%.1f');
        r2_str = format_nan(r.jpca_r2, '%.3f');

        if is_sig
            latex_lines{end+1} = sprintf(['\\textcolor{sigcolor}{\\textbf{%s}} & ', ...
                '\\textcolor{sigcolor}{\\textbf{%.2f}} & ', ...
                '\\textcolor{sigcolor}{\\textbf{%.4f}}$^{%s}$ & ', ...
                '%s & %s & %s & %s \\\\'], ...
                r.task, r.peak_sep, r.sep_p, stars, ...
                acc_str, onset_str, dim_str, r2_str);
        else
            latex_lines{end+1} = sprintf(['%s & %.2f & %.4f & ', ...
                '%s & %s & %s & %s \\\\'], ...
                r.task, r.peak_sep, r.sep_p, ...
                acc_str, onset_str, dim_str, r2_str);
        end
    end
    latex_str = strjoin(latex_lines, '\n');

    %% CSV
    csv_lines = {strjoin(header, ',')};
    for i = 1:numel(rows)
        r = rows{i};
        is_sig = ~isnan(r.sep_p) && r.sep_p < 0.05;
        csv_lines{end+1} = sprintf('%s,%d,%d,%.4f,%.6f,%s,%.4f,%.1f,%.2f,%.4f,%s,%d,%.4f', ...
            r.task, r.trials, r.conditions, r.peak_sep, r.sep_p, ...
            bool_to_str(is_sig), r.peak_acc, r.onset_ms, r.eff_dim, r.jpca_r2, ...
            r.contrasts_str, r.n_tf_clusters, r.tf_mvpa_acc);
    end
    csv_str = strjoin(csv_lines, '\n');

    %% Markdown
    md_lines = {};
    for i = 1:numel(rows)
        r = rows{i};
        is_sig = ~isnan(r.sep_p) && r.sep_p < 0.05;
        stars = p_to_stars_md(r.sep_p);

        acc_str = format_nan(r.peak_acc * 100, '%.1f');
        onset_str = format_nan(r.onset_ms, '%.0f');
        dim_str = format_nan(r.eff_dim, '%.1f');
        r2_str = format_nan(r.jpca_r2, '%.3f');
        mvpa_str = format_nan(r.tf_mvpa_acc * 100, '%.1f');

        if is_sig
            md_lines{end+1} = sprintf('| **%s** | **%.2f** | **%.4f%s** | %s | %s | %s | %s |', ...
                r.task, r.peak_sep, r.sep_p, stars, acc_str, onset_str, dim_str, r2_str);
        else
            md_lines{end+1} = sprintf('| %s | %.2f | %.4f | %s | %s | %s | %s |', ...
                r.task, r.peak_sep, r.sep_p, acc_str, onset_str, dim_str, r2_str);
        end
    end
    md_str = strjoin(md_lines, '\n');
end


function stars = p_to_stars_latex(p)
    if isnan(p); stars = ''; return; end
    if p < 0.001; stars = '***';
    elseif p < 0.01; stars = '**';
    elseif p < 0.05; stars = '*';
    else; stars = ''; end
end


function stars = p_to_stars_md(p)
    if isnan(p); stars = ''; return; end
    if p < 0.001; stars = '***';
    elseif p < 0.01; stars = '**';
    elseif p < 0.05; stars = '*';
    else; stars = ''; end
end


function s = format_nan(val, fmt)
    if isnan(val)
        s = '--';
    else
        s = sprintf(fmt, val);
    end
end


function s = bool_to_str(b)
    if b; s = 'YES'; else; s = 'NO'; end
end
