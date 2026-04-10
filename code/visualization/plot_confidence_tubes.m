function fig = plot_confidence_tubes(mean_traj, ci_lower, ci_upper, dims, time_vec, varargin)
% PLOT_CONFIDENCE_TUBES Publication-quality trajectory confidence tubes.
%
%   fig = plot_confidence_tubes(mean_traj, ci_lower, ci_upper, [1 2], time_vec)
%
%   Highlights where condition CIs do NOT overlap (significant divergence).

    s = nature_style();
    p = inputParser;
    addParameter(p, 'conditions', {});
    addParameter(p, 'title', 'Trajectory Confidence Intervals');
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    fig = figure('Name', 'CI_Tubes', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.single_col, s.figure.single_col], ...
        'Color', s.figure.background);

    ax = axes(fig);
    hold(ax, 'on');

    if iscell(mean_traj)
        n_conds = numel(mean_traj);
        colors = nature_colors(n_conds);

        for c = 1:n_conds
            col = colors(c, :);
            mt = mean_traj{c};
            cl = ci_lower{c};
            cu = ci_upper{c};

            x_lo = cl(dims(1), :); x_hi = cu(dims(1), :);
            y_lo = cl(dims(2), :); y_hi = cu(dims(2), :);
            x_m = mt(dims(1), :);  y_m = mt(dims(2), :);

            % CI tube
            fill(ax, [x_lo, fliplr(x_hi)], [y_lo, fliplr(y_hi)], ...
                col, 'FaceAlpha', s.colors.tube_alpha, 'EdgeColor', [col, 0.3], ...
                'LineWidth', 0.3);

            % Mean trajectory
            plot(ax, x_m, y_m, 'Color', col, 'LineWidth', s.line.mean);

            % Markers
            plot(ax, x_m(1), y_m(1), 'o', 'Color', col, ...
                'MarkerSize', s.marker.onset, 'MarkerFaceColor', col);
            plot(ax, x_m(end), y_m(end), 's', 'Color', col, ...
                'MarkerSize', s.marker.endpoint, 'MarkerFaceColor', 'none', ...
                'LineWidth', s.line.data);
        end

        % Highlight non-overlapping regions (for 2 conditions)
        if n_conds == 2
            mt1 = mean_traj{1}; mt2 = mean_traj{2};
            cu1 = ci_upper{1}; cl1 = ci_lower{1};
            cu2 = ci_upper{2}; cl2 = ci_lower{2};

            for d = dims
                non_overlap = cl1(d,:) > cu2(d,:) | cl2(d,:) > cu1(d,:);
                if any(non_overlap)
                    x1 = mt1(dims(1), non_overlap);
                    y1 = mt1(dims(2), non_overlap);
                    plot(ax, x1, y1, '.', 'Color', s.colors.significance, ...
                        'MarkerSize', s.marker.significance + 2);
                end
            end
        end

        if ~isempty(p.Results.conditions)
            legend(ax, p.Results.conditions, 'Location', 'best');
        end
    else
        col = s.colors.palette(1, :);
        x_m = mean_traj(dims(1), :); y_m = mean_traj(dims(2), :);
        x_lo = ci_lower(dims(1), :); y_lo = ci_lower(dims(2), :);
        x_hi = ci_upper(dims(1), :); y_hi = ci_upper(dims(2), :);

        fill(ax, [x_lo, fliplr(x_hi)], [y_lo, fliplr(y_hi)], ...
            col, 'FaceAlpha', s.colors.tube_alpha, 'EdgeColor', 'none');
        plot(ax, x_m, y_m, 'Color', col, 'LineWidth', s.line.mean);
    end

    xlabel(ax, sprintf('PC%d', dims(1)));
    ylabel(ax, sprintf('PC%d', dims(2)));
    title(ax, p.Results.title);
    axis(ax, 'equal');
    apply_nature_style(ax, s);
end
