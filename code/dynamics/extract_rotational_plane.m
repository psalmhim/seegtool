function [W_rot, rotation_freq, var_explained] = extract_rotational_plane(M, Z)
% EXTRACT_ROTATIONAL_PLANE Extract the dominant rotational plane from dynamics matrix.
%
%   [W_rot, rotation_freq, var_explained] = extract_rotational_plane(M)
%   [W_rot, rotation_freq, var_explained] = extract_rotational_plane(M, Z)
%
%   Finds conjugate eigenvalue pairs of M with the largest imaginary parts.
%   The dominant rotational plane is defined by the real and imaginary parts
%   of the corresponding eigenvector.
%
%   Inputs:
%       M - [n_dims x n_dims] dynamics matrix
%       Z - [n_dims x n_time] (optional) latent states for computing
%           variance explained by the rotational plane
%
%   Outputs:
%       W_rot         - [n_dims x 2] orthonormal basis for the rotational plane
%       rotation_freq - scalar rotation frequency in cycles per unit time
%                       (imag(eigenvalue) / (2*pi))
%       var_explained - scalar fraction of variance explained by the rotational
%                       plane (requires Z input; NaN if Z not provided)

    if nargin < 1
        error('extract_rotational_plane:missingInput', ...
            'Dynamics matrix M is required.');
    end

    n_dims = size(M, 1);

    % Eigendecomposition
    [V, D] = eig(M);
    eigenvalues = diag(D);

    % Find eigenvalues with imaginary parts (conjugate pairs)
    imag_parts = abs(imag(eigenvalues));

    % Sort by magnitude of imaginary part (descending)
    [~, sort_idx] = sort(imag_parts, 'descend');

    % Select the eigenvalue with the largest imaginary part
    dominant_idx = sort_idx(1);
    dominant_eigenvalue = eigenvalues(dominant_idx);
    dominant_eigenvector = V(:, dominant_idx);

    % Rotation frequency: imag(lambda) / (2*pi)
    rotation_freq = abs(imag(dominant_eigenvalue)) / (2 * pi);

    % Build rotational plane basis from real and imaginary parts of eigenvector
    v_real = real(dominant_eigenvector);
    v_imag = imag(dominant_eigenvector);

    % Orthonormalize via QR
    W_raw = [v_real, v_imag];
    [W_rot, R] = qr(W_raw, 0);

    % Ensure consistent orientation (positive diagonal in R)
    signs = sign(diag(R));
    signs(signs == 0) = 1;
    W_rot = W_rot * diag(signs);

    % Compute variance explained if Z is provided
    if nargin >= 2 && ~isempty(Z)
        Z_centered = Z - mean(Z, 2);
        total_var = sum(Z_centered(:) .^ 2);

        if total_var > 0
            Z_proj = W_rot' * Z_centered;
            proj_var = sum(Z_proj(:) .^ 2);
            var_explained = proj_var / total_var;
        else
            var_explained = 0;
        end
    else
        var_explained = NaN;
    end

end
