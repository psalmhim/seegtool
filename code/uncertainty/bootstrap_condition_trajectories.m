function [boot_trajectories, ci_lower, ci_upper] = bootstrap_condition_trajectories(latent_tensor, trial_indices, n_boot, ci_level)
% BOOTSTRAP_CONDITION_TRAJECTORIES Bootstrap condition-averaged trajectories.
%
%   [boot_trajectories, ci_lower, ci_upper] = bootstrap_condition_trajectories(latent_tensor, trial_indices, n_boot, ci_level)
%
%   Inputs:
%       latent_tensor - trials x n_dims x time
%       trial_indices - indices of trials for this condition
%       n_boot        - number of bootstrap iterations (default: 500)
%       ci_level      - confidence interval level (default: 0.95)
%
%   Outputs:
%       boot_trajectories - n_boot x n_dims x time
%       ci_lower          - n_dims x time lower CI bound
%       ci_upper          - n_dims x time upper CI bound

    if nargin < 3, n_boot = 500; end
    if nargin < 4, ci_level = 0.95; end

    n_trials = numel(trial_indices);
    n_dims = size(latent_tensor, 2);
    n_time = size(latent_tensor, 3);

    boot_trajectories = zeros(n_boot, n_dims, n_time);

    for b = 1:n_boot
        boot_idx = trial_indices(randi(n_trials, n_trials, 1));
        boot_trajectories(b, :, :) = squeeze(mean(latent_tensor(boot_idx, :, :), 1));
    end

    alpha = 1 - ci_level;
    ci_lower = squeeze(prctile(boot_trajectories, 100 * alpha / 2, 1));
    ci_upper = squeeze(prctile(boot_trajectories, 100 * (1 - alpha / 2), 1));
end
