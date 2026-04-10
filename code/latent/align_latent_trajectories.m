function aligned = align_latent_trajectories(latent_tensor, reference)
% ALIGN_LATENT_TRAJECTORIES Align trajectories via Procrustes to reference.
%
%   aligned = align_latent_trajectories(latent_tensor, reference)
%
%   Inputs:
%       latent_tensor - trials x n_dims x time
%       reference     - n_dims x time reference trajectory
%
%   Outputs:
%       aligned - aligned latent tensor, same size

    [n_trials, n_dims, n_time] = size(latent_tensor);
    aligned = zeros(size(latent_tensor));

    ref = reference';  % time x n_dims

    for k = 1:n_trials
        traj = squeeze(latent_tensor(k, :, :))';  % time x n_dims

        % Procrustes: find optimal rotation
        [U, ~, V] = svd(ref' * traj);
        R = V * U';

        aligned(k, :, :) = (traj * R)';
    end
end
