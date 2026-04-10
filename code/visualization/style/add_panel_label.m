function add_panel_label(ax, label, s)
% ADD_PANEL_LABEL Add bold panel label (a, b, c...) to axes.
%
%   add_panel_label(ax, 'a')
%   add_panel_label(ax, 'a', style)

    if nargin < 3
        s = nature_style();
    end

    pos = ax.Position;
    x = pos(1) - 0.04;
    y = pos(2) + pos(4) + 0.01;

    annotation(ax.Parent, 'textbox', [x, y, 0.03, 0.03], ...
        'String', label, 'FontSize', s.font.panel_label, ...
        'FontWeight', 'bold', 'FontName', s.font.family, ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'bottom');
end
