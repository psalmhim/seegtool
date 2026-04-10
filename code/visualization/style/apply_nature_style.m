function apply_nature_style(h, s)
% APPLY_NATURE_STYLE Apply Nature journal style to axes or figure.
%
%   apply_nature_style(ax, style)
%   apply_nature_style(fig, style)

    if nargin < 2
        s = nature_style();
    end

    if isa(h, 'matlab.ui.Figure')
        apply_to_figure(h, s);
        ax_list = findall(h, 'Type', 'axes');
        for i = 1:numel(ax_list)
            apply_to_axes(ax_list(i), s);
        end
    elseif isa(h, 'matlab.graphics.axis.Axes')
        apply_to_axes(h, s);
    end
end

function apply_to_figure(fig, s)
    set(fig, 'Color', s.figure.background);
    set(fig, 'Renderer', s.figure.renderer);
    set(fig, 'InvertHardcopy', 'off');
end

function apply_to_axes(ax, s)
    set(ax, 'FontName', s.font.family);
    set(ax, 'FontSize', s.font.tick_label);
    set(ax, 'LineWidth', s.line.axis);
    set(ax, 'TickDir', s.line.tick_dir);
    set(ax, 'TickLength', s.line.tick_length);
    set(ax, 'Box', 'off');
    set(ax, 'XGrid', 'off');
    set(ax, 'YGrid', 'off');
    set(ax, 'ZGrid', 'off');
    set(ax, 'Color', s.figure.background);

    % Style axis labels
    ax.XLabel.FontSize = s.font.axis_label;
    ax.YLabel.FontSize = s.font.axis_label;
    if isprop(ax, 'ZLabel')
        ax.ZLabel.FontSize = s.font.axis_label;
    end
    ax.Title.FontSize = s.font.title;
    ax.Title.FontWeight = 'normal';

    % Style legend if present
    lg = ax.Legend;
    if ~isempty(lg)
        set(lg, 'FontSize', s.font.legend, 'Box', 'off', 'FontName', s.font.family);
    end

    % Style colorbar if present
    cb = findobj(ax.Parent, 'Type', 'colorbar');
    for i = 1:numel(cb)
        set(cb(i), 'FontSize', s.font.colorbar, 'FontName', s.font.family);
        set(cb(i), 'TickDirection', 'out', 'LineWidth', s.line.axis);
    end
end
