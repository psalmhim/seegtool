function fig = plot_condition_separation(sep_index, p_values, time_vec, varargin)
% PLOT_CONDITION_SEPARATION Publication-quality condition separation with significance.
%
%   fig = plot_condition_separation(sep_index, p_values, time_vec)
%
%   Name-Value:
%       'ci'        - [2 x T] lower and upper CI bounds
%       'null_mean' - mean of null distribution (chance level)
%       'title'     - figure title
%       'style'     - style struct

    s = nature_style();
    p = inputParser;
    addParameter(p, 'ci', []);
    addParameter(p, 'null_mean', []);
    addParameter(p, 'title', 'Condition Separation');
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    fig = figure('Name', 'Separation', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.double_col, 2.8], ...
        'Color', s.figure.background);

    % --- Panel a: Separation index ---
    ax1 = subplot(5, 1, 1:4);
    hold(ax1, 'on');

    sig_mask = p_values < s.sig.alpha;

    % Significance shading
    add_significance_shading(ax1, time_vec, sig_mask, s);

    % CI ribbon
    col = s.colors.palette(1, :);
    if ~isempty(p.Results.ci)
        ci = p.Results.ci;
        fill(ax1, [time_vec, fliplr(time_vec)], ...
            [ci(1,:), fliplr(ci(2,:))], ...
            col, 'EdgeColor', 'none', 'FaceAlpha', s.colors.ci_alpha);
    end

    % Mean trace
    plot(ax1, time_vec, sep_index, 'Color', col, 'LineWidth', s.line.mean);

    % Chance level
    if ~isempty(p.Results.null_mean)
        yline(ax1, p.Results.null_mean, '--', 'Color', s.colors.gray, ...
            'LineWidth', s.line.reference);
    end

    % Stimulus onset
    xline(ax1, 0, '--', 'Color', s.colors.black, 'LineWidth', s.line.reference);

    % Peak annotation
    [peak_val, peak_idx] = max(sep_index);
    peak_t = time_vec(peak_idx);
    plot(ax1, peak_t, peak_val, 'v', 'Color', s.colors.significance, ...
        'MarkerSize', s.marker.size, 'MarkerFaceColor', s.colors.significance);
    text(ax1, peak_t, peak_val * 1.08, ...
        sprintf('%.2f @ %.0fms', peak_val, peak_t*1000), ...
        'FontSize', s.font.annotation, 'FontName', s.font.family, ...
        'HorizontalAlignment', 'center', 'Color', s.colors.significance);

    ylabel(ax1, 'Separation Index');
    title(ax1, p.Results.title);
    set(ax1, 'XTickLabel', []);
    xlim(ax1, [time_vec(1), time_vec(end)]);
    apply_nature_style(ax1, s);

    % --- Panel b: p-value strip ---
    ax2 = subplot(5, 1, 5);
    hold(ax2, 'on');

    log_p = -log10(max(p_values, 1e-10));
    imagesc(ax2, time_vec, 1, log_p(:)');
    colormap(ax2, nature_colormap('thermal'));
    caxis(ax2, [0, max(4, max(log_p))]);
    set(ax2, 'YTick', []);

    % Alpha threshold line
    alpha_line = -log10(s.sig.alpha);
    hold(ax2, 'on');

    xlabel(ax2, 'Time (s)');
    ylabel(ax2, '-log_{10}(p)');
    xlim(ax2, [time_vec(1), time_vec(end)]);
    apply_nature_style(ax2, s);

    % Panel labels
    add_panel_label(ax1, 'a', s);
    add_panel_label(ax2, 'b', s);
end
