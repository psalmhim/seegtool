function add_significance_bar(ax, x1, x2, y, p_value, s)
% ADD_SIGNIFICANCE_BAR Draw significance bracket with stars.
%
%   add_significance_bar(ax, x1, x2, y, p_value)
%   add_significance_bar(ax, x1, x2, y, p_value, style)
%
%   Draws a horizontal bracket from x1 to x2 at height y,
%   with significance stars based on p_value.

    if nargin < 6
        s = nature_style();
    end

    if p_value >= s.sig.alpha
        return;
    end

    hold(ax, 'on');

    % Bracket
    tick_h = diff(ylim(ax)) * 0.015;
    plot(ax, [x1, x1, x2, x2], [y-tick_h, y, y, y-tick_h], ...
        'Color', s.colors.black, 'LineWidth', s.line.reference);

    % Stars
    if p_value < s.sig.thresholds(3)
        label = s.sig.labels{3};
    elseif p_value < s.sig.thresholds(2)
        label = s.sig.labels{2};
    else
        label = s.sig.labels{1};
    end

    text(ax, (x1+x2)/2, y + tick_h*0.5, label, ...
        'FontSize', s.font.annotation, 'FontName', s.font.family, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end
