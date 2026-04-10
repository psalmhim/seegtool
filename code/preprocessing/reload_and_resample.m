function [cleaned, fs_out] = reload_and_resample(bids_root, sub_prefix, ses_prefix, run_info, fs_original, cfg)
% RELOAD_AND_RESAMPLE Reload raw BIDS data, preprocess, and resample.
%
%   [cleaned, fs_out] = reload_and_resample(bids_root, sub_prefix, ses_prefix, run_info, fs_original, cfg)
%
%   Used by Stage 4/7/8 when cleaned data is not in memory.
%   Applies preprocessing at original fs, then resamples if configured.

    ieeg_dir = fullfile(bids_root, sub_prefix, ses_prefix, 'ieeg');
    vhdr_name = sprintf('%s_%s_task-%s_run-%s_ieeg.vhdr', ...
        sub_prefix, ses_prefix, run_info.task, run_info.run);
    [raw_reload, ~, ~, ~, ~] = load_bids_run( ...
        ieeg_dir, vhdr_name, 'mni', true, 'filter_seeg', true);
    [raw_data_clean, ~, ~] = apply_bids_channel_status(raw_reload);

    % Preprocess at original fs
    preproc_cfg = cfg;
    preproc_cfg.fs = fs_original;
    if isfield(cfg, 'stim_times')
        preproc_cfg.stim_times = cfg.stim_times;
    end
    [cleaned, ~, ~, ~] = preprocess_signals(raw_data_clean, fs_original, preproc_cfg);
    clear raw_reload raw_data_clean;

    fs_out = fs_original;

    % Resample if configured
    if isfield(cfg, 'resample_fs') && cfg.resample_fs > 0 && cfg.resample_fs < fs_original
        target_fs = cfg.resample_fs;
        fprintf('[Reload] Resampling %d Hz -> %d Hz...\n', fs_original, target_fs);
        [p, q] = rat(target_fs / fs_original);
        n_ch = size(cleaned, 1);
        n_samples_new = ceil(size(cleaned, 2) * p / q);
        resampled = zeros(n_ch, n_samples_new);
        for ch = 1:n_ch
            resampled(ch, :) = resample(double(cleaned(ch, :)), p, q);
        end
        cleaned = resampled;
        clear resampled;
        fs_out = target_fs;
    end
end
