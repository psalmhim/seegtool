function fig = plot_contrast_summary(contrast_results, time_vec, varargin)
% PLOT_CONTRAST_SUMMARY Multi-panel figure showing all contrast results.
%
%   fig = plot_contrast_summary(contrast_results, time_vec)
%   fig = plot_contrast_summary(..., 'title', 'Task', 'style', s)
%
%   Generates a publication-quality overview of all contrasts:
%   - Left column: separation index per contrast (with significance shading)
%   - Right column: decoding accuracy per contrast (with significance shading)
%   - Bottom: summary bar showing which contrasts are significant

    s = nature_style();
    p = inputParser;
    addParameter(p, 'title', 'Contrast Analysis', @ischar);
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    n_con = numel(contrast_results);
    if n_con == 0
        fig = figure('Visible', 'off');
        return;
    end

    colors = nature_colors(n_con);

    % Figure sizing
    fw = s.figure.double_col;
    fh = min(0.9 * n_con + 1.5, s.figure.max_height);

    fig = figure('Name', 'ContrastSummary', 'Units', 'inches', ...
        'Position', [1, 1, fw, fh], 'Color', s.figure.background);

    n_rows = n_con + 1;  % +1 for summary bar

    for ci = 1:n_con
        cr = contrast_results(ci);
        col = colors(ci, :);

        % --- Left: Separation ---
        ax_sep = subplot(n_rows, 2, (ci-1)*2 + 1);
        hold(ax_sep, 'on');

        if isfield(cr, 'separation') && isfield(cr.separation, 'index')
            sep = cr.separation;
            sig_mask = sep.p_values < s.sig.alpha;
            add_significance_shading(ax_sep, sep.time_vec, sig_mask, s);
            plot(ax_sep, sep.time_vec, sep.index, 'Color', col, 'LineWidth', s.line.mean);
            xline(ax_sep, 0, '--', 'Color', s.colors.black, 'LineWidth', s.line.reference);
        end

        ylabel(ax_sep, 'Sep.', 'FontSize', s.font.tick_label);
        set(ax_sep, 'XTickLabel', []);
        xlim(ax_sep, [time_vec(1), time_vec(end)]);

        % Contrast name as row label
        text(ax_sep, time_vec(1), max(ylim(ax_sep)), ...
            ['  ' cr.contrast.name], ...
            'FontSize', s.font.annotation, 'FontName', s.font.family, ...
            'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Color', col);

        if cr.significant
            text(ax_sep, time_vec(end), max(ylim(ax_sep)), ...
                sprintf('p=%.3f ', cr.p_min), ...
                'FontSize', s.font.annotation, 'Color', s.colors.significance, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
        end

        apply_nature_style(ax_sep, s);

        % --- Right: Decoding ---
        ax_dec = subplot(n_rows, 2, (ci-1)*2 + 2);
        hold(ax_dec, 'on');

        if isfield(cr, 'decoding') && isfield(cr.decoding, 'accuracy_time')
            dec = cr.decoding;
            sig_mask = dec.p_values < s.sig.alpha;
            add_significance_shading(ax_dec, dec.time_vec, sig_mask, s);
            plot(ax_dec, dec.time_vec, dec.accuracy_time, 'Color', col, 'LineWidth', s.line.mean);
            yline(ax_dec, dec.chance_level, '--', 'Color', s.colors.gray, ...
                'LineWidth', s.line.reference);
            xline(ax_dec, 0, '--', 'Color', s.colors.black, 'LineWidth', s.line.reference);
        end

        ylabel(ax_dec, 'Acc.', 'FontSize', s.font.tick_label);
        set(ax_dec, 'XTickLabel', []);
        xlim(ax_dec, [time_vec(1), time_vec(end)]);
        apply_nature_style(ax_dec, s);
    end

    % --- Summary bar ---
    ax_bar = subplot(n_rows, 2, [n_con*2+1, n_con*2+2]);
    hold(ax_bar, 'on');

    for ci = 1:n_con
        col = colors(ci, :);
        cr = contrast_results(ci);

        if cr.significant
            bar_col = col;
            face_alpha = 0.8;
        else
            bar_col = s.colors.nonsig;
            face_alpha = 0.3;
        end

        fill(ax_bar, [ci-0.4, ci+0.4, ci+0.4, ci-0.4], ...
            [0, 0, -log10(max(cr.p_min, 1e-10)), -log10(max(cr.p_min, 1e-10))], ...
            bar_col, 'EdgeColor', 'none', 'FaceAlpha', face_alpha);
    end

    % Alpha threshold
    yline(ax_bar, -log10(0.05), '--', 'Color', s.colors.significance, ...
        'LineWidth', s.line.reference);
    text(ax_bar, n_con + 0.5, -log10(0.05), ' p=0.05', ...
        'FontSize', s.font.annotation, 'Color', s.colors.significance);

    set(ax_bar, 'XTick', 1:n_con);
    con_names = {contrast_results.contrast};
    labels = cellfun(@(c) c.name, con_names, 'UniformOutput', false);
    set(ax_bar, 'XTickLabel', labels, 'XTickLabelRotation', 30);
    ylabel(ax_bar, '-log_{10}(p)');
    xlabel(ax_bar, 'Contrast');
    xlim(ax_bar, [0.3, n_con + 0.7]);
    apply_nature_style(ax_bar, s);

    sgtitle(p.Results.title, 'FontSize', s.font.sgtitle, 'FontName', s.font.family);
end
