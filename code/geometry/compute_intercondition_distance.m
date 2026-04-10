function [dist_euclidean, dist_mahal] = compute_intercondition_distance(centroid_A, centroid_B, cov_matrix)
% COMPUTE_INTERCONDITION_DISTANCE Euclidean and Mahalanobis distance.
    n_time = size(centroid_A, 2);
    dist_euclidean = zeros(1, n_time);
    dist_mahal = zeros(1, n_time);
    if nargin < 3 || isempty(cov_matrix)
        cov_matrix = eye(size(centroid_A, 1));
    end
    cov_inv = pinv(cov_matrix);
    for t = 1:n_time
        diff_vec = centroid_A(:, t) - centroid_B(:, t);
        dist_euclidean(t) = norm(diff_vec);
        dist_mahal(t) = sqrt(diff_vec' * cov_inv * diff_vec);
    end
end
