function result = compute_state_space_occupancy(latent_tensor)
% COMPUTE_STATE_SPACE_OCCUPANCY Compute state space occupancy metrics.
%
%   result = compute_state_space_occupancy(latent_tensor)
%
%   Computes the covariance of latent states, its eigenvalues, and the
%   effective dimensionality via the participation ratio.
%
%   Inputs:
%       latent_tensor - [n_trials x n_dims x n_time] tensor of latent states
%
%   Outputs:
%       result - struct with fields:
%           .covariance              - [n_dims x n_dims] covariance matrix
%           .eigenvalues             - [n_dims x 1] sorted eigenvalues (descending)
%           .effective_dimensionality - scalar participation ratio
%                                      PR = (sum(lambda))^2 / sum(lambda^2)
%           .variance_explained      - [n_dims x 1] fraction of variance per component

    if nargin < 1
        error('compute_state_space_occupancy:missingInput', ...
            'latent_tensor is required.');
    end

    [n_trials, n_dims, n_time] = size(latent_tensor);

    % Reshape to [n_dims x (n_trials * n_time)] by concatenating all trials and times
    states = reshape(permute(latent_tensor, [2, 1, 3]), n_dims, []);

    % Compute covariance matrix
    mean_state = mean(states, 2);
    centered = states - mean_state;
    cov_matrix = (centered * centered') / (size(centered, 2) - 1);

    % Eigendecomposition
    [~, D] = eig(cov_matrix, 'vector');

    % Sort eigenvalues in descending order
    [eigenvalues, sort_idx] = sort(D, 'descend');

    % Ensure non-negative eigenvalues (numerical stability)
    eigenvalues = max(eigenvalues, 0);

    % Participation ratio: effective dimensionality
    sum_lambda = sum(eigenvalues);
    sum_lambda_sq = sum(eigenvalues .^ 2);

    if sum_lambda_sq > 0
        effective_dim = sum_lambda^2 / sum_lambda_sq;
    else
        effective_dim = 0;
    end

    % Variance explained per component
    if sum_lambda > 0
        var_explained = eigenvalues / sum_lambda;
    else
        var_explained = zeros(n_dims, 1);
    end

    % Build output struct
    result.covariance = cov_matrix;
    result.eigenvalues = eigenvalues;
    result.effective_dimensionality = effective_dim;
    result.variance_explained = var_explained;

end
