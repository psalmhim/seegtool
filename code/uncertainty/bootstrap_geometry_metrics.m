function boot_metrics = bootstrap_geometry_metrics(latent_tensor, cond_indices, n_boot, ci_level)
% BOOTSTRAP_GEOMETRY_METRICS Bootstrap geometry metrics.
%
%   boot_metrics = bootstrap_geometry_metrics(latent_tensor, cond_indices, n_boot, ci_level)
%
%   Inputs:
%       latent_tensor - trials x n_dims x time
%       cond_indices  - struct with condition trial indices
%       n_boot        - number of bootstrap iterations (default: 500)
%       ci_level      - confidence interval level (default: 0.95)
%
%   Outputs:
%       boot_metrics - struct with bootstrap distributions and CIs

    if nargin < 3, n_boot = 500; end
    if nargin < 4, ci_level = 0.95; end

    cond_names = fieldnames(cond_indices);
    boot_metrics = struct();

    for c = 1:numel(cond_names)
        name = cond_names{c};
        idx = cond_indices.(name);
        n_trials = numel(idx);

        boot_path_length = zeros(n_boot, 1);

        for b = 1:n_boot
            boot_idx = idx(randi(n_trials, n_trials, 1));
            boot_traj = squeeze(mean(latent_tensor(boot_idx, :, :), 1));
            boot_path_length(b) = compute_path_length(boot_traj);
        end

        alpha = 1 - ci_level;
        boot_metrics.path_length.(name).values = boot_path_length;
        boot_metrics.path_length.(name).mean = mean(boot_path_length);
        boot_metrics.path_length.(name).ci = [prctile(boot_path_length, 100*alpha/2), ...
                                               prctile(boot_path_length, 100*(1-alpha/2))];
    end

    % Bootstrap inter-condition distance if two conditions
    if numel(cond_names) >= 2
        idx_A = cond_indices.(cond_names{1});
        idx_B = cond_indices.(cond_names{2});
        n_A = numel(idx_A);
        n_B = numel(idx_B);
        n_time = size(latent_tensor, 3);

        boot_dist = zeros(n_boot, n_time);
        for b = 1:n_boot
            bA = idx_A(randi(n_A, n_A, 1));
            bB = idx_B(randi(n_B, n_B, 1));
            cent_A = squeeze(mean(latent_tensor(bA, :, :), 1));
            cent_B = squeeze(mean(latent_tensor(bB, :, :), 1));
            for t = 1:n_time
                boot_dist(b, t) = norm(cent_A(:, t) - cent_B(:, t));
            end
        end

        alpha = 1 - ci_level;
        boot_metrics.distance.values = boot_dist;
        boot_metrics.distance.mean = mean(boot_dist, 1);
        boot_metrics.distance.ci_lower = prctile(boot_dist, 100*alpha/2, 1);
        boot_metrics.distance.ci_upper = prctile(boot_dist, 100*(1-alpha/2), 1);
    end
end
