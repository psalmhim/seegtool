function fig = plot_jpca_plane(jpca_results, varargin)
% PLOT_JPCA_PLANE Publication-quality jPCA rotational plane.
%
%   fig = plot_jpca_plane(jpca_results)

    s = nature_style();
    p = inputParser;
    addParameter(p, 'title', 'jPCA Rotational Dynamics');
    addParameter(p, 'style', s);
    addParameter(p, 'condition_names', {});
    parse(p, varargin{:});
    s = p.Results.style;

    fig = figure('Name', 'jPCA', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.single_col, s.figure.single_col], ...
        'Color', s.figure.background);

    ax = axes(fig);
    hold(ax, 'on');

    n_conds = numel(jpca_results.projected_trajectories);
    cond_names = p.Results.condition_names;
    if isempty(cond_names) || numel(cond_names) ~= n_conds
        cond_names = cell(1, n_conds);
        for c = 1:n_conds
            cond_names{c} = sprintf('Condition %d', c);
        end
    end
    colors = nature_colors(n_conds);

    for c = 1:n_conds
        if iscell(jpca_results.projected_trajectories)
            traj = jpca_results.projected_trajectories{c};
        else
            % Fallback just in case
            fnames = fieldnames(jpca_results.projected_trajectories);
            traj = jpca_results.projected_trajectories.(fnames{c});
        end
        col = colors(c, :);
        n_t = size(traj, 2);

        % Draw trajectory with time gradient
        for t = 1:n_t-1
            alpha_val = 0.3 + 0.7 * (t / n_t);
            plot(ax, traj(1, t:t+1), traj(2, t:t+1), ...
                'Color', [col, alpha_val], 'LineWidth', s.line.mean);
        end

        % Onset marker
        plot(ax, traj(1, 1), traj(2, 1), 'o', 'Color', col, ...
            'MarkerSize', s.marker.onset, 'MarkerFaceColor', col);

        % Direction arrows at regular intervals
        n_arrows = 3;
        arrow_idx = round(linspace(round(n_t*0.2), round(n_t*0.8), n_arrows));
        for ai = 1:numel(arrow_idx)
            idx = arrow_idx(ai);
            if idx < n_t
                dx = traj(1, idx+1) - traj(1, idx);
                dy = traj(2, idx+1) - traj(2, idx);
                scale = 3;
                quiver(ax, traj(1, idx), traj(2, idx), dx*scale, dy*scale, 0, ...
                    'Color', col, 'MaxHeadSize', 1.5, 'LineWidth', s.line.data, ...
                    'AutoScale', 'off');
            end
        end
    end

    xlabel(ax, 'jPC_1');
    ylabel(ax, 'jPC_2');
    title(ax, p.Results.title);
    legend(ax, cond_names, 'Location', 'best');
    axis(ax, 'equal');

    % Annotate R-squared
    if isfield(jpca_results, 'R2')
        text(ax, 0.02, 0.02, sprintf('R^2 = %.3f', jpca_results.R2), ...
            'Units', 'normalized', 'FontSize', s.font.annotation, ...
            'FontName', s.font.family, 'Color', s.colors.gray);
    end

    apply_nature_style(ax, s);
end
