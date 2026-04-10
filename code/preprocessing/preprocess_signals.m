function [cleaned_data, valid_channels, artifact_mask, preproc_info] = preprocess_signals(raw_data, fs, cfg)
% PREPROCESS_SIGNALS Main SEEG preprocessing pipeline.
%
%   [cleaned_data, valid_channels, artifact_mask, preproc_info] = preprocess_signals(raw_data, fs, cfg)
%
%   Pipeline stages:
%       1. High-pass filter
%       2. Low-pass filter
%       3. Line noise removal
%       4. Re-referencing (bipolar or CAR)
%       5. Bad channel detection
%       6. Artifact segment detection
%       7. Stimulation artifact suppression (if applicable)
%
%   Inputs:
%       raw_data - channels x time matrix
%       fs       - sampling rate (Hz)
%       cfg      - configuration struct from default_config()
%
%   Outputs:
%       cleaned_data   - preprocessed data matrix
%       valid_channels - logical vector of valid channels
%       artifact_mask  - logical matrix of artifact segments
%       preproc_info   - struct with preprocessing metadata

    if nargin < 3
        cfg = default_config();
    end

    preproc_info = struct();
    preproc_info.n_channels_original = size(raw_data, 1);
    preproc_info.n_samples = size(raw_data, 2);
    preproc_info.fs = fs;

    % Step 1: High-pass filter
    fprintf('[Preprocess] Applying high-pass filter at %.1f Hz...\n', cfg.highpass_freq);
    data = apply_highpass(raw_data, fs, cfg.highpass_freq, cfg.filter_order);

    % Step 2: Low-pass filter
    fprintf('[Preprocess] Applying low-pass filter at %.1f Hz...\n', cfg.lowpass_freq);
    data = apply_lowpass(data, fs, cfg.lowpass_freq, cfg.filter_order);

    % Step 3: Line noise removal
    fprintf('[Preprocess] Removing line noise at %d Hz...\n', cfg.line_noise_freq);
    data = remove_line_noise(data, fs, cfg.line_noise_freq, numel(cfg.line_noise_harmonics));

    % Step 4: Bad channel detection (before re-referencing)
    fprintf('[Preprocess] Detecting bad channels...\n');
    [bad_channels, chan_metrics] = detect_bad_channels(data, fs, cfg.bad_channel_zscore, cfg.line_noise_freq);
    valid_channels = ~bad_channels;
    preproc_info.bad_channels = find(bad_channels);
    preproc_info.n_bad_channels = sum(bad_channels);
    preproc_info.channel_metrics = chan_metrics;
    fprintf('[Preprocess] Detected %d bad channels.\n', preproc_info.n_bad_channels);

    % Step 5: Re-referencing
    fprintf('[Preprocess] Applying %s re-referencing...\n', cfg.reref_method);
    preproc_info.reref_method = cfg.reref_method;

    switch lower(cfg.reref_method)
        case 'car'
            data = rereference_car(data, valid_channels);
            preproc_info.channel_labels_reref = {};
        case 'bipolar'
            if isfield(cfg, 'channel_labels')
                [data, bipolar_labels, bipolar_valid] = rereference_bipolar(data, cfg.channel_labels, valid_channels);
                valid_channels = bipolar_valid;
                preproc_info.channel_labels_reref = bipolar_labels;
            else
                warning('preprocess_signals:noLabels', ...
                    'Channel labels not provided for bipolar referencing. Using CAR instead.');
                data = rereference_car(data, valid_channels);
                preproc_info.reref_method = 'car';
                preproc_info.channel_labels_reref = {};
            end
        otherwise
            error('preprocess_signals:invalidReref', 'Unknown reref method: %s', cfg.reref_method);
    end

    % Step 5b: Stimulation artifact suppression on continuous data
    if isfield(cfg, 'stim_times') && ~isempty(cfg.stim_times) && ...
            isfield(cfg, 'stim_mask_duration') && cfg.stim_mask_duration > 0
        fprintf('[Preprocess] Suppressing %d stimulation events (%.3f s)...\n', ...
            numel(cfg.stim_times), cfg.stim_mask_duration);
        [data, stim_mask] = suppress_stimulation_artifacts(data, cfg.stim_times, fs, cfg.stim_mask_duration);
        preproc_info.stim_suppressed = true;
        preproc_info.stim_fraction = mean(stim_mask);
    else
        preproc_info.stim_suppressed = false;
        preproc_info.stim_fraction = 0;
    end

    % Step 6: Artifact detection
    fprintf('[Preprocess] Detecting artifact segments...\n');
    artifact_mask = detect_artifact_segments(data, cfg.artifact_threshold, fs);
    preproc_info.artifact_fraction = mean(artifact_mask(:));
    fprintf('[Preprocess] Artifact fraction: %.2f%%\n', preproc_info.artifact_fraction * 100);

    cleaned_data = interpolate_masked_segments(data, artifact_mask);
    fprintf('[Preprocess] Preprocessing complete.\n');
end


function cleaned = interpolate_masked_segments(data, mask)
% Replace artifact spans with linear interpolation on each channel.
    cleaned = data;
    for ch = 1:size(data, 1)
        chan_mask = mask(ch, :);
        if ~any(chan_mask)
            continue;
        end

        dmask = diff([false, chan_mask, false]);
        starts = find(dmask == 1);
        ends = find(dmask == -1) - 1;

        for i = 1:numel(starts)
            seg_start = starts(i);
            seg_end = ends(i);
            pre_idx = max(1, seg_start - 1);
            post_idx = min(size(data, 2), seg_end + 1);

            if pre_idx == seg_start && post_idx == seg_end
                cleaned(ch, seg_start:seg_end) = 0;
            elseif pre_idx == seg_start
                cleaned(ch, seg_start:seg_end) = cleaned(ch, post_idx);
            elseif post_idx == seg_end
                cleaned(ch, seg_start:seg_end) = cleaned(ch, pre_idx);
            else
                n_interp = seg_end - seg_start + 1;
                cleaned(ch, seg_start:seg_end) = linspace(cleaned(ch, pre_idx), cleaned(ch, post_idx), n_interp);
            end
        end
    end
end
