function phase_feats = compute_phase_features(tf_phase, freqs, time_vec, freq_bands)
% COMPUTE_PHASE_FEATURES Extract phase-based features per frequency band.
%
%   phase_feats = compute_phase_features(tf_phase, freqs, time_vec, freq_bands)
%
%   Inputs:
%       tf_phase   - trials x channels x freqs x time (radians)
%       freqs      - frequency vector (Hz)
%       time_vec   - time vector (seconds)
%       freq_bands - struct with band names as fields, each [f_low, f_high]
%
%   Outputs:
%       phase_feats - struct with itpc_bands (channels x bands x time)

    band_names = fieldnames(freq_bands);
    n_bands = numel(band_names);
    n_channels = size(tf_phase, 2);
    n_time = size(tf_phase, 4);

    % Compute full ITPC
    itpc_full = compute_itpc(tf_phase);

    phase_feats.itpc_bands = zeros(n_channels, n_bands, n_time);
    phase_feats.band_names = band_names;

    for b = 1:n_bands
        band = freq_bands.(band_names{b});
        band_idx = freqs >= band(1) & freqs <= band(2);
        if any(band_idx)
            phase_feats.itpc_bands(:, b, :) = mean(itpc_full(:, band_idx, :), 2);
        end
    end
end
