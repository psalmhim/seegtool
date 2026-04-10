function centroids = compute_condition_centroids(latent_tensor, cond_indices)
% COMPUTE_CONDITION_CENTROIDS Centroid trajectory per condition.
    cond_names = fieldnames(cond_indices);
    centroids = struct();
    for c = 1:numel(cond_names)
        name = cond_names{c};
        idx = cond_indices.(name);
        centroids.(name) = squeeze(mean(latent_tensor(idx, :, :), 1));
    end
end
