function add_significance_shading(ax, time_vec, sig_mask, s)
% ADD_SIGNIFICANCE_SHADING Shade time windows where results are significant.
%
%   add_significance_shading(ax, time_vec, sig_mask)
%   add_significance_shading(ax, time_vec, sig_mask, style)
%
%   Draws contiguous shaded blocks for significant periods (sig_mask = true).

    if nargin < 4
        s = nature_style();
    end

    if isempty(sig_mask) || ~any(sig_mask)
        return;
    end

    yl = ylim(ax);
    hold(ax, 'on');

    % Find contiguous blocks
    d = diff([0; sig_mask(:); 0]);
    starts = find(d == 1);
    stops = find(d == -1) - 1;

    for i = 1:numel(starts)
        t1 = time_vec(starts(i));
        t2 = time_vec(min(stops(i), numel(time_vec)));
        fill(ax, [t1, t2, t2, t1], [yl(1), yl(1), yl(2), yl(2)], ...
            s.colors.sig_shading, 'EdgeColor', 'none', 'FaceAlpha', 0.45);
    end

    % Send shading to back
    ch = get(ax, 'Children');
    n_new = numel(starts);
    if n_new > 0 && numel(ch) > n_new
        set(ax, 'Children', [ch(n_new+1:end); ch(1:n_new)]);
    end
end
