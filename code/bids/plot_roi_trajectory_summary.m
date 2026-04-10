function fig = plot_roi_trajectory_summary(roi_results, time_vec, varargin)
% PLOT_ROI_TRAJECTORY_SUMMARY Plot latent trajectory summary for all ROIs.
%
%   fig = plot_roi_trajectory_summary(roi_results, time_vec)
%   fig = plot_roi_trajectory_summary(..., 'dims', [1 2], 'title', 'ROI Trajectories')
%
%   Inputs:
%       roi_results - struct array from run_roi_latent_analysis
%       time_vec    - time vector in seconds
%       Name-Value:
%           'dims'  - latent dimensions to plot [default: [1 2]]
%           'title' - figure title

    p = inputParser;
    addParameter(p, 'dims', [1 2]);
    addParameter(p, 'title', 'ROI Latent Trajectory Summary');
    addParameter(p, 'style', []);
    parse(p, varargin{:});

    dims = p.Results.dims;

    % Filter to non-skipped ROIs
    valid = [];
    for i = 1:numel(roi_results)
        if ~roi_results(i).skipped && isfield(roi_results(i), 'cond_trajectories')
            valid = [valid, i];
        end
    end

    n_valid = numel(valid);
    if n_valid == 0
        warning('No valid ROI results to plot');
        fig = figure('Visible', 'off');
        return;
    end

    n_cols = min(3, n_valid);
    n_rows = ceil(n_valid / n_cols);

    fig = figure('Name', 'ROI Trajectories', ...
        'Position', [50, 50, 350*n_cols, 300*n_rows]);

    colors = lines(10);

    for vi = 1:n_valid
        idx = valid(vi);
        roi = roi_results(idx);

        subplot(n_rows, n_cols, vi);
        hold on;

        cond_traj = roi.cond_trajectories;
        cond_names = fieldnames(cond_traj);

        for c = 1:numel(cond_names)
            traj = cond_traj.(cond_names{c});
            % traj: time x latent_dims
            if size(traj, 2) >= max(dims)
                x = traj(:, dims(1));
                y = traj(:, dims(2));

                color = colors(mod(c-1, size(colors,1)) + 1, :);
                plot(x, y, '-', 'Color', color, 'LineWidth', 1.5);
                plot(x(1), y(1), 'o', 'Color', color, 'MarkerSize', 8, 'MarkerFaceColor', color);
                plot(x(end), y(end), 's', 'Color', color, 'MarkerSize', 8, 'MarkerFaceColor', color);
            end
        end

        xlabel(sprintf('Latent dim %d', dims(1)));
        ylabel(sprintf('Latent dim %d', dims(2)));
        title(sprintf('%s (%d ch, %.0f%% var)', ...
            roi.name, roi.n_channels, roi.explained_var * 100), 'FontSize', 10);
        axis equal;
        grid on;

        if vi == 1 && numel(cond_names) > 1
            legend(cond_names, 'Location', 'best', 'FontSize', 7);
        end
    end

    sgtitle(p.Results.title, 'FontSize', 13);
end
