function angles = compute_principal_angles(V_A, V_B)
% COMPUTE_PRINCIPAL_ANGLES Principal angles between two subspaces.
%
%   angles = compute_principal_angles(V_A, V_B)
%
%   Computes principal (canonical) angles between subspaces spanned by V_A and V_B.
%   Uses QR decomposition of each basis followed by SVD of Q_A' * Q_B.
%
%   Inputs:
%       V_A - [n_dims x n_vectors_A] basis vectors for subspace A
%       V_B - [n_dims x n_vectors_B] basis vectors for subspace B
%
%   Outputs:
%       angles - [min(n_vectors_A, n_vectors_B) x 1] principal angles in radians,
%                sorted from smallest to largest

    if nargin < 2
        error('compute_principal_angles:missingInput', ...
            'Both V_A and V_B are required.');
    end

    if size(V_A, 1) ~= size(V_B, 1)
        error('compute_principal_angles:dimensionMismatch', ...
            'V_A and V_B must have the same number of rows (n_dims).');
    end

    % QR decomposition to get orthonormal bases
    [Q_A, ~] = qr(V_A, 0);
    [Q_B, ~] = qr(V_B, 0);

    % SVD of the inner product matrix
    [~, S, ~] = svd(Q_A' * Q_B, 'econ');
    singular_values = diag(S);

    % Clamp singular values to [0, 1] for numerical stability
    singular_values = min(max(singular_values, 0), 1);

    % Principal angles = acos of singular values
    angles = acos(singular_values);

end
