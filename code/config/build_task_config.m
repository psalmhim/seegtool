function cfg = build_task_config(run_info, fs)
% BUILD_TASK_CONFIG Build task-appropriate pipeline configuration.
%
%   cfg = build_task_config(run_info, fs)
%
%   Inputs:
%       run_info - struct with .task, .session, .run fields
%       fs       - sampling rate in Hz

    cfg = default_config();
    cfg.fs = fs;
    cfg.line_noise_freq = 60;  % Korea: 60 Hz

    % General defaults (set before switch so task-specific cases can override)
    cfg.n_latent_dims = 10;
    cfg.latent_method = 'pca';
    cfg.smooth_kernel_ms = 10;
    cfg.n_bootstrap = 200;
    cfg.bootstrap_ci = 0.95;
    cfg.n_permutations = 1000;
    cfg.fig_format = 'png';
    cfg.fig_dpi = 150;

    % Task-specific epoch windows and parameters
    switch lower(run_info.task)
        case {'lexicaldecision', 'shapecontrol', 'sentencenoun', 'sentencegrammar'}
            % 2-AFC cognitive tasks: 2s stimulus
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 2.0;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;

        case 'saliencepain'
            % Passive viewing, 3s image
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 3.0;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;

        case 'balloonwatching'
            % Long video (~15s), wide window for anticipation
            cfg.epoch_pre = 1.0;
            cfg.epoch_post = 16.0;
            cfg.baseline_start = -1.0;
            cfg.baseline_end = 0.0;
            % Only ~10 trials: reduce CV folds and bootstrap
            cfg.n_cv_folds = 3;
            cfg.n_bootstrap = 100;

        case {'viseme', 'visemegen'}
            % 2-AFC, 2.5s video
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 2.5;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;

        case 'visualrhythm'
            % Long stimuli (7-8.5s videos), ITPC is primary analysis
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 8.5;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;

        otherwise
            cfg.epoch_pre = 0.5;
            cfg.epoch_post = 1.5;
            cfg.baseline_start = -0.5;
            cfg.baseline_end = 0.0;
    end
end
