function hfa = compute_high_frequency_activity(tf_power, freqs, hfa_range)
% COMPUTE_HIGH_FREQUENCY_ACTIVITY Compute HFA by averaging power in HF band.
%
%   hfa = compute_high_frequency_activity(tf_power, freqs, hfa_range)
%
%   HFA(t) = mean(P(t,f)) for f in hfa_range
%
%   Inputs:
%       tf_power  - trials x channels x freqs x time
%       freqs     - frequency vector (Hz)
%       hfa_range - [f_low, f_high] (default: [70, 150])
%
%   Outputs:
%       hfa - trials x channels x time

    if nargin < 3 || isempty(hfa_range)
        hfa_range = [70, 150];
    end

    hfa = compute_band_limited_power(tf_power, freqs, hfa_range);
end
