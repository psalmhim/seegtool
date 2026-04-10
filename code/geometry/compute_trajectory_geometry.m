function geom = compute_trajectory_geometry(latent_tensor, time_vec, cond_indices)
% COMPUTE_TRAJECTORY_GEOMETRY Main geometry analysis pipeline.
    dt = time_vec(2) - time_vec(1);
    cond_names = fieldnames(cond_indices);
    geom = struct();
    geom.centroids = compute_condition_centroids(latent_tensor, cond_indices);
    for c = 1:numel(cond_names)
        name = cond_names{c};
        traj = geom.centroids.(name);
        [geom.velocity.(name), geom.speed.(name)] = compute_velocity(traj, dt);
        geom.curvature.(name) = compute_curvature(traj, dt);
        geom.path_length.(name) = compute_path_length(traj);
        geom.dispersion.(name) = compute_dispersion(latent_tensor(cond_indices.(name), :, :), traj);
    end
    if numel(cond_names) >= 2
        [geom.euclidean_dist, geom.mahal_dist] = compute_intercondition_distance(...
            geom.centroids.(cond_names{1}), geom.centroids.(cond_names{2}));
        [geom.separation_index, geom.separation_pval] = compute_time_resolved_separation(...
            latent_tensor, cond_indices, 1000);
    end
end
