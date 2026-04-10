function tubes = compute_confidence_tubes(boot_trajectories, ci_level)
% COMPUTE_CONFIDENCE_TUBES Compute confidence tubes around mean trajectory.
%
%   tubes = compute_confidence_tubes(boot_trajectories, ci_level)
%
%   Inputs:
%       boot_trajectories - n_boot x n_dims x time
%       ci_level          - confidence interval level (default: 0.95)
%
%   Outputs:
%       tubes - struct with mean, lower, upper (each n_dims x time)

    if nargin < 2, ci_level = 0.95; end

    alpha = 1 - ci_level;

    tubes.mean = squeeze(mean(boot_trajectories, 1));
    tubes.lower = squeeze(prctile(boot_trajectories, 100 * alpha / 2, 1));
    tubes.upper = squeeze(prctile(boot_trajectories, 100 * (1 - alpha / 2), 1));
    tubes.ci_level = ci_level;
end
