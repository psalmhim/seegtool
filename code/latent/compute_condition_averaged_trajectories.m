function cond_trajectories = compute_condition_averaged_trajectories(latent_tensor, cond_indices)
% COMPUTE_CONDITION_AVERAGED_TRAJECTORIES Average trajectories per condition.
%
%   cond_trajectories = compute_condition_averaged_trajectories(latent_tensor, cond_indices)
%
%   z_bar_C(t) = (1/|C|) * sum_{k in C} z^(k)(t)
%
%   Inputs:
%       latent_tensor - trials x n_dims x time
%       cond_indices  - struct with condition names as fields, each containing trial indices
%
%   Outputs:
%       cond_trajectories - struct with condition fields, each n_dims x time

    cond_names = fieldnames(cond_indices);
    cond_trajectories = struct();

    for c = 1:numel(cond_names)
        name = cond_names{c};
        idx = cond_indices.(name);
        cond_trajectories.(name) = squeeze(mean(latent_tensor(idx, :, :), 1));
    end
end
