function model = fit_factor_analysis_model(data_matrix, n_factors)
% FIT_FACTOR_ANALYSIS_MODEL Fit factor analysis via EM algorithm.
%
%   model = fit_factor_analysis_model(data_matrix, n_factors)
%
%   Model: x(t) = W*z(t) + epsilon, epsilon ~ N(0, diag(Psi))
%
%   Inputs:
%       data_matrix - channels x time
%       n_factors   - number of latent factors
%
%   Outputs:
%       model - struct with W, Psi, mean_vec

    [n_channels, n_time] = size(data_matrix);
    model.mean_vec = mean(data_matrix, 2);
    centered = data_matrix - model.mean_vec;

    cov_matrix = (centered * centered') / (n_time - 1);

    % Initialize with PCA
    [V, D] = eig(cov_matrix, 'vector');
    [D, sort_idx] = sort(D, 'descend');
    V = V(:, sort_idx);

    n_factors = min(n_factors, n_channels);
    W = V(:, 1:n_factors) * diag(sqrt(max(D(1:n_factors), 0)));
    Psi = diag(cov_matrix) - sum(W.^2, 2);
    Psi = max(Psi, 1e-6);

    % EM iterations
    max_iter = 100;
    tol = 1e-6;

    for iter = 1:max_iter
        W_old = W;

        % E-step
        Psi_inv = diag(1 ./ Psi);
        M = W' * Psi_inv * W + eye(n_factors);
        M_inv = inv(M);
        Ez = M_inv * W' * Psi_inv * centered;
        Ezz = n_time * M_inv + Ez * Ez';

        % M-step
        W = (centered * Ez') / Ezz;
        Psi = diag(cov_matrix) - sum(W .* (centered * Ez' / n_time), 2);
        Psi = max(Psi, 1e-6);

        % Check convergence
        if max(abs(W(:) - W_old(:))) < tol
            break;
        end
    end

    model.W = W;
    model.Psi = Psi;
    model.n_factors = n_factors;
    model.n_iter = iter;
    model.method = 'fa';
end
