function induced_power = compute_induced_power(trial_tensor, erp, fs, cfg)
% COMPUTE_INDUCED_POWER Compute induced power by subtracting ERP first.
%
%   induced_power = compute_induced_power(trial_tensor, erp, fs, cfg)
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       erp          - channels x time ERP
%       fs           - sampling rate (Hz)
%       cfg          - config struct for TF analysis
%
%   Outputs:
%       induced_power - trials x channels x freqs x time induced spectral power

    residual = subtract_erp(trial_tensor, erp);
    [induced_power, ~, ~, ~] = compute_time_frequency(residual, fs, cfg);
end
