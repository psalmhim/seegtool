function boot_results = bootstrap_trajectory_uncertainty(latent_tensor, cond_indices, n_boot, ci_level)
% BOOTSTRAP_TRAJECTORY_UNCERTAINTY Main bootstrap uncertainty analysis.
%
%   boot_results = bootstrap_trajectory_uncertainty(latent_tensor, cond_indices, n_boot, ci_level)
%
%   Inputs:
%       latent_tensor - trials x n_dims x time
%       cond_indices  - struct with condition trial indices
%       n_boot        - number of bootstrap iterations (default: 500)
%       ci_level      - confidence interval level (default: 0.95)
%
%   Outputs:
%       boot_results - struct with bootstrap distributions and CIs

    if nargin < 3, n_boot = 500; end
    if nargin < 4, ci_level = 0.95; end

    boot_results = struct();
    cond_names = fieldnames(cond_indices);

    % Bootstrap trajectories for each condition
    for c = 1:numel(cond_names)
        name = cond_names{c};
        idx = cond_indices.(name);
        [bt, ci_lo, ci_up] = bootstrap_condition_trajectories(latent_tensor, idx, n_boot, ci_level);
        boot_results.trajectories.(name) = bt;
        boot_results.tubes.(name) = compute_confidence_tubes(bt, ci_level);
    end

    % Bootstrap geometry metrics
    fprintf('[Bootstrap] Computing geometry metrics uncertainty...\n');
    boot_results.geometry = bootstrap_geometry_metrics(latent_tensor, cond_indices, n_boot, ci_level);

    fprintf('[Bootstrap] Uncertainty quantification complete.\n');
end
