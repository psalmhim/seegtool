function erp = compute_weighted_erp(trial_tensor, weights)
% COMPUTE_WEIGHTED_ERP Compute weighted average ERP.
%
%   erp = compute_weighted_erp(trial_tensor, weights)
%
%   ERP_i(t) = sum(w_k * x_k(i,t)) / sum(w_k)
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       weights      - trials x 1 weight vector
%
%   Outputs:
%       erp - channels x time weighted average

    weights = weights(:);
    w_sum = sum(weights);

    if w_sum == 0
        error('compute_weighted_erp:zeroWeights', 'Sum of weights is zero.');
    end

    n_channels = size(trial_tensor, 2);
    n_time = size(trial_tensor, 3);
    erp = zeros(n_channels, n_time);

    for k = 1:numel(weights)
        erp = erp + weights(k) * squeeze(trial_tensor(k, :, :));
    end
    erp = erp / w_sum;
end
