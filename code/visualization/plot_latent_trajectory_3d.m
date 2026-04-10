function fig = plot_latent_trajectory_3d(trajectories, dims, varargin)
% PLOT_LATENT_TRAJECTORY_3D Publication-quality 3D latent trajectories.
%
%   fig = plot_latent_trajectory_3d(trajectories, [1 2 3])

    s = nature_style();
    p = inputParser;
    addParameter(p, 'var_explained', []);
    addParameter(p, 'title', '');
    addParameter(p, 'shadows', true);
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    if numel(dims) < 3
        error('Must specify 3 dimensions');
    end

    fig = figure('Name', 'Trajectory_3D', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.single_col, s.figure.single_col], ...
        'Color', s.figure.background);

    ax = axes(fig);
    hold(ax, 'on');

    cond_names = fieldnames(trajectories);
    n_conds = numel(cond_names);
    colors = nature_colors(n_conds);

    % Collect all data for shadow plane positioning
    all_x = []; all_y = []; all_z = [];
    for c = 1:n_conds
        traj = trajectories.(cond_names{c});
        all_x = [all_x, traj(dims(1), :)];
        all_y = [all_y, traj(dims(2), :)];
        all_z = [all_z, traj(dims(3), :)];
    end

    for c = 1:n_conds
        traj = trajectories.(cond_names{c});
        x = traj(dims(1), :);
        y = traj(dims(2), :);
        z = traj(dims(3), :);
        col = colors(c, :);

        % Main trajectory
        plot3(ax, x, y, z, '-', 'Color', col, 'LineWidth', s.line.mean);

        % Shadow projections
        if p.Results.shadows
            z_floor = min(all_z) - 0.1 * range(all_z);
            shadow_col = [col * 0.3 + 0.7, 0.15];
            plot3(ax, x, y, repmat(z_floor, size(z)), '-', ...
                'Color', shadow_col, 'LineWidth', 0.4);
        end

        % Onset and endpoint markers
        plot3(ax, x(1), y(1), z(1), 'o', 'Color', col, ...
            'MarkerSize', s.marker.onset, 'MarkerFaceColor', col);
        plot3(ax, x(end), y(end), z(end), 's', 'Color', col, ...
            'MarkerSize', s.marker.endpoint, 'MarkerFaceColor', 'none', ...
            'LineWidth', s.line.data);
    end

    % Axis labels
    if ~isempty(p.Results.var_explained) && numel(p.Results.var_explained) >= max(dims)
        ve = p.Results.var_explained * 100;
        xlabel(ax, sprintf('PC%d (%.1f%%)', dims(1), ve(dims(1))));
        ylabel(ax, sprintf('PC%d (%.1f%%)', dims(2), ve(dims(2))));
        zlabel(ax, sprintf('PC%d (%.1f%%)', dims(3), ve(dims(3))));
    else
        xlabel(ax, sprintf('PC%d', dims(1)));
        ylabel(ax, sprintf('PC%d', dims(2)));
        zlabel(ax, sprintf('PC%d', dims(3)));
    end

    if ~isempty(p.Results.title)
        title(ax, p.Results.title);
    end

    legend(ax, cond_names, 'Location', 'best');
    view(ax, 45, 25);
    apply_nature_style(ax, s);
end
