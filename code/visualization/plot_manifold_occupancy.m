function fig = plot_manifold_occupancy(occupancy, varargin)
% PLOT_MANIFOLD_OCCUPANCY Publication-quality manifold occupancy with per-condition comparison.
%
%   fig = plot_manifold_occupancy(occupancy)

    s = nature_style();
    p = inputParser;
    addParameter(p, 'title', 'Neural Manifold Occupancy');
    addParameter(p, 'cond_dims', []);
    addParameter(p, 'cond_names', {});
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    has_cond = ~isempty(p.Results.cond_dims);
    n_panels = 2 + has_cond;

    fig = figure('Name', 'Occupancy', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.single_col, 1.2 * n_panels + 0.3], ...
        'Color', s.figure.background);

    n_show = min(20, numel(occupancy.eigenvalues));
    eig_vals = occupancy.eigenvalues(1:n_show);
    cum_var = cumsum(occupancy.eigenvalues) / sum(occupancy.eigenvalues);

    % Panel a: Scree plot
    ax1 = subplot(n_panels, 1, 1);
    col = s.colors.palette(1, :);
    area(ax1, 1:n_show, eig_vals, 'FaceColor', col, 'FaceAlpha', 0.3, ...
        'EdgeColor', col, 'LineWidth', s.line.data);
    xlabel(ax1, 'Component');
    ylabel(ax1, 'Eigenvalue');
    title(ax1, sprintf('Participation Ratio = %.1f', occupancy.effective_dim));
    xlim(ax1, [1, n_show]);
    apply_nature_style(ax1, s);
    add_panel_label(ax1, 'a', s);

    % Panel b: Cumulative variance
    ax2 = subplot(n_panels, 1, 2);
    plot(ax2, 1:n_show, cum_var(1:n_show), 'o-', 'Color', col, ...
        'LineWidth', s.line.data, 'MarkerSize', 2, 'MarkerFaceColor', col);
    hold(ax2, 'on');
    yline(ax2, 0.90, '--', 'Color', s.colors.gray, 'LineWidth', s.line.reference);
    yline(ax2, 0.95, ':', 'Color', s.colors.gray, 'LineWidth', s.line.reference);
    text(ax2, n_show * 0.85, 0.91, '90%', 'FontSize', s.font.annotation, 'Color', s.colors.gray);
    text(ax2, n_show * 0.85, 0.96, '95%', 'FontSize', s.font.annotation, 'Color', s.colors.gray);
    xlabel(ax2, 'Components');
    ylabel(ax2, 'Cum. Variance');
    xlim(ax2, [1, n_show]);
    ylim(ax2, [0, 1.02]);
    apply_nature_style(ax2, s);
    add_panel_label(ax2, 'b', s);

    % Panel c: Per-condition effective dimensionality
    if has_cond
        ax3 = subplot(n_panels, 1, 3);
        cd = p.Results.cond_dims;
        cn = p.Results.cond_names;
        n_c = numel(cd);
        colors = nature_colors(n_c);

        for i = 1:n_c
            bar(ax3, i, cd(i), 'FaceColor', colors(i,:), 'EdgeColor', 'none', ...
                'BarWidth', 0.6);
            hold(ax3, 'on');
        end

        set(ax3, 'XTick', 1:n_c);
        if ~isempty(cn)
            set(ax3, 'XTickLabel', cn, 'XTickLabelRotation', 30);
        end
        ylabel(ax3, 'Eff. Dimensionality');
        apply_nature_style(ax3, s);
        add_panel_label(ax3, 'c', s);
    end

    sgtitle(p.Results.title, 'FontSize', s.font.sgtitle, 'FontName', s.font.family);
end
