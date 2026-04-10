function roi_results = run_roi_latent_analysis(trial_tensor, roi_groups, time_vec, events, cfg)
% RUN_ROI_LATENT_ANALYSIS Perform latent trajectory analysis per ROI.
%
%   roi_results = run_roi_latent_analysis(trial_tensor, roi_groups, time_vec, events, cfg)
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       roi_groups   - struct array from build_roi_groups
%       time_vec     - time vector in seconds
%       events       - struct array with .condition
%       cfg          - pipeline config
%
%   Output:
%       roi_results - struct array (one per ROI) with:
%           .name              - ROI name
%           .n_channels        - number of channels
%           .latent_model      - fitted latent model
%           .cond_trajectories - condition-averaged trajectories
%           .geometry          - trajectory geometry metrics
%           .explained_var     - variance explained

    n_groups = numel(roi_groups);
    n_trials = size(trial_tensor, 1);

    % Build condition indices
    condition_labels = {events.condition}';
    if numel(condition_labels) > n_trials
        condition_labels = condition_labels(1:n_trials);
    end
    [~, cond_indices] = make_condition_labels(events, 1:n_trials);

    roi_results = struct();

    for g = 1:n_groups
        roi = roi_groups(g);
        fprintf('[ROI %d/%d] %s (%d channels)\n', g, n_groups, roi.name, roi.n_channels);

        roi_results(g).name = roi.name;
        roi_results(g).n_channels = roi.n_channels;
        roi_results(g).channel_indices = roi.indices;

        if roi.n_channels < 2
            fprintf('  Skipping: too few channels for latent analysis\n');
            roi_results(g).skipped = true;
            continue;
        end

        roi_results(g).skipped = false;

        % Extract ROI channels
        roi_tensor = trial_tensor(:, roi.indices, :);

        % Build population tensor
        pop_tensor = build_population_tensor(roi_tensor, 'voltage');
        pop_tensor = normalize_population_tensor(pop_tensor, 'zscore');

        % Fit latent model
        roi_cfg = cfg;
        roi_cfg.n_latent_dims = min(cfg.n_latent_dims, roi.n_channels - 1);

        try
            model = fit_latent_model(pop_tensor, roi_cfg);
            latent_tensor = project_to_latent_space(pop_tensor, model);

            if isfield(cfg, 'smooth_kernel_ms') && cfg.smooth_kernel_ms > 0
                latent_tensor = smooth_latent_trajectories(latent_tensor, cfg.smooth_kernel_ms, cfg.fs);
            end

            cond_traj = compute_condition_averaged_trajectories(latent_tensor, cond_indices);

            roi_results(g).latent_model = model;
            roi_results(g).cond_trajectories = cond_traj;
            roi_results(g).explained_var = sum(model.explained_variance);

            % Trajectory geometry
            geom = compute_trajectory_geometry(latent_tensor, time_vec, cond_indices);
            roi_results(g).geometry = geom;

        catch ME
            fprintf('  Error in latent analysis: %s\n', ME.message);
            roi_results(g).skipped = true;
        end
    end

    n_done = sum(~[roi_results.skipped]);
    fprintf('[ROI] Completed latent analysis for %d / %d ROIs\n', n_done, n_groups);
end
