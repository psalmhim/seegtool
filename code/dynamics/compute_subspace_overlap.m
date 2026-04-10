function overlap = compute_subspace_overlap(W_A, W_B)
% COMPUTE_SUBSPACE_OVERLAP Compute overlap between two subspaces.
%
%   overlap = compute_subspace_overlap(W_A, W_B)
%
%   Computes overlap = trace(P_A * P_B) / min(dim_A, dim_B), where P_A and P_B
%   are projection matrices. If columns of W are orthonormal, P = W*W'.
%   Otherwise, P = W * pinv(W' * W) * W'.
%
%   Inputs:
%       W_A - [n_dims x dim_A] basis vectors for subspace A
%       W_B - [n_dims x dim_B] basis vectors for subspace B
%
%   Outputs:
%       overlap - scalar in [0, 1] measuring subspace overlap.
%                 1 = fully overlapping, 0 = orthogonal

    if nargin < 2
        error('compute_subspace_overlap:missingInput', ...
            'Both W_A and W_B are required.');
    end

    if size(W_A, 1) ~= size(W_B, 1)
        error('compute_subspace_overlap:dimensionMismatch', ...
            'W_A and W_B must have the same number of rows (n_dims).');
    end

    dim_A = size(W_A, 2);
    dim_B = size(W_B, 2);

    % Build projection matrix for subspace A
    P_A = build_projection(W_A);

    % Build projection matrix for subspace B
    P_B = build_projection(W_B);

    % Overlap metric
    overlap = trace(P_A * P_B) / min(dim_A, dim_B);

    % Clamp to [0, 1] for numerical stability
    overlap = min(max(overlap, 0), 1);

end


function P = build_projection(W)
% BUILD_PROJECTION Construct orthogonal projection matrix.
%
%   If W has orthonormal columns (W'*W ≈ I), use P = W*W'.
%   Otherwise, use P = W * pinv(W'*W) * W'.

    gram = W' * W;
    n = size(W, 2);

    % Check if columns are approximately orthonormal
    if norm(gram - eye(n), 'fro') < 1e-10 * n
        P = W * W';
    else
        P = W * pinv(gram) * W';
    end

end
