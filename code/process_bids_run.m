function summary = process_bids_run(bids_root, subject, run_info, results_dir)
% PROCESS_BIDS_RUN Full SEEG pipeline for a single BIDS run (resumable).
%
%   summary = process_bids_run(bids_root, subject, run_info, results_dir)
%
%   Each stage saves its own .mat file. Completed stages are skipped on
%   re-run. Memory stays low because only the current stage's data is held.
%
%   Output directory structure:
%       run_output/
%         results/                      - per-stage result files
%           stage01_bids.mat            - metadata, channel info, events
%           stage02_config.mat          - pipeline configuration
%           stage03_preproc.mat         - preprocessing info (not raw data)
%           stage04_epochs.mat          - trial_tensor, time_vec (largest)
%           stage05_qc.mat              - trial labels, weights
%           stage06_erp.mat             - ERP + SEM
%           stage07_timefreq.mat        - TF power, HFA, freqs
%           stage08_phase.mat           - ITPC
%           stage09_stats.mat           - permutation test results
%           stage11_latent.mat          - PCA model, trajectories
%           stage12_geometry.mat        - geometry metrics, separation
%           stage13_dynamics.mat        - jPCA, tangent, occupancy
%           stage14_decoding.mat        - decoding accuracy, onset
%           stage14b_contrasts.mat      - contrast results
%           stage15_bootstrap.mat       - confidence tubes
%           stage16_roi.mat             - per-region analysis
%         figures/pdf/, figures/png/    - publication figures
%         summary.mat                   - lightweight metadata + success

    sub_prefix = sprintf('sub-%s', subject);
    ses_prefix = sprintf('ses-%s', run_info.session);
    run_output = fullfile(results_dir, ...
        sprintf('task-%s_run-%s', run_info.task, run_info.run));
    if ~isfolder(run_output); mkdir(run_output); end
    results_subdir = fullfile(run_output, 'results');
    if ~isfolder(results_subdir); mkdir(results_subdir); end

    % Stage file helper - all stage .mat files go into results/ subfolder
    sf = @(name) fullfile(results_subdir, [name '.mat']);

    %% ================================================================
    %  STAGE 1: Load BIDS data
    %  ================================================================
    if is_done(sf('stage01_bids'))
        fprintf('[Stage 1] BIDS loading... SKIP\n');
        s1 = load(sf('stage01_bids'));
    else
        fprintf('\n[Stage 1] Loading BIDS data...\n');
        ieeg_dir = fullfile(bids_root, sub_prefix, ses_prefix, 'ieeg');
        vhdr_name = sprintf('%s_%s_task-%s_run-%s_ieeg.vhdr', ...
            sub_prefix, ses_prefix, run_info.task, run_info.run);

        [raw, events, electrodes, channels, meta] = load_bids_run( ...
            ieeg_dir, vhdr_name, 'mni', true, 'filter_seeg', true);

        fprintf('[Stage 1b] Harmonizing electrode names...\n');
        [elec_matched, ~] = harmonize_electrode_names(electrodes, raw.label');
        raw.electrodes = elec_matched;

        fprintf('[Stage 1c] Applying channel status...\n');
        [clean_data, good_idx, bad_labels] = apply_bids_channel_status(raw);
        raw.data = clean_data;
        raw.label = raw.label(good_idx);

        fprintf('[Stage 1d] Filtering events...\n');
        stim_events = filter_events_by_type(events, run_info.epoch_event);
        if isempty(stim_events)
            warning('No %s events found. Skipping.', run_info.epoch_event);
            summary = struct('success', false, 'error', 'No stimulus events');
            return;
        end
        stim_events = enrich_event_conditions(stim_events, events, run_info.task);

        s1 = struct();
        s1.fs = raw.fs;
        s1.task = run_info.task;
        s1.meta = meta;
        s1.channel_labels = raw.label;
        s1.n_channels_raw = size(raw.data, 1) + numel(bad_labels);
        s1.n_channels_good = size(raw.data, 1);
        s1.bad_channels = bad_labels;
        s1.conditions = unique({stim_events.condition});
        s1.n_events_total = numel(events);
        s1.n_events_stim = numel(stim_events);
        s1.stim_events = stim_events;
        s1.channels = channels;
        s1.good_idx = good_idx;
        s1.raw_data = raw.data;  % needed by stage 3, cleared after

        fprintf('[Stage 1] %d channels, %d events, conditions: %s\n', ...
            s1.n_channels_good, s1.n_events_stim, strjoin(s1.conditions, ', '));

        % Save without raw_data (too large for permanent storage)
        s1_save = rmfield(s1, 'raw_data');
        save(sf('stage01_bids'), '-struct', 's1_save', '-v7.3');
    end

    %% ================================================================
    %  STAGE 2: Configuration
    %  ================================================================
    if is_done(sf('stage02_config'))
        fprintf('[Stage 2] Config... SKIP\n');
        s2 = load(sf('stage02_config'));
    else
        fprintf('\n[Stage 2] Configuring pipeline...\n');
        cfg = build_task_config(run_info, s1.fs);
        s2 = struct('cfg', cfg);
        save(sf('stage02_config'), '-struct', 's2');
    end
    cfg = s2.cfg;

    %% ================================================================
    %  STAGE 2b: Contact tissue filtering (optional)
    %  ================================================================
    if isfield(cfg, 'filter_tissue') && cfg.filter_tissue
        if is_done(sf('stage02b_tissue'))
            fprintf('[Stage 2b] Tissue classification... SKIP\n');
            s2b = load(sf('stage02b_tissue'));
        else
            fprintf('\n[Stage 2b] Classifying contact tissue type...\n');
            % Need MNI electrodes for atlas lookup
            mni_elec_file = fullfile(bids_root, sub_prefix, ses_prefix, 'ieeg', ...
                sprintf('%s_%s_space-MNI152NLin2009cAsym_electrodes.tsv', sub_prefix, ses_prefix));
            if isfile(mni_elec_file)
                mni_elec = load_bids_electrodes(mni_elec_file);
                % Filter to good channels only
                [mni_matched, ~] = harmonize_electrode_names(mni_elec, s1.channel_labels);
                tissue_info = classify_contact_tissue(mni_matched, ...
                    'method', cfg.tissue_method, ...
                    'atlas_nii', cfg.tissue_atlas_nii, ...
                    'manual_file', cfg.tissue_manual_file, ...
                    'radius_mm', cfg.tissue_radius_mm);
            else
                fprintf('[Stage 2b] No MNI electrodes found, including all contacts.\n');
                tissue_info = struct();
                tissue_info.is_gm = true(numel(s1.channel_labels), 1);
                tissue_info.gm_indices = (1:numel(s1.channel_labels))';
                tissue_info.label = s1.channel_labels;
                tissue_info.tissue = repmat({'unknown'}, numel(s1.channel_labels), 1);
                tissue_info.region = repmat({''}, numel(s1.channel_labels), 1);
            end
            s2b = struct('tissue_info', tissue_info);
            save(sf('stage02b_tissue'), '-struct', 's2b');
        end

        % Apply tissue filter to raw data and channel labels
        gm_idx = s2b.tissue_info.gm_indices;
        if numel(gm_idx) < numel(s1.channel_labels)
            n_excluded = numel(s1.channel_labels) - numel(gm_idx);
            fprintf('[Stage 2b] Excluding %d non-GM contacts, keeping %d\n', n_excluded, numel(gm_idx));
            s1.channel_labels = s1.channel_labels(gm_idx);
            s1.n_channels_good = numel(gm_idx);
            if isfield(s1, 'raw_data')
                s1.raw_data = s1.raw_data(gm_idx, :);
            end
            s1.good_idx = s1.good_idx(gm_idx);
        end
    end

    %% ================================================================
    %  STAGE 3: Preprocessing
    %  ================================================================
    if is_done(sf('stage03_preproc'))
        fprintf('[Stage 3] Preprocessing... SKIP\n');
        s3 = load(sf('stage03_preproc'));
        % Restore resampled fs if saved
        if isfield(s3, 'fs') && s3.fs ~= s1.fs
            s1.fs_original = s1.fs;
            s1.fs = s3.fs;
            cfg.fs = s3.fs;
            % Update event sample indices for resampled fs
            for ei = 1:numel(s1.stim_events)
                s1.stim_events(ei).sample = round(s1.stim_events(ei).onset * s3.fs) + 1;
            end
        end
    else
        fprintf('\n[Stage 3] Preprocessing...\n');
        % Need raw data - reload if resuming
        if ~isfield(s1, 'raw_data')
            fprintf('[Stage 3] Reloading raw data for preprocessing...\n');
            ieeg_dir = fullfile(bids_root, sub_prefix, ses_prefix, 'ieeg');
            vhdr_name = sprintf('%s_%s_task-%s_run-%s_ieeg.vhdr', ...
                sub_prefix, ses_prefix, run_info.task, run_info.run);
            [raw_reload, ~, ~, ~, ~] = load_bids_run( ...
                ieeg_dir, vhdr_name, 'mni', true, 'filter_seeg', true);
            [raw_data_clean, ~, ~] = apply_bids_channel_status(raw_reload);
        else
            raw_data_clean = s1.raw_data;
        end

        cfg.stim_times = [s1.stim_events.onset];
        [cleaned, ~, ~, preproc_info] = preprocess_signals(raw_data_clean, s1.fs, cfg);

        % Resample if configured
        if isfield(cfg, 'resample_fs') && cfg.resample_fs > 0 && cfg.resample_fs < s1.fs
            target_fs = cfg.resample_fs;
            fprintf('[Preprocess] Resampling %d Hz -> %d Hz...\n', s1.fs, target_fs);
            [p, q] = rat(target_fs / s1.fs);
            n_ch = size(cleaned, 1);
            n_samples_new = ceil(size(cleaned, 2) * p / q);
            resampled = zeros(n_ch, n_samples_new);
            for ch = 1:n_ch
                resampled(ch, :) = resample(double(cleaned(ch, :)), p, q);
            end
            cleaned = resampled;
            clear resampled;
            s1.fs_original = s1.fs;
            s1.fs = target_fs;
            cfg.fs = target_fs;
            % Update event sample indices for new fs
            for ei = 1:numel(s1.stim_events)
                s1.stim_events(ei).sample = round(s1.stim_events(ei).onset * target_fs) + 1;
            end
            fprintf('[Preprocess] Resampled: %d channels x %d samples at %d Hz\n', ...
                n_ch, size(cleaned, 2), target_fs);
        end

        s3 = struct();
        s3.preproc_info = preproc_info;
        s3.fs = s1.fs;  % save actual fs (may be resampled)
        s3.cleaned = cleaned;  % needed by stage 4
        if isfield(preproc_info, 'channel_labels_reref') && ~isempty(preproc_info.channel_labels_reref)
            s3.channel_labels = preproc_info.channel_labels_reref;
        else
            s3.channel_labels = s1.channel_labels;
        end

        % Save without cleaned data (too large)
        s3_save = rmfield(s3, 'cleaned');
        save(sf('stage03_preproc'), '-struct', 's3_save');
    end
    % Free raw data from memory
    if isfield(s1, 'raw_data')
        s1 = rmfield(s1, 'raw_data');
    end

    %% ================================================================
    %  STAGE 4: Epoch extraction
    %  ================================================================
    if is_done(sf('stage04_epochs'))
        fprintf('[Stage 4] Epoch extraction... SKIP\n');
        s4 = load(sf('stage04_epochs'));
    else
        fprintf('\n[Stage 4] Extracting epochs...\n');
        if ~isfield(s3, 'cleaned')
            fprintf('[Stage 4] Reloading preprocessed data...\n');
            fs_orig = s1.fs;
            if isfield(s1, 'fs_original'); fs_orig = s1.fs_original; end
            [cleaned, ~] = reload_and_resample(bids_root, sub_prefix, ses_prefix, run_info, fs_orig, cfg);
            s3.cleaned = cleaned;
            clear cleaned;
        end
        event_times = [s1.stim_events.onset];
        [trial_tensor, time_vec] = extract_event_locked_trials( ...
            s3.cleaned, s1.fs, event_times, cfg.epoch_pre, cfg.epoch_post);

        if cfg.stim_mask_duration > 0
            trial_tensor = apply_poststim_mask(trial_tensor, time_vec, cfg.stim_mask_duration);
        end

        s4 = struct();
        s4.trial_tensor = trial_tensor;
        s4.time_vec = time_vec;
        s4.n_trials = size(trial_tensor, 1);
        s4.n_channels = size(trial_tensor, 2);
        s4.n_timepoints = size(trial_tensor, 3);

        fprintf('[Stage 4] %d trials x %d channels x %d time\n', ...
            s4.n_trials, s4.n_channels, s4.n_timepoints);
        save(sf('stage04_epochs'), '-struct', 's4', '-v7.3');
    end
    % Free cleaned data
    if isfield(s3, 'cleaned')
        s3 = rmfield(s3, 'cleaned');
    end

    %% ================================================================
    %  STAGE 5: Quality control
    %  ================================================================
    if is_done(sf('stage05_qc'))
        fprintf('[Stage 5] Quality control... SKIP\n');
        s5 = load(sf('stage05_qc'));
    else
        fprintf('\n[Stage 5] Quality control...\n');
        [~, trial_labels, ~] = compute_trial_quality(s4.trial_tensor, s4.time_vec, cfg);
        trial_weights = assign_trial_weights(trial_labels);

        condition_labels = {s1.stim_events.condition}';
        if numel(condition_labels) > s4.n_trials
            condition_labels = condition_labels(1:s4.n_trials);
        end

        s5 = struct();
        s5.trial_labels = trial_labels;
        s5.trial_weights = trial_weights;
        s5.condition_labels = condition_labels;

        n_good = sum(strcmp(trial_labels, 'green'));
        n_warn = sum(strcmp(trial_labels, 'yellow'));
        n_bad = sum(strcmp(trial_labels, 'red'));
        fprintf('[Stage 5] Trials: %d green, %d yellow, %d red\n', n_good, n_warn, n_bad);
        save(sf('stage05_qc'), '-struct', 's5');
    end

    %% ================================================================
    %  STAGE 6: ERP analysis
    %  ================================================================
    if is_done(sf('stage06_erp'))
        fprintf('[Stage 6] ERP analysis... SKIP\n');
    else
        fprintf('\n[Stage 6] ERP analysis...\n');
        erp = compute_weighted_erp(s4.trial_tensor, s5.trial_weights);
        [~, erp_sem] = compute_robust_erp(s4.trial_tensor, s5.trial_labels);
        save(sf('stage06_erp'), 'erp', 'erp_sem', '-v7.3');
    end

    %% ================================================================
    %  STAGE 7: Time-frequency analysis (continuous CWT → epoch)
    %  ================================================================
    if is_done(sf('stage07_timefreq'))
        fprintf('[Stage 7] Time-frequency analysis... SKIP\n');
        tf_phase = [];
    else
        fprintf('\n[Stage 7] Time-frequency analysis (continuous → epoch)...\n');
        % Need continuous preprocessed data for artifact-free CWT
        if ~isfield(s3, 'cleaned')
            fprintf('[Stage 7] Reloading preprocessed data...\n');
            fs_orig = s1.fs;
            if isfield(s1, 'fs_original'); fs_orig = s1.fs_original; end
            [cleaned_data, ~] = reload_and_resample(bids_root, sub_prefix, ses_prefix, run_info, fs_orig, cfg);
        else
            cleaned_data = s3.cleaned;
        end

        event_times = [s1.stim_events.onset];
        [tf_power, tf_phase, freqs, ~] = compute_tf_continuous_epoch( ...
            cleaned_data, s1.fs, event_times, cfg.epoch_pre, cfg.epoch_post, cfg);
        clear cleaned_data;

        baseline_window = [cfg.baseline_start, cfg.baseline_end];
        tf_power_norm = baseline_normalize_tf(tf_power, s4.time_vec, baseline_window, cfg.baseline_norm_method);

        hfa = compute_high_frequency_activity(tf_power, freqs, cfg.freq_bands.hfa);

        save(sf('stage07_timefreq'), 'tf_power_norm', 'freqs', 'hfa', '-v7.3');
        clear tf_power tf_power_norm hfa;
    end

    %% ================================================================
    %  STAGE 8: Phase analysis (ITPC)
    %  ================================================================
    if is_done(sf('stage08_phase'))
        fprintf('[Stage 8] Phase analysis... SKIP\n');
    else
        fprintf('\n[Stage 8] Phase analysis...\n');
        if isempty(tf_phase)
            % Recompute TF phase from continuous data
            fprintf('[Stage 8] Reloading data for phase computation...\n');
            if ~isfield(s3, 'cleaned')
                fs_orig = s1.fs;
                if isfield(s1, 'fs_original'); fs_orig = s1.fs_original; end
                [cleaned_data, ~] = reload_and_resample(bids_root, sub_prefix, ses_prefix, run_info, fs_orig, cfg);
            else
                cleaned_data = s3.cleaned;
            end
            event_times = [s1.stim_events.onset];
            [~, tf_phase, ~, ~] = compute_tf_continuous_epoch( ...
                cleaned_data, s1.fs, event_times, cfg.epoch_pre, cfg.epoch_post, cfg);
            clear cleaned_data;
        end
        itpc = compute_itpc(tf_phase);
        save(sf('stage08_phase'), 'itpc', '-v7.3');
        clear tf_phase itpc;
    end

    %% ================================================================
    %  STAGE 9: Statistical inference
    %  ================================================================
    if is_done(sf('stage09_stats'))
        fprintf('[Stage 9] Statistics... SKIP\n');
    else
        fprintf('\n[Stage 9] Statistics...\n');
        if numel(unique(s5.condition_labels)) > 1
            stats_results = run_permutation_statistics( ...
                s4.trial_tensor, s5.condition_labels, s4.time_vec, cfg);
            save(sf('stage09_stats'), 'stats_results', '-v7.3');
        else
            fprintf('[Stage 9] Single condition - skipping\n');
            stats_results = struct();
            save(sf('stage09_stats'), 'stats_results');
        end
        clear stats_results;
    end

    %% ================================================================
    %  STAGE 9b: Multivariate TF statistics
    %  ================================================================
    if is_done(sf('stage09b_tf_stats'))
        fprintf('[Stage 9b] TF multivariate stats... SKIP\n');
    else
        fprintf('\n[Stage 9b] TF multivariate statistics...\n');
        if numel(unique(s5.condition_labels)) > 1
            % Load TF power if not in memory
            s7 = load(sf('stage07_timefreq'), 'tf_power_norm', 'freqs');
            if isfield(s7, 'tf_power_norm')
                tf_stats = run_tf_multivariate_stats( ...
                    s7.tf_power_norm, s4.trial_tensor, s5.condition_labels, ...
                    s4.time_vec, s7.freqs, cfg);
                save(sf('stage09b_tf_stats'), 'tf_stats', '-v7.3');
                clear tf_stats;
            else
                fprintf('[Stage 9b] TF data not available - skipping\n');
            end
            clear s7;
        else
            fprintf('[Stage 9b] Single condition - skipping\n');
        end
    end

    %% ================================================================
    %  STAGE 10-11: Population + Latent dynamics
    %  ================================================================
    if is_done(sf('stage11_latent'))
        fprintf('[Stage 10-11] Population + Latent dynamics... SKIP\n');
        s11 = load(sf('stage11_latent'));
    else
        fprintf('\n[Stage 10] Population dynamics...\n');
        pop_tensor = build_population_tensor(s4.trial_tensor, 'voltage');
        pop_tensor = normalize_population_tensor(pop_tensor, 'zscore');

        fprintf('\n[Stage 11] Latent dynamics...\n');
        model = fit_latent_model(pop_tensor, cfg);
        latent_tensor = project_to_latent_space(pop_tensor, model);
        latent_tensor = smooth_latent_trajectories(latent_tensor, cfg.smooth_kernel_ms, s1.fs);
        clear pop_tensor;

        [~, cond_indices] = make_condition_labels(s1.stim_events, 1:s4.n_trials);
        cond_trajectories = compute_condition_averaged_trajectories(latent_tensor, cond_indices);

        s11 = struct();
        s11.latent_model = model;
        s11.cond_trajectories = cond_trajectories;
        s11.cond_indices = cond_indices;
        s11.latent_tensor = latent_tensor;

        fprintf('[Stage 11] %d latent dims, %.1f%% variance\n', ...
            cfg.n_latent_dims, sum(model.explained_variance) * 100);
        save(sf('stage11_latent'), '-struct', 's11', '-v7.3');
    end

    %% ================================================================
    %  STAGE 12: Trajectory geometry
    %  ================================================================
    if is_done(sf('stage12_geometry'))
        fprintf('[Stage 12] Trajectory geometry... SKIP\n');
    else
        fprintf('\n[Stage 12] Trajectory geometry...\n');
        geom = compute_trajectory_geometry(s11.latent_tensor, s4.time_vec, s11.cond_indices);

        separation = struct();
        if numel(unique(s5.condition_labels)) > 1
            separation = compute_condition_separation(s11.latent_tensor, s11.cond_indices, s4.time_vec);
        end
        save(sf('stage12_geometry'), 'geom', 'separation', '-v7.3');
        clear geom separation;
    end

    %% ================================================================
    %  STAGE 13: Dynamical systems
    %  ================================================================
    if is_done(sf('stage13_dynamics'))
        fprintf('[Stage 13] Dynamical systems... SKIP\n');
    else
        fprintf('\n[Stage 13] Dynamical systems...\n');
        cond_names = fieldnames(s11.cond_trajectories);
        trajectories_cell = cell(1, numel(cond_names));
        for ci = 1:numel(cond_names)
            trajectories_cell{ci} = s11.cond_trajectories.(cond_names{ci});
        end
        dt = mean(diff(s4.time_vec));
        dynamics = run_dynamical_systems_analysis(trajectories_cell, dt, s11.latent_tensor);
        save(sf('stage13_dynamics'), 'dynamics', '-v7.3');
        clear dynamics trajectories_cell;
    end

    %% ================================================================
    %  STAGE 14: Neural decoding
    %  ================================================================
    if is_done(sf('stage14_decoding'))
        fprintf('[Stage 14] Neural decoding... SKIP\n');
    else
        fprintf('\n[Stage 14] Neural decoding...\n');
        % Check condition balance: need at least n_cv_folds samples per class
        uniq_conds = unique(s5.condition_labels);
        min_class_count = Inf;
        for ci = 1:numel(uniq_conds)
            if iscell(s5.condition_labels)
                cc = sum(strcmp(s5.condition_labels, uniq_conds{ci}));
            else
                cc = sum(s5.condition_labels == uniq_conds(ci));
            end
            min_class_count = min(min_class_count, cc);
        end

        if numel(uniq_conds) > 1 && min_class_count >= cfg.n_cv_folds
            pca_model = [];
            if isfield(s11, 'latent_model') && isfield(s11.latent_model, 'W')
                pca_model = s11.latent_model;
            end
            pop_tensor = build_population_tensor(s4.trial_tensor, 'voltage');
            pop_tensor = normalize_population_tensor(pop_tensor, 'zscore');
            decoding = run_neural_decoding(s11.latent_tensor, s5.condition_labels, s4.time_vec, cfg, pca_model, pop_tensor);
            save(sf('stage14_decoding'), 'decoding', '-v7.3');
            clear decoding pop_tensor;
        else
            if numel(uniq_conds) <= 1
                fprintf('[Stage 14] Single condition - skipping\n');
            else
                fprintf('[Stage 14] Imbalanced conditions (min class=%d < %d folds) - skipping\n', ...
                    min_class_count, cfg.n_cv_folds);
            end
            decoding = struct();
            save(sf('stage14_decoding'), 'decoding');
        end
    end

    %% ================================================================
    %  STAGE 14b: Contrast analysis
    %  ================================================================
    if is_done(sf('stage14b_contrasts'))
        fprintf('[Stage 14b] Contrast analysis... SKIP\n');
    else
        fprintf('\n[Stage 14b] Contrast analysis...\n');
        if numel(unique(s5.condition_labels)) > 1
            contrasts = build_task_contrasts(run_info.task, s5.condition_labels);
            contrast_results = struct([]);
            if ~isempty(contrasts)
                ca_out = run_contrast_analysis(s4.trial_tensor, contrasts, s4.time_vec, cfg, ...
                    'condition_labels', s5.condition_labels, 'latent_tensor', s11.latent_tensor);
                contrast_results = ca_out.contrasts;
                n_sig = sum([contrast_results.significant]);
                fprintf('[Stage 14b] %d/%d contrasts significant\n', n_sig, numel(contrasts));
            end
            save(sf('stage14b_contrasts'), 'contrasts', 'contrast_results', '-v7.3');
            clear contrasts contrast_results;
        else
            fprintf('[Stage 14b] Single condition - skipping\n');
            contrasts = struct([]);
            contrast_results = struct([]);
            save(sf('stage14b_contrasts'), 'contrasts', 'contrast_results');
        end
    end

    %% ================================================================
    %  STAGE 15: Bootstrap uncertainty
    %  ================================================================
    if is_done(sf('stage15_bootstrap'))
        fprintf('[Stage 15] Bootstrap uncertainty... SKIP\n');
    else
        fprintf('\n[Stage 15] Uncertainty quantification...\n');
        bootstrap = bootstrap_trajectory_uncertainty(s11.latent_tensor, s11.cond_indices, ...
            cfg.n_bootstrap, cfg.bootstrap_ci);
        save(sf('stage15_bootstrap'), 'bootstrap', '-v7.3');
        clear bootstrap;
    end

    %% ================================================================
    %  STAGE 16: ROI-based analysis
    %  ================================================================
    if is_done(sf('stage16_roi'))
        fprintf('[Stage 16] ROI-based analysis... SKIP\n');
    else
        fprintf('\n[Stage 16] ROI-based analysis...\n');
        roi_groups = build_roi_groups_from_channels(s1.channels, s1.good_idx);
        roi_results = struct([]);
        if numel(roi_groups) > 1
            roi_results = run_roi_latent_analysis(s4.trial_tensor, roi_groups, ...
                s4.time_vec, s1.stim_events, cfg);
        end
        save(sf('stage16_roi'), 'roi_groups', 'roi_results', '-v7.3');
        clear roi_groups roi_results;
    end

    %% ================================================================
    %  STAGE 17: Visualization
    %  ================================================================
    fprintf('\n[Stage 17] Generating publication figures...\n');
    result = build_result_for_viz(run_output, s1, s4, s5, cfg);
    generate_publication_figures(result, run_output, cfg);

    % Contrast summary figure
    if isfile(sf('stage14b_contrasts'))
        s14b = load(sf('stage14b_contrasts'));
        if ~isempty(s14b.contrast_results)
            try
                sty = nature_style();
                fig = plot_contrast_summary(s14b.contrast_results, s4.time_vec, ...
                    'title', sprintf('Contrasts - %s', run_info.task), 'style', sty);
                pdf_dir = fullfile(run_output, 'figures', 'pdf');
                png_dir = fullfile(run_output, 'figures', 'png');
                if ~isfolder(pdf_dir); mkdir(pdf_dir); end
                if ~isfolder(png_dir); mkdir(png_dir); end
                export_figure(fig, fullfile(pdf_dir, 'contrasts'), sty, 'width', 'double');
                export_figure(fig, fullfile(png_dir, 'contrasts'), sty, 'width', 'double', 'formats', {'png'});
                close(fig);
            catch ME
                fprintf('[Stage 17] Contrast figure failed: %s\n', ME.message);
            end
        end
    end

    %% ================================================================
    %  STAGE 18: Summary
    %  ================================================================
    fprintf('\n[Stage 18] Saving summary...\n');
    summary = struct();
    summary.success = true;
    summary.task = s1.task;
    summary.conditions = s1.conditions;
    summary.n_trials = s4.n_trials;
    summary.n_channels = s4.n_channels;
    summary.n_timepoints = s4.n_timepoints;
    summary.fs = s1.fs;
    summary.run_output = run_output;
    summary.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    % List completed stages
    stage_files = {'stage01_bids', 'stage02_config', 'stage03_preproc', ...
        'stage04_epochs', 'stage05_qc', 'stage06_erp', 'stage07_timefreq', ...
        'stage08_phase', 'stage09_stats', 'stage09b_tf_stats', 'stage11_latent', ...
        'stage12_geometry', 'stage13_dynamics', 'stage14_decoding', ...
        'stage14b_contrasts', 'stage15_bootstrap', 'stage16_roi'};
    summary.stages_complete = {};
    for i = 1:numel(stage_files)
        if isfile(sf(stage_files{i}))
            summary.stages_complete{end+1} = stage_files{i};
        end
    end
    summary.n_figures = numel(dir(fullfile(run_output, 'figures', 'png', '*.png')));

    save(fullfile(run_output, 'summary.mat'), '-struct', 'summary');
    fprintf('[Done] %d stages complete, %d figures\n', ...
        numel(summary.stages_complete), summary.n_figures);

    % Generate per-stage reports (markdown + LaTeX)
    try
        generate_stage_report(run_output, 'md');
        generate_stage_report(run_output, 'tex');
    catch ME
        fprintf('[Report] Report generation failed: %s\n', ME.message);
    end

    % Also save legacy results.mat for backward compatibility with dashboard
    save_legacy_result(run_output, sf);
end


%% ======================================================================
%  Helper functions
%  ======================================================================

function done = is_done(filepath)
% Check if a stage file exists (= stage completed).
    done = isfile(filepath);
end


function result = build_result_for_viz(run_output, s1, s4, s5, cfg)
% Build a lightweight result struct for generate_publication_figures
% by loading only what's needed from stage files.
    sf = @(name) fullfile(run_output, 'results', [name '.mat']);

    result = struct();
    result.task = s1.task;
    result.conditions = s1.conditions;
    result.channel_labels = s1.channel_labels;
    result.time_vec = s4.time_vec;
    result.n_trials = s4.n_trials;
    result.n_channels = s4.n_channels;
    result.condition_labels = s5.condition_labels;
    result.config = cfg;

    if isfile(sf('stage06_erp'))
        s = load(sf('stage06_erp'));
        result.erp = s.erp;
        result.erp_sem = s.erp_sem;
    end
    if isfile(sf('stage07_timefreq'))
        s = load(sf('stage07_timefreq'));
        result.tf_power_norm = s.tf_power_norm;
        result.freqs = s.freqs;
        result.hfa = s.hfa;
    end
    if isfile(sf('stage08_phase'))
        s = load(sf('stage08_phase'));
        result.itpc = s.itpc;
    end
    if isfile(sf('stage09_stats'))
        s = load(sf('stage09_stats'));
        result.stats = s.stats_results;
    end
    if isfile(sf('stage11_latent'))
        s = load(sf('stage11_latent'));
        result.latent_model = s.latent_model;
        result.cond_trajectories = s.cond_trajectories;
        result.cond_indices = s.cond_indices;
    end
    if isfile(sf('stage12_geometry'))
        s = load(sf('stage12_geometry'));
        result.geometry = s.geom;
        result.separation = s.separation;
    end
    if isfile(sf('stage13_dynamics'))
        s = load(sf('stage13_dynamics'));
        result.dynamics = s.dynamics;
    end
    if isfile(sf('stage14_decoding'))
        s = load(sf('stage14_decoding'));
        result.decoding = s.decoding;
    end
    if isfile(sf('stage14b_contrasts'))
        s = load(sf('stage14b_contrasts'));
        result.contrast_results = s.contrast_results;
    end
    if isfile(sf('stage15_bootstrap'))
        s = load(sf('stage15_bootstrap'));
        result.bootstrap = s.bootstrap;
    end
    if isfile(sf('stage16_roi'))
        s = load(sf('stage16_roi'));
        result.roi_results = s.roi_results;
        result.roi_groups = s.roi_groups;
    end
end


function save_legacy_result(run_output, ~)
% Save a combined results.mat for backward compatibility (dashboard, reports).
% Only stores lightweight fields - large tensors stay in stage files.
    sf = @(name) fullfile(run_output, 'results', [name '.mat']);
    result = struct();
    result.success = true;

    if isfile(sf('stage01_bids'))
        s = load(sf('stage01_bids'));
        result.task = s.task;
        result.fs = s.fs;
        result.conditions = s.conditions;
        result.channel_labels = s.channel_labels;
        result.n_channels = s.n_channels_good;
        result.n_channels_raw = s.n_channels_raw;
        result.bad_channels = s.bad_channels;
        result.meta = s.meta;
        result.preproc_info = struct();
    end
    if isfile(sf('stage02_config'))
        s = load(sf('stage02_config'));
        result.config = s.cfg;
    end
    if isfile(sf('stage03_preproc'))
        s = load(sf('stage03_preproc'));
        result.preproc_info = s.preproc_info;
    end
    if isfile(sf('stage04_epochs'))
        s = load(sf('stage04_epochs'), 'n_trials', 'n_channels', 'n_timepoints', 'time_vec');
        result.n_trials = s.n_trials;
        result.n_channels = s.n_channels;
        result.n_timepoints = s.n_timepoints;
        result.time_vec = s.time_vec;
    end
    if isfile(sf('stage05_qc'))
        s = load(sf('stage05_qc'));
        result.trial_labels = s.trial_labels;
        result.trial_weights = s.trial_weights;
        result.condition_labels = s.condition_labels;
    end
    if isfile(sf('stage06_erp'))
        s = load(sf('stage06_erp'));
        result.erp = s.erp;
        result.erp_sem = s.erp_sem;
    end
    if isfile(sf('stage07_timefreq'))
        s = load(sf('stage07_timefreq'), 'freqs');
        result.freqs = s.freqs;
        % NOT loading tf_power_norm here - too large for legacy file
    end
    if isfile(sf('stage08_phase'))
        s = load(sf('stage08_phase'));
        result.itpc = s.itpc;
    end
    if isfile(sf('stage09_stats'))
        s = load(sf('stage09_stats'));
        result.stats = s.stats_results;
    end
    if isfile(sf('stage11_latent'))
        s = load(sf('stage11_latent'), 'latent_model', 'cond_trajectories', 'cond_indices');
        result.latent_model = s.latent_model;
        result.cond_trajectories = s.cond_trajectories;
        result.cond_indices = s.cond_indices;
    end
    if isfile(sf('stage12_geometry'))
        s = load(sf('stage12_geometry'));
        result.geometry = s.geom;
        result.separation = s.separation;
    end
    if isfile(sf('stage13_dynamics'))
        s = load(sf('stage13_dynamics'));
        result.dynamics = s.dynamics;
    end
    if isfile(sf('stage14_decoding'))
        s = load(sf('stage14_decoding'));
        result.decoding = s.decoding;
    end
    if isfile(sf('stage14b_contrasts'))
        s = load(sf('stage14b_contrasts'));
        result.contrasts = s.contrasts;
        result.contrast_results = s.contrast_results;
    end
    if isfile(sf('stage15_bootstrap'))
        s = load(sf('stage15_bootstrap'));
        result.bootstrap = s.bootstrap;
    end
    if isfile(sf('stage16_roi'))
        s = load(sf('stage16_roi'));
        result.roi_groups = s.roi_groups;
        result.roi_results = s.roi_results;
    end

    save(fullfile(run_output, 'results.mat'), 'result', '-v7.3');
end
