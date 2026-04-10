function model = fit_pca_model(data_matrix, n_dims)
% FIT_PCA_MODEL Fit PCA model via eigendecomposition.
%
%   model = fit_pca_model(data_matrix, n_dims)
%
%   Inputs:
%       data_matrix - channels x time
%       n_dims      - number of principal components to retain
%
%   Outputs:
%       model - struct with W, eigenvalues, explained_variance, mean_vec

    % Replace NaN with 0 for robust PCA
    nan_mask = isnan(data_matrix);
    if any(nan_mask(:))
        fprintf('[PCA] Replacing %d NaN values (%.2f%%) with 0\n', ...
            sum(nan_mask(:)), 100 * sum(nan_mask(:)) / numel(data_matrix));
        data_matrix(nan_mask) = 0;
    end

    model.mean_vec = mean(data_matrix, 2);
    centered = data_matrix - model.mean_vec;

    cov_matrix = (centered * centered') / (size(centered, 2) - 1);

    [V, D] = eig(cov_matrix, 'vector');
    [D, sort_idx] = sort(D, 'descend');
    V = V(:, sort_idx);

    % Clamp negative eigenvalues (numerical noise) to 0
    D(D < 0) = 0;

    n_dims = min(n_dims, numel(D));
    model.W = V(:, 1:n_dims);
    model.eigenvalues = D;
    total_var = sum(D);
    if total_var == 0, total_var = 1; end
    model.explained_variance = D(1:n_dims) / total_var;
    model.cumulative_variance = cumsum(D) / total_var;
    model.n_dims = n_dims;
    model.method = 'pca';
end
