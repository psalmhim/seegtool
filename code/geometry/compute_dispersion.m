function dispersion = compute_dispersion(latent_tensor, mean_trajectory)
% COMPUTE_DISPERSION Trial-to-trial dispersion around mean trajectory.
%   D(t) = (1/K) * sum_k ||z^(k)(t) - z_bar(t)||
    n_trials = size(latent_tensor, 1);
    n_time = size(latent_tensor, 3);
    dispersion = zeros(1, n_time);
    for t = 1:n_time
        dists = zeros(n_trials, 1);
        for k = 1:n_trials
            dists(k) = norm(squeeze(latent_tensor(k, :, t))' - mean_trajectory(:, t));
        end
        dispersion(t) = mean(dists);
    end
end
