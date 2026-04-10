function fig = plot_tangent_angles(angles, time_vec, varargin)
% PLOT_TANGENT_ANGLES Publication-quality tangent space principal angles.
%
%   fig = plot_tangent_angles(angles, time_vec)

    s = nature_style();
    p = inputParser;
    addParameter(p, 'ci', []);
    addParameter(p, 'p_values', []);
    addParameter(p, 'title', 'Tangent Space Principal Angles');
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    fig = figure('Name', 'Tangent', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.single_col, 2.2], ...
        'Color', s.figure.background);

    ax = axes(fig);
    hold(ax, 'on');

    col = s.colors.palette(1, :);

    % Significance shading
    if ~isempty(p.Results.p_values)
        sig_mask = p.Results.p_values < s.sig.alpha;
        add_significance_shading(ax, time_vec, sig_mask, s);
    end

    % CI ribbon
    if ~isempty(p.Results.ci)
        ci = p.Results.ci;
        fill(ax, [time_vec, fliplr(time_vec)], ...
            rad2deg([ci(1,:), fliplr(ci(2,:))]), ...
            col, 'EdgeColor', 'none', 'FaceAlpha', s.colors.ci_alpha);
    end

    % Mean angles
    plot(ax, time_vec, rad2deg(angles), 'Color', col, 'LineWidth', s.line.mean);

    % Reference lines
    yline(ax, 90, ':', 'Color', s.colors.gray, 'LineWidth', s.line.reference);
    xline(ax, 0, '--', 'Color', s.colors.black, 'LineWidth', s.line.reference);

    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Principal Angle (\circ)');
    title(ax, p.Results.title);
    ylim(ax, [0, 95]);
    xlim(ax, [time_vec(1), time_vec(end)]);
    apply_nature_style(ax, s);
end
