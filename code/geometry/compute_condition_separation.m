function separation = compute_condition_separation(latent_tensor, cond_indices, time_vec)
% COMPUTE_CONDITION_SEPARATION Main condition separation analysis.
    separation = struct();
    separation.centroids = compute_condition_centroids(latent_tensor, cond_indices);
    cond_names = fieldnames(cond_indices);
    if numel(cond_names) >= 2
        [separation.euclidean, separation.mahal] = compute_intercondition_distance(...
            separation.centroids.(cond_names{1}), separation.centroids.(cond_names{2}));
        [separation.index, separation.p_values] = compute_time_resolved_separation(...
            latent_tensor, cond_indices, 1000);
    end
    separation.time_vec = time_vec;
end
