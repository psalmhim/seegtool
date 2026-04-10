function [latex_sec, md_sec] = format_contrast_report(contrast_results, task_name)
% FORMAT_CONTRAST_REPORT Generate LaTeX and Markdown sections for contrast results.
%
%   [latex_sec, md_sec] = format_contrast_report(contrast_results, task_name)
%
%   Creates formatted report sections summarizing all contrast results,
%   with emphasis on significant condition-dependent effects.

    n_con = numel(contrast_results);
    if n_con == 0
        latex_sec = '';
        md_sec = '';
        return;
    end

    %% LaTeX
    lx = {};
    lx{end+1} = '\subsubsection*{Contrast Analysis}';
    lx{end+1} = sprintf('%d contrasts tested for %s:', n_con, task_name);

    % Table
    lx{end+1} = '\begin{table}[H]\centering';
    lx{end+1} = '\begin{tabular}{@{}l r r r l@{}}';
    lx{end+1} = '\toprule';
    lx{end+1} = 'Contrast & Sep. & $p_{\min}$ & Acc. (\%) & Significant \\';
    lx{end+1} = '\midrule';

    for ci = 1:n_con
        cr = contrast_results(ci);
        name = strrep(cr.contrast.name, '_', '\_');
        name = strrep(name, '>', '$>$');

        sep_val = NaN;
        if isfield(cr, 'separation') && isfield(cr.separation, 'index')
            sep_val = max(cr.separation.index);
        end

        acc_val = NaN;
        if isfield(cr, 'decoding') && isfield(cr.decoding, 'accuracy_time')
            acc_val = max(cr.decoding.accuracy_time) * 100;
        end

        if cr.significant
            stars = p_to_stars(cr.p_min);
            lx{end+1} = sprintf(['\\textcolor{sigcolor}{\\textbf{%s}} & ', ...
                '\\textcolor{sigcolor}{\\textbf{%.2f}} & ', ...
                '\\textcolor{sigcolor}{\\textbf{%.4f}}$^{%s}$ & ', ...
                '%.1f & \\textcolor{sigcolor}{YES} \\\\'], ...
                name, sep_val, cr.p_min, stars, acc_val);
        else
            lx{end+1} = sprintf('%s & %.2f & %.4f & %.1f & no \\\\', ...
                name, sep_val, cr.p_min, acc_val);
        end
    end

    lx{end+1} = '\bottomrule';
    lx{end+1} = '\end{tabular}';
    lx{end+1} = '\end{table}';

    % Significant contrast details
    n_sig = sum([contrast_results.significant]);
    if n_sig > 0
        lx{end+1} = sprintf(['\\textcolor{sigcolor}{\\textbf{%d/%d contrasts significant.}} ', ...
            'Significant time windows:'], n_sig, n_con);
        lx{end+1} = '\begin{itemize}';
        for ci = 1:n_con
            cr = contrast_results(ci);
            if ~cr.significant; continue; end
            name = strrep(cr.contrast.name, '_', '\_');
            win_str = format_windows_latex(cr.sig_windows);
            lx{end+1} = sprintf('\\item \\textbf{%s}: %s ($p_{\\min}$ = %.4f)', ...
                name, win_str, cr.p_min);
        end
        lx{end+1} = '\end{itemize}';
    end

    latex_sec = strjoin(lx, '\n');

    %% Markdown
    md = {};
    md{end+1} = '#### Contrast Analysis';
    md{end+1} = sprintf('%d contrasts tested for %s:', n_con, task_name);
    md{end+1} = '';
    md{end+1} = '| Contrast | Separation | p-value | Accuracy (%) | Significant |';
    md{end+1} = '|----------|----------:|--------:|-------------:|:-----------:|';

    for ci = 1:n_con
        cr = contrast_results(ci);
        name = cr.contrast.name;

        sep_val = NaN;
        if isfield(cr, 'separation') && isfield(cr.separation, 'index')
            sep_val = max(cr.separation.index);
        end

        acc_val = NaN;
        if isfield(cr, 'decoding') && isfield(cr.decoding, 'accuracy_time')
            acc_val = max(cr.decoding.accuracy_time) * 100;
        end

        if cr.significant
            stars = p_to_stars(cr.p_min);
            md{end+1} = sprintf('| **%s** | **%.2f** | **%.4f%s** | %.1f | **YES** |', ...
                name, sep_val, cr.p_min, stars, acc_val);
        else
            md{end+1} = sprintf('| %s | %.2f | %.4f | %.1f | no |', ...
                name, sep_val, cr.p_min, acc_val);
        end
    end

    if n_sig > 0
        md{end+1} = '';
        md{end+1} = sprintf('**%d/%d contrasts significant.** Time windows:', n_sig, n_con);
        for ci = 1:n_con
            cr = contrast_results(ci);
            if ~cr.significant; continue; end
            win_str = format_windows_md(cr.sig_windows);
            md{end+1} = sprintf('- **%s**: %s (p = %.4f)', ...
                cr.contrast.name, win_str, cr.p_min);
        end
    end

    md_sec = strjoin(md, '\n');
end


function stars = p_to_stars(p)
    if isnan(p); stars = ''; return; end
    if p < 0.001; stars = '***';
    elseif p < 0.01; stars = '**';
    elseif p < 0.05; stars = '*';
    else; stars = ''; end
end


function s = format_windows_latex(windows)
    if isempty(windows)
        s = 'no significant windows';
        return;
    end
    parts = {};
    for w = 1:numel(windows)
        parts{w} = sprintf('%.0f--%.0f~ms', windows{w}(1), windows{w}(2));
    end
    s = strjoin(parts, ', ');
end


function s = format_windows_md(windows)
    if isempty(windows)
        s = 'no significant windows';
        return;
    end
    parts = {};
    for w = 1:numel(windows)
        parts{w} = sprintf('%.0f-%.0f ms', windows{w}(1), windows{w}(2));
    end
    s = strjoin(parts, ', ');
end
