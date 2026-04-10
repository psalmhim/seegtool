function cfg = default_config()
% DEFAULT_CONFIG Return default configuration for the SEEG pipeline.
%
%   cfg = default_config() returns a struct containing all default
%   parameters for signal preprocessing, epoching, time-frequency
%   analysis, statistics, latent dynamics, and visualization.

    % Sampling rate
    cfg.fs = 1000;
    cfg.resample_fs = 512;  % downsample after preprocessing (0 = no resample)

    % Filtering
    cfg.highpass_freq = 0.5;
    cfg.lowpass_freq = 250;
    cfg.line_noise_freq = 60;
    cfg.line_noise_harmonics = [60, 120, 180];
    cfg.filter_order = 4;

    % Re-referencing
    cfg.reref_method = 'bipolar';

    % Epoching
    cfg.epoch_pre = 1.0;
    cfg.epoch_post = 1.0;
    cfg.baseline_start = -0.5;
    cfg.baseline_end = 0;
    cfg.stim_mask_duration = 0.01;

    % Artifact detection
    cfg.artifact_threshold = 500;
    cfg.bad_channel_zscore = 3.0;

    % Quality control
    cfg.qc_weights.rms = 1.0;
    cfg.qc_weights.var = 1.0;
    cfg.qc_weights.p2p = 1.0;
    cfg.qc_weights.kurt = 0.5;
    cfg.qc_weights.line_noise = 0.5;
    cfg.qc_green_threshold = 3.0;
    cfg.qc_red_threshold = 5.0;

    % Time-frequency analysis
    cfg.freq_range = [2, 150];
    cfg.num_freqs = 40;
    cfg.freqs = logspace(log10(cfg.freq_range(1)), log10(cfg.freq_range(2)), cfg.num_freqs);
    cfg.wavelet_cycles_range = [5, 7];
    cfg.wavelet_cycles = linspace(cfg.wavelet_cycles_range(1), cfg.wavelet_cycles_range(2), cfg.num_freqs);
    cfg.baseline_norm_method = 'db';

    % Frequency bands
    cfg.freq_bands.theta = [4, 8];
    cfg.freq_bands.alpha = [8, 12];
    cfg.freq_bands.beta = [13, 30];
    cfg.freq_bands.gamma = [30, 70];
    cfg.freq_bands.hfa = [70, 150];

    % Statistics
    cfg.n_permutations = 1000;
    cfg.alpha_level = 0.05;
    cfg.alpha = 0.05;  % alias for report templates
    cfg.cluster_threshold = 2.0;
    cfg.channel_sig_top_n = 20;  % top N channels to display in significance figure

    % Latent dynamics
    cfg.n_latent_dims = 10;
    cfg.latent_method = 'pca';
    cfg.smooth_kernel_ms = 10;

    % Time-frequency cycles (scalar summary for reports)
    cfg.n_cycles = mean(cfg.wavelet_cycles_range);

    % Bootstrap / uncertainty
    cfg.n_bootstrap = 500;
    cfg.bootstrap_ci = 0.95;

    % Decoding
    cfg.decode_method = 'lda';
    cfg.n_cv_folds = 5;
    cfg.n_folds = 5;  % alias for report templates

    % Visualization
    cfg.fig_format = 'pdf';
    cfg.fig_dpi = 600;

    % Contrasts
    cfg.contrast_type = 'auto';       % 'auto', 'all_pairwise', 'one_vs_rest', 'custom'
    cfg.contrast_specs = {};           % custom contrast specs (cell of structs)
    cfg.contrast_analyses = {'permutation', 'separation', 'decoding', 'effect_size'};

    % Contact selection / tissue filtering
    cfg.filter_tissue = false;           % false = include all contacts (default)
    cfg.tissue_method = 'atlas';         % 'atlas', 'neighbor', 'manual'
    cfg.tissue_atlas_nii = '';           % path to NIfTI atlas in MNI space
    cfg.tissue_manual_file = '';         % path to TSV with name/tissue columns
    cfg.tissue_radius_mm = 3;           % atlas lookup radius (mm)

    % Report
    cfg.report_formats = {'latex', 'markdown'};
end
