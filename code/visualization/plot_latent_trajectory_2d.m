function fig = plot_latent_trajectory_2d(trajectories, dims, varargin)
% PLOT_LATENT_TRAJECTORY_2D Publication-quality 2D latent trajectories.
%
%   fig = plot_latent_trajectory_2d(trajectories, [1 2])
%
%   Inputs:
%       trajectories - struct with condition fields, each n_dims x time
%       dims         - [dim1, dim2] to plot
%       Name-Value:
%           'var_explained' - variance explained per dim (for axis labels)
%           'time_vec'      - time vector for time markers
%           'title'         - figure title
%           'stats'         - struct with .sig_mask for color modulation
%           'style'         - style struct

    s = nature_style();
    p = inputParser;
    addParameter(p, 'var_explained', []);
    addParameter(p, 'time_vec', []);
    addParameter(p, 'title', '');
    addParameter(p, 'stats', []);
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    fig = figure('Name', 'Trajectory_2D', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.single_col, s.figure.single_col], ...
        'Color', s.figure.background);

    ax = axes(fig);
    hold(ax, 'on');

    cond_names = fieldnames(trajectories);
    n_conds = numel(cond_names);
    colors = nature_colors(n_conds);

    for c = 1:n_conds
        traj = trajectories.(cond_names{c});
        x = traj(dims(1), :);
        y = traj(dims(2), :);
        n_t = numel(x);
        col = colors(c, :);

        % Draw trajectory with time-varying alpha using patch
        for t = 1:n_t-1
            alpha_val = 0.25 + 0.75 * (t / n_t);
            plot(ax, x(t:t+1), y(t:t+1), ...
                'Color', [col, alpha_val], 'LineWidth', s.line.mean);
        end

        % Time tick markers every 100ms
        if ~isempty(p.Results.time_vec)
            tv = p.Results.time_vec;
            tick_interval = 0.1;
            tick_times = 0:tick_interval:tv(end);
            for ti = 1:numel(tick_times)
                [~, idx] = min(abs(tv - tick_times(ti)));
                if idx <= n_t
                    plot(ax, x(idx), y(idx), '.', 'Color', col, ...
                        'MarkerSize', s.marker.significance);
                end
            end
        end

        % Onset marker (filled circle)
        plot(ax, x(1), y(1), 'o', 'Color', col, 'MarkerSize', s.marker.onset, ...
            'MarkerFaceColor', col, 'LineWidth', 0.5);

        % Endpoint marker (open square)
        plot(ax, x(end), y(end), 's', 'Color', col, 'MarkerSize', s.marker.endpoint, ...
            'MarkerFaceColor', 'none', 'LineWidth', s.line.data);
    end

    % Axis labels with variance explained
    if ~isempty(p.Results.var_explained) && numel(p.Results.var_explained) >= max(dims)
        ve = p.Results.var_explained * 100;
        xlabel(ax, sprintf('PC%d (%.1f%%)', dims(1), ve(dims(1))));
        ylabel(ax, sprintf('PC%d (%.1f%%)', dims(2), ve(dims(2))));
    else
        xlabel(ax, sprintf('PC%d', dims(1)));
        ylabel(ax, sprintf('PC%d', dims(2)));
    end

    if ~isempty(p.Results.title)
        title(ax, p.Results.title);
    end

    legend(ax, cond_names, 'Location', 'best');
    axis(ax, 'equal');
    apply_nature_style(ax, s);
end
