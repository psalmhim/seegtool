function z = zscore_safe(x, dim)
% ZSCORE_SAFE Z-score normalization handling zero variance gracefully.
%
%   z = zscore_safe(x, dim)
%
%   Returns zeros instead of NaN when standard deviation is zero.
%
%   Inputs:
%       x   - numeric array
%       dim - dimension to operate along (default: 1)
%
%   Outputs:
%       z - z-scored array

    if nargin < 2, dim = 1; end

    mu = mean(x, dim);
    sigma = std(x, 0, dim);
    sigma(sigma == 0) = 1;
    z = (x - mu) ./ sigma;
end
