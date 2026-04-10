function [M, r_squared] = fit_linear_dynamics(Z, dZ)
% FIT_LINEAR_DYNAMICS Fit linear dynamics dZ = M*Z via least squares.
%
%   [M, r_squared] = fit_linear_dynamics(Z, dZ)
%
%   Solves for M in dZ = M*Z using the closed-form solution:
%       M = dZ * Z' * pinv(Z * Z')
%
%   Inputs:
%       Z  - [n_dims x n_time] matrix of latent states
%       dZ - [n_dims x n_time] matrix of state derivatives
%
%   Outputs:
%       M         - [n_dims x n_dims] dynamics matrix
%       r_squared - scalar R-squared goodness-of-fit (proportion of variance
%                   in dZ explained by M*Z)

    if nargin < 2
        error('fit_linear_dynamics:missingInput', ...
            'Both Z and dZ are required.');
    end

    if ~isequal(size(Z), size(dZ))
        error('fit_linear_dynamics:sizeMismatch', ...
            'Z and dZ must have the same dimensions.');
    end

    % Fit M via least squares: M = dZ * Z' * pinv(Z * Z')
    M = dZ * Z' * pinv(Z * Z');

    % Compute R-squared
    dZ_pred = M * Z;
    residuals = dZ - dZ_pred;

    ss_res = sum(residuals(:) .^ 2);
    dZ_mean = mean(dZ, 2);
    dZ_centered = dZ - dZ_mean;
    ss_tot = sum(dZ_centered(:) .^ 2);

    if ss_tot > 0
        r_squared = 1 - ss_res / ss_tot;
    else
        r_squared = 0;
    end

end
