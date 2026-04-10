function band_feats = extract_band_features(tf_power, freqs, time_vec, freq_bands)
% EXTRACT_BAND_FEATURES Extract band-limited power for each frequency band.
%
%   band_feats = extract_band_features(tf_power, freqs, time_vec, freq_bands)
%
%   Inputs:
%       tf_power   - trials x channels x freqs x time
%       freqs      - frequency vector
%       time_vec   - time vector
%       freq_bands - struct with band names, each [f_low, f_high]
%
%   Outputs:
%       band_feats - struct with field per band (each trials x channels x time)

    band_names = fieldnames(freq_bands);
    band_feats = struct();

    for b = 1:numel(band_names)
        name = band_names{b};
        band_feats.(name) = compute_band_limited_power(tf_power, freqs, freq_bands.(name));
    end
end
