function residual_tensor = subtract_erp(trial_tensor, erp)
% SUBTRACT_ERP Subtract ERP from each trial to isolate induced activity.
%
%   residual_tensor = subtract_erp(trial_tensor, erp)
%
%   x_induced^(k)(t) = x^(k)(t) - ERP(t)
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       erp          - channels x time
%
%   Outputs:
%       residual_tensor - trials x channels x time induced signals

    n_trials = size(trial_tensor, 1);
    residual_tensor = trial_tensor;

    for k = 1:n_trials
        residual_tensor(k, :, :) = squeeze(trial_tensor(k, :, :)) - erp;
    end
end
