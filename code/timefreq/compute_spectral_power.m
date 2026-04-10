function power = compute_spectral_power(analytic_signal)
% COMPUTE_SPECTRAL_POWER Compute spectral power from analytic signal.
%
%   power = compute_spectral_power(analytic_signal)
%
%   P(t,f) = |Z(t,f)|^2
%
%   Inputs:
%       analytic_signal - complex analytic signal (any dimensions)
%
%   Outputs:
%       power - spectral power, same size as input

    power = abs(analytic_signal).^2;
end
