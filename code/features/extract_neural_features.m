function feature_table = extract_neural_features(trial_tensor, tf_power, tf_phase, freqs, time_vec, cfg)
% EXTRACT_NEURAL_FEATURES Main feature extraction pipeline.
%
%   feature_table = extract_neural_features(trial_tensor, tf_power, tf_phase, freqs, time_vec, cfg)
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       tf_power     - trials x channels x freqs x time
%       tf_phase     - trials x channels x freqs x time
%       freqs        - frequency vector
%       time_vec     - time vector
%       cfg          - configuration struct
%
%   Outputs:
%       feature_table - struct with all extracted features

    feature_table = struct();

    % Band-limited power features
    feature_table.band_features = extract_band_features(tf_power, freqs, time_vec, cfg.freq_bands);

    % HFA features
    baseline_window = [cfg.baseline_start, cfg.baseline_end];
    feature_table.hfa_features = extract_hfa_features(tf_power, freqs, time_vec, ...
        cfg.freq_bands.hfa, baseline_window);

    % Phase features
    feature_table.phase_features = compute_phase_features(tf_phase, freqs, time_vec, cfg.freq_bands);

    feature_table.freqs = freqs;
    feature_table.time_vec = time_vec;
end
