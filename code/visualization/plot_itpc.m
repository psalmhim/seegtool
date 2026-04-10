function fig = plot_itpc(itpc, time_vec, freqs, varargin)
% PLOT_ITPC Publication-quality ITPC map.
%
%   fig = plot_itpc(itpc, time_vec, freqs)

    s = nature_style();
    p = inputParser;
    addParameter(p, 'title', 'Inter-Trial Phase Coherence');
    addParameter(p, 'threshold', []);
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    fig = figure('Name', 'ITPC', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.single_col, 2.5], ...
        'Color', s.figure.background);

    ax = axes(fig);
    imagesc(ax, time_vec, freqs, itpc);
    set(ax, 'YDir', 'normal');
    colormap(ax, nature_colormap('sequential'));
    caxis(ax, [0 1]);

    cb = colorbar(ax);
    ylabel(cb, 'ITPC', 'FontSize', s.font.colorbar);

    hold(ax, 'on');
    xline(ax, 0, '--', 'Color', [1 1 1 0.7], 'LineWidth', s.line.reference);

    % Significance threshold contour
    if ~isempty(p.Results.threshold)
        contour(ax, time_vec, freqs, itpc, [p.Results.threshold, p.Results.threshold], ...
            'Color', s.colors.black, 'LineWidth', 0.6);
    end

    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Frequency (Hz)');
    title(ax, p.Results.title);
    apply_nature_style(ax, s);
end
