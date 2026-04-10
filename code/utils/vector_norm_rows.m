function norms = vector_norm_rows(X)
% VECTOR_NORM_ROWS Compute L2 norm of each row.
%
%   norms = vector_norm_rows(X)
%
%   Inputs:
%       X - matrix (rows are vectors)
%
%   Outputs:
%       norms - column vector of L2 norms

    norms = sqrt(sum(X.^2, 2));
end
