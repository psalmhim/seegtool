function path_len = compute_path_length(trajectory)
% COMPUTE_PATH_LENGTH Total path length: L = sum ||z(t+1) - z(t)||
    diffs = diff(trajectory, 1, 2);
    path_len = sum(sqrt(sum(diffs.^2, 1)));
end
