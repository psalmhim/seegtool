function [h, p_adjusted] = fdr_correction(p_values, alpha)
% FDR_CORRECTION Benjamini-Hochberg FDR correction.
%
%   [h, p_adjusted] = fdr_correction(p_values, alpha)
%
%   Inputs:
%       p_values - vector of p-values
%       alpha    - significance level (default: 0.05)
%
%   Outputs:
%       h          - logical vector (true = significant after FDR)
%       p_adjusted - FDR-adjusted p-values

    if nargin < 2, alpha = 0.05; end

    p_values = p_values(:);
    m = numel(p_values);

    [p_sorted, sort_idx] = sort(p_values);
    rank = (1:m)';

    p_adjusted_sorted = min(1, p_sorted .* m ./ rank);

    % Enforce monotonicity (from end to start)
    for i = m-1:-1:1
        p_adjusted_sorted(i) = min(p_adjusted_sorted(i), p_adjusted_sorted(i+1));
    end

    p_adjusted = zeros(m, 1);
    p_adjusted(sort_idx) = p_adjusted_sorted;

    h = p_adjusted < alpha;
end
