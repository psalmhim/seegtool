function results = run_seeg_pipeline(subject_id, config_name, data_dir, results_dir)
% RUN_SEEG_PIPELINE Main SEEG population dynamics analysis pipeline.
%
%   results = run_seeg_pipeline(subject_id, config_name, data_dir, results_dir)
%
%   Inputs:
%       subject_id  - subject identifier string
%       config_name - configuration name: 'default', 'electrical_stimulation',
%                     'cognitive_task', or 'latent_dynamics'
%       data_dir    - path to data directory
%       results_dir - path to results directory
%
%   Outputs:
%       results - struct with all analysis results

    %% Initialization
    pipeline_start = tic;
    fprintf('=== SEEG Population Dynamics Pipeline ===\n');
    fprintf('Subject: %s\n', subject_id);
    fprintf('Config: %s\n', config_name);
    fprintf('Start: %s\n\n', datestr(now));

    % Add paths
    add_paths();

    % Load configuration
    switch lower(config_name)
        case 'electrical_stimulation'
            cfg = config_electrical_stimulation();
        case 'cognitive_task'
            cfg = config_cognitive_task();
        case 'latent_dynamics'
            cfg = config_latent_dynamics();
        otherwise
            cfg = default_config();
    end

    % Create output directories
    output_paths = make_output_dirs(results_dir, subject_id);

    results = struct();
    results.subject_id = subject_id;
    results.config = cfg;

    %% STAGE 1: Load Data
    fprintf('[Stage 1] Loading data...\n');
    try
        data_file = fullfile(data_dir, 'raw', [subject_id, '.mat']);
        events_file = fullfile(data_dir, 'events', [subject_id, '_events.mat']);
        meta_file = fullfile(data_dir, 'metadata', [subject_id, '_metadata.mat']);

        [raw_data, fs, channel_labels] = load_raw_seeg(data_file);
        events = load_events(events_file);
        metadata = load_metadata(meta_file);

        cfg.fs = fs;
        cfg.channel_labels = channel_labels;
        cfg.stim_times = [events.timestamp];
        results.fs = fs;
        results.channel_labels = channel_labels;
        fprintf('[Stage 1] Loaded %d channels, %d samples, fs=%d Hz\n', ...
            size(raw_data, 1), size(raw_data, 2), fs);
    catch ME
        fprintf('[Stage 1] ERROR: %s\n', ME.message);
        return;
    end

    %% STAGE 2: Preprocessing
    fprintf('\n[Stage 2] Preprocessing...\n');
    try
        [cleaned_data, valid_channels, artifact_mask, preproc_info] = ...
            preprocess_signals(raw_data, fs, cfg);
        results.preproc_info = preproc_info;

        if isfield(preproc_info, 'channel_labels_reref') && ~isempty(preproc_info.channel_labels_reref)
            channel_labels = preproc_info.channel_labels_reref;
            results.channel_labels = channel_labels;
        end
    catch ME
        fprintf('[Stage 2] ERROR: %s\n', ME.message);
        return;
    end

    %% STAGE 3: Epoch Extraction
    fprintf('\n[Stage 3] Extracting epochs...\n');
    try
        event_times = [events.timestamp];
        [trial_tensor, time_vec] = extract_event_locked_trials(...
            cleaned_data, fs, event_times, cfg.epoch_pre, cfg.epoch_post);
        results.time_vec = time_vec;

        if cfg.stim_mask_duration > 0
            trial_tensor = apply_poststim_mask(trial_tensor, time_vec, cfg.stim_mask_duration);
        end

        fprintf('[Stage 3] Extracted %d trials, %d channels, %d timepoints\n', ...
            size(trial_tensor, 1), size(trial_tensor, 2), size(trial_tensor, 3));
    catch ME
        fprintf('[Stage 3] ERROR: %s\n', ME.message);
        return;
    end

    %% STAGE 4: Quality Control
    fprintf('\n[Stage 4] Quality control...\n');
    try
        [quality_scores, trial_labels, qc_metrics] = ...
            compute_trial_quality(trial_tensor, time_vec, cfg);
        trial_weights = assign_trial_weights(trial_labels);
        results.trial_labels = trial_labels;
        results.trial_weights = trial_weights;

        n_green = sum(strcmp(trial_labels, 'green'));
        n_yellow = sum(strcmp(trial_labels, 'yellow'));
        n_red = sum(strcmp(trial_labels, 'red'));
        fprintf('[Stage 4] Trials: %d green, %d yellow, %d red\n', n_green, n_yellow, n_red);
    catch ME
        fprintf('[Stage 4] ERROR: %s\n', ME.message);
        return;
    end

    %% STAGE 5: ERP Analysis
    fprintf('\n[Stage 5] ERP analysis...\n');
    try
        erp = compute_weighted_erp(trial_tensor, trial_weights);
        results.erp = erp;
        [~, erp_sem] = compute_robust_erp(trial_tensor, trial_labels);
        results.erp_sem = erp_sem;
    catch ME
        fprintf('[Stage 5] ERROR: %s\n', ME.message);
    end

    %% STAGE 6: Time-Frequency Analysis
    fprintf('\n[Stage 6] Time-frequency analysis...\n');
    try
        [tf_power, tf_phase, freqs, ~] = compute_time_frequency(trial_tensor, fs, cfg);
        results.freqs = freqs;

        baseline_window = [cfg.baseline_start, cfg.baseline_end];
        tf_power_norm = baseline_normalize_tf(tf_power, time_vec, baseline_window, cfg.baseline_norm_method);
        results.tf_power_norm = tf_power_norm;

        hfa = compute_high_frequency_activity(tf_power, freqs, cfg.freq_bands.hfa);
        results.hfa = hfa;

        fprintf('[Stage 6] TF: %d freqs x %d timepoints\n', numel(freqs), size(tf_power, 4));
    catch ME
        fprintf('[Stage 6] ERROR: %s\n', ME.message);
    end

    %% STAGE 7: Phase Analysis
    fprintf('\n[Stage 7] Phase analysis...\n');
    try
        itpc = compute_itpc(tf_phase);
        results.itpc = itpc;
        phase_feats = compute_phase_features(tf_phase, freqs, time_vec, cfg.freq_bands);
        results.phase_features = phase_feats;
    catch ME
        fprintf('[Stage 7] ERROR: %s\n', ME.message);
    end

    %% STAGE 8: Statistical Inference
    fprintf('\n[Stage 8] Statistical inference...\n');
    try
        condition_labels = {events.condition}';
        condition_labels = condition_labels(1:size(trial_tensor, 1));
        results.condition_labels = condition_labels;

        stats_results = run_permutation_statistics(trial_tensor, condition_labels, time_vec, cfg);
        results.stats = stats_results;
    catch ME
        fprintf('[Stage 8] ERROR: %s\n', ME.message);
    end

    %% STAGE 9: Population Representation
    fprintf('\n[Stage 9] Population representation...\n');
    try
        pop_tensor = build_population_tensor(trial_tensor, 'voltage');
        pop_tensor = normalize_population_tensor(pop_tensor, 'zscore');
        results.pop_tensor_size = size(pop_tensor);
    catch ME
        fprintf('[Stage 9] ERROR: %s\n', ME.message);
    end

    %% STAGE 10: Latent Dynamics
    fprintf('\n[Stage 10] Latent dynamics...\n');
    try
        model = fit_latent_model(pop_tensor, cfg);
        latent_tensor = project_to_latent_space(pop_tensor, model);
        latent_tensor = smooth_latent_trajectories(latent_tensor, cfg.smooth_kernel_ms, fs);

        [~, cond_indices] = make_condition_labels(events, 1:size(trial_tensor, 1));
        cond_trajectories = compute_condition_averaged_trajectories(latent_tensor, cond_indices);

        results.latent_model = model;
        results.cond_trajectories = cond_trajectories;
        results.cond_indices = cond_indices;

        fprintf('[Stage 10] %d latent dims, %.1f%% variance explained\n', ...
            cfg.n_latent_dims, sum(model.explained_variance)*100);
    catch ME
        fprintf('[Stage 10] ERROR: %s\n', ME.message);
    end

    %% STAGE 11: Trajectory Geometry
    fprintf('\n[Stage 11] Trajectory geometry...\n');
    try
        geom = compute_trajectory_geometry(latent_tensor, time_vec, cond_indices);
        results.geometry = geom;

        separation = compute_condition_separation(latent_tensor, cond_indices, time_vec);
        results.separation = separation;
    catch ME
        fprintf('[Stage 11] ERROR: %s\n', ME.message);
    end

    %% STAGE 12: Dynamical Systems
    fprintf('\n[Stage 12] Dynamical systems analysis...\n');
    try
        dyn_results = run_dynamical_systems_analysis(latent_tensor, time_vec, cond_indices, cfg);
        results.dynamics = dyn_results;

        if isfield(dyn_results, 'jpca')
            results.jpca = dyn_results.jpca;
        end
        if isfield(dyn_results, 'occupancy')
            results.occupancy = dyn_results.occupancy;
        end
    catch ME
        fprintf('[Stage 12] ERROR: %s\n', ME.message);
    end

    %% STAGE 13: Neural Decoding
    fprintf('\n[Stage 13] Neural decoding...\n');
    try
        decode_results = run_neural_decoding(latent_tensor, condition_labels, time_vec, cfg, model, pop_tensor);
        results.decoding = decode_results;
    catch ME
        fprintf('[Stage 13] ERROR: %s\n', ME.message);
    end

    %% STAGE 14: Uncertainty Quantification
    fprintf('\n[Stage 14] Uncertainty quantification...\n');
    try
        boot_results = bootstrap_trajectory_uncertainty(latent_tensor, cond_indices, ...
            cfg.n_bootstrap, cfg.bootstrap_ci);
        results.bootstrap = boot_results;
    catch ME
        fprintf('[Stage 14] ERROR: %s\n', ME.message);
    end

    %% STAGE 15: Visualization
    fprintf('\n[Stage 15] Generating figures...\n');
    try
        fig_handles = generate_figures(results, cfg);
        export_figures(fig_handles, output_paths.figures, cfg.fig_format, cfg.fig_dpi);
    catch ME
        fprintf('[Stage 15] ERROR: %s\n', ME.message);
    end

    %% STAGE 16: Save Results
    fprintf('\n[Stage 16] Saving results...\n');
    try
        save_results(results, output_paths.subject, subject_id, config_name);
    catch ME
        fprintf('[Stage 16] ERROR: %s\n', ME.message);
    end

    %% Summary
    elapsed = toc(pipeline_start);
    fprintf('\n=== Pipeline Complete ===\n');
    fprintf('Total time: %.1f seconds\n', elapsed);
    fprintf('Results saved to: %s\n', output_paths.subject);
end
