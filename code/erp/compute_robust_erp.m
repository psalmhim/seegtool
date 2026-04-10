function [erp, erp_sem] = compute_robust_erp(trial_tensor, trial_labels)
% COMPUTE_ROBUST_ERP Compute ERP excluding red (rejected) trials.
%
%   [erp, erp_sem] = compute_robust_erp(trial_tensor, trial_labels)
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       trial_labels - cell array of 'green', 'yellow', 'red'
%
%   Outputs:
%       erp     - channels x time average ERP
%       erp_sem - channels x time standard error of the mean

    valid_mask = ~strcmp(trial_labels, 'red');
    valid_data = trial_tensor(valid_mask, :, :);

    n_valid = size(valid_data, 1);
    if n_valid == 0
        error('compute_robust_erp:noValidTrials', 'No valid trials remaining after rejection.');
    end

    erp = squeeze(mean(valid_data, 1));
    erp_sem = squeeze(std(valid_data, 0, 1)) / sqrt(n_valid);
end
