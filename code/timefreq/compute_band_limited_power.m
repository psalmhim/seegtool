function band_power = compute_band_limited_power(tf_power, freqs, band_limits)
% COMPUTE_BAND_LIMITED_POWER Average TF power within a frequency band.
%
%   band_power = compute_band_limited_power(tf_power, freqs, band_limits)
%
%   Inputs:
%       tf_power    - trials x channels x freqs x time
%       freqs       - frequency vector (Hz)
%       band_limits - [f_low, f_high] in Hz
%
%   Outputs:
%       band_power - trials x channels x time

    band_idx = freqs >= band_limits(1) & freqs <= band_limits(2);

    if ~any(band_idx)
        error('compute_band_limited_power:noBand', ...
            'No frequencies found in band [%.1f, %.1f] Hz.', band_limits(1), band_limits(2));
    end

    band_power = squeeze(mean(tf_power(:, :, band_idx, :), 3));
end
