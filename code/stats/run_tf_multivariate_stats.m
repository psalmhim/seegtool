function tf_stats = run_tf_multivariate_stats(tf_power, trial_tensor, condition_labels, time_vec, freqs, cfg)
% RUN_TF_MULTIVARIATE_STATS Multivariate time-frequency statistical analysis.
%
%   tf_stats = run_tf_multivariate_stats(tf_power, trial_tensor, condition_labels, time_vec, freqs, cfg)
%
%   Comprehensive TF analysis beyond pointwise testing:
%     1. TF cluster-based permutation (controls FWER across freq x time)
%     2. Adaptive peak frequency detection per channel
%     3. Band-specific power contrasts (theta, alpha, beta, gamma, HFA)
%     4. Multivariate pattern analysis on TF features
%     5. Cross-frequency coupling (PAC)
%
%   Inputs:
%       tf_power         - trials x channels x freqs x time (baseline-normalized)
%       trial_tensor     - trials x channels x time (ERP data)
%       condition_labels - cell array of condition strings
%       time_vec         - time vector (seconds)
%       freqs            - frequency vector (Hz)
%       cfg              - pipeline config
%
%   Output:
%       tf_stats - struct with all TF statistical results

    conditions = unique(condition_labels, 'stable');
    n_conds = numel(conditions);
    n_trials = size(tf_power, 1);
    n_ch = size(tf_power, 2);
    n_freq = numel(freqs);
    n_time = size(tf_power, 4);

    n_perms = 500;
    if isfield(cfg, 'n_permutations'); n_perms = cfg.n_permutations; end
    cluster_thresh = 2.0;
    if isfield(cfg, 'cluster_threshold'); cluster_thresh = cfg.cluster_threshold; end
    alpha = 0.05;
    if isfield(cfg, 'alpha'); alpha = cfg.alpha; end

    fprintf('[TF-Stats] %d trials, %d ch, %d freq, %d time, %d conditions\n', ...
        n_trials, n_ch, n_freq, n_time, n_conds);

    tf_stats = struct();
    tf_stats.freqs = freqs;
    tf_stats.time_vec = time_vec;
    tf_stats.conditions = conditions;

    if n_conds < 2
        fprintf('[TF-Stats] Single condition — skipping contrast analyses\n');
        tf_stats.cluster_contrasts = struct([]);
        tf_stats.band_contrasts = struct([]);
        tf_stats.adaptive_peaks = detect_adaptive_peaks(tf_power, freqs, cfg);
        tf_stats.mvpa = struct([]);
        tf_stats.pac = struct([]);
        return;
    end

    %% 1. TF cluster-based permutation per condition pair
    fprintf('[TF-Stats] Running cluster-based TF permutation tests...\n');
    tf_stats.cluster_contrasts = run_tf_cluster_contrasts( ...
        tf_power, condition_labels, conditions, n_perms, cluster_thresh, alpha, freqs);

    %% 2. Adaptive peak frequency detection
    fprintf('[TF-Stats] Detecting adaptive peak frequencies...\n');
    tf_stats.adaptive_peaks = detect_adaptive_peaks(tf_power, freqs, cfg);

    %% 3. Band-specific contrasts
    fprintf('[TF-Stats] Running band-specific contrasts...\n');
    tf_stats.band_contrasts = run_band_contrasts( ...
        tf_power, condition_labels, conditions, freqs, time_vec, n_perms, cfg);

    %% 4. Multivariate pattern analysis on TF features
    fprintf('[TF-Stats] Running multivariate TF decoding...\n');
    tf_stats.mvpa = run_tf_mvpa(tf_power, condition_labels, conditions, freqs, time_vec, cfg);

    %% 5. Phase-amplitude coupling (if enough trials)
    fprintf('[TF-Stats] Computing phase-amplitude coupling...\n');
    tf_stats.pac = compute_pac_stats(trial_tensor, condition_labels, conditions, cfg);

    %% Summary
    n_sig_clusters = 0;
    for ci = 1:numel(tf_stats.cluster_contrasts)
        if tf_stats.cluster_contrasts(ci).n_sig_clusters > 0
            n_sig_clusters = n_sig_clusters + tf_stats.cluster_contrasts(ci).n_sig_clusters;
        end
    end
    tf_stats.n_sig_clusters_total = n_sig_clusters;

    n_sig_bands = 0;
    for ci = 1:numel(tf_stats.band_contrasts)
        if isfield(tf_stats.band_contrasts(ci), 'any_significant')
            n_sig_bands = n_sig_bands + tf_stats.band_contrasts(ci).any_significant;
        end
    end
    tf_stats.n_sig_band_contrasts = n_sig_bands;

    fprintf('[TF-Stats] Done: %d sig clusters, %d sig band contrasts\n', ...
        n_sig_clusters, n_sig_bands);
end


%% ======================================================================
%  1. TF cluster-based permutation (channel-averaged)
%% ======================================================================
function results = run_tf_cluster_contrasts(tf_power, condition_labels, conditions, n_perms, cluster_thresh, alpha, freqs)
    n_conds = numel(conditions);
    results = struct([]);

    % For each pair of conditions
    pair_idx = 0;
    for ci = 1:n_conds
        for cj = (ci+1):n_conds
            pair_idx = pair_idx + 1;
            idx_A = strcmp(condition_labels, conditions{ci});
            idx_B = strcmp(condition_labels, conditions{cj});

            % Average across channels → trials x freqs x time
            tf_A = squeeze(mean(tf_power(idx_A, :, :, :), 2));
            tf_B = squeeze(mean(tf_power(idx_B, :, :, :), 2));

            % Handle single-trial case
            if sum(idx_A) == 1; tf_A = reshape(tf_A, 1, size(tf_A,1), size(tf_A,2)); end
            if sum(idx_B) == 1; tf_B = reshape(tf_B, 1, size(tf_B,1), size(tf_B,2)); end

            fprintf('  [Cluster] %s vs %s (%d vs %d trials)...\n', ...
                conditions{ci}, conditions{cj}, sum(idx_A), sum(idx_B));

            [sig_mask, cluster_stats, p_vals] = cluster_tf_permutation( ...
                tf_A, tf_B, n_perms, cluster_thresh, alpha);

            r = struct();
            r.cond_A = conditions{ci};
            r.cond_B = conditions{cj};
            r.sig_mask = sig_mask;
            r.cluster_stats = cluster_stats;
            r.cluster_p = p_vals;
            r.n_sig_clusters = sum(p_vals < alpha);
            r.n_total_clusters = numel(cluster_stats);

            % Identify which frequency bands the clusters span
            r.cluster_bands = identify_cluster_bands(sig_mask, freqs);

            if r.n_sig_clusters > 0
                fprintf('    ** %d significant cluster(s) **\n', r.n_sig_clusters);
                for bi = 1:numel(r.cluster_bands)
                    b = r.cluster_bands(bi);
                    fprintf('    Cluster %d: %.0f-%.0f Hz, %.0f-%.0f ms (stat=%.1f, p=%.4f)\n', ...
                        bi, b.freq_range(1), b.freq_range(2), ...
                        b.time_range(1)*1000, b.time_range(2)*1000, ...
                        b.cluster_stat, b.p_value);
                end
            end

            if isempty(results)
                results = r;
            else
                results(end+1) = r;
            end
        end
    end

    if isempty(results)
        results = struct([]);
    end
end


function bands = identify_cluster_bands(sig_mask, freqs)
% Identify frequency/time ranges spanned by each connected cluster.
    bands = struct([]);
    if ~any(sig_mask(:)); return; end

    cc = bwconncomp(sig_mask);
    for i = 1:cc.NumObjects
        [freq_idx, time_idx] = ind2sub(size(sig_mask), cc.PixelIdxList{i});
        b = struct();
        b.freq_range = [min(freqs(freq_idx)), max(freqs(freq_idx))];
        b.time_range = [0, 0];  % placeholder, caller should fill with time_vec
        b.freq_idx = [min(freq_idx), max(freq_idx)];
        b.time_idx = [min(time_idx), max(time_idx)];
        b.n_pixels = numel(cc.PixelIdxList{i});
        b.cluster_stat = 0;
        b.p_value = NaN;

        if isempty(bands)
            bands = b;
        else
            bands(end+1) = b;
        end
    end
end


%% ======================================================================
%  2. Adaptive peak frequency detection
%% ======================================================================
function peaks = detect_adaptive_peaks(tf_power, freqs, cfg)
% Detect data-driven peak oscillation frequencies per channel.
%
% For each canonical band, finds the actual peak frequency in each channel
% during the post-stimulus window. This handles the case where HFA peak
% shifts across tasks/regions.

    n_ch = size(tf_power, 2);
    n_freq = numel(freqs);

    % Post-stimulus power (average across trials and time)
    % tf_power: trials x ch x freq x time
    mean_spectrum = squeeze(mean(mean(tf_power, 1, 'omitnan'), 4, 'omitnan'));  % ch x freq

    if isfield(cfg, 'freq_bands')
        band_names = fieldnames(cfg.freq_bands);
    else
        band_names = {'theta', 'alpha', 'beta', 'gamma', 'hfa'};
        cfg.freq_bands.theta = [4, 8];
        cfg.freq_bands.alpha = [8, 12];
        cfg.freq_bands.beta = [13, 30];
        cfg.freq_bands.gamma = [30, 70];
        cfg.freq_bands.hfa = [70, 150];
    end

    peaks = struct();
    peaks.freqs = freqs;
    peaks.mean_spectrum = mean_spectrum;
    peaks.bands = struct();

    for bi = 1:numel(band_names)
        bname = band_names{bi};
        brange = cfg.freq_bands.(bname);
        freq_mask = freqs >= brange(1) & freqs <= brange(2);

        if ~any(freq_mask); continue; end

        band_freqs = freqs(freq_mask);
        band_power = mean_spectrum(:, freq_mask);  % ch x band_freqs

        % Peak frequency per channel
        [peak_power, peak_idx] = max(band_power, [], 2);
        peak_freq = band_freqs(peak_idx);

        % Global peak (average across channels)
        global_spectrum = mean(band_power, 1);
        [~, global_peak_idx] = max(global_spectrum);
        global_peak = band_freqs(global_peak_idx);

        % Adaptive band: ±20% around global peak (min 2 Hz width)
        bw = max(global_peak * 0.2, 1);
        adaptive_range = [max(brange(1), global_peak - bw), ...
                          min(brange(2), global_peak + bw)];

        b = struct();
        b.nominal_range = brange;
        b.adaptive_range = adaptive_range;
        b.global_peak_freq = global_peak;
        b.peak_freq_per_ch = peak_freq;
        b.peak_power_per_ch = peak_power;
        b.mean_band_power = mean(band_power, 2);  % ch x 1

        peaks.bands.(bname) = b;
        fprintf('[AdaptivePeak] %s: nominal [%.0f-%.0f] Hz, peak %.1f Hz, adaptive [%.1f-%.1f] Hz\n', ...
            bname, brange(1), brange(2), global_peak, adaptive_range(1), adaptive_range(2));
    end
end


%% ======================================================================
%  3. Band-specific contrasts with cluster correction
%% ======================================================================
function results = run_band_contrasts(tf_power, condition_labels, conditions, freqs, time_vec, n_perms, cfg)
    n_conds = numel(conditions);
    n_ch = size(tf_power, 2);
    n_time = size(tf_power, 4);

    if isfield(cfg, 'freq_bands')
        band_names = fieldnames(cfg.freq_bands);
    else
        band_names = {'theta', 'alpha', 'beta', 'gamma', 'hfa'};
    end

    results = struct([]);
    pair_idx = 0;

    for ci = 1:n_conds
        for cj = (ci+1):n_conds
            pair_idx = pair_idx + 1;
            idx_A = strcmp(condition_labels, conditions{ci});
            idx_B = strcmp(condition_labels, conditions{cj});

            r = struct();
            r.cond_A = conditions{ci};
            r.cond_B = conditions{cj};
            r.band_results = struct();
            r.any_significant = false;

            for bi = 1:numel(band_names)
                bname = band_names{bi};
                brange = cfg.freq_bands.(bname);
                freq_mask = freqs >= brange(1) & freqs <= brange(2);
                if ~any(freq_mask); continue; end

                % Band power: average across freq within band → trials x ch x time
                bp_A = squeeze(mean(tf_power(idx_A, :, freq_mask, :), 3, 'omitnan'));
                bp_B = squeeze(mean(tf_power(idx_B, :, freq_mask, :), 3, 'omitnan'));

                % Channel-averaged band power for cluster test: trials x 1 x time
                bp_A_avg = squeeze(mean(bp_A, 2, 'omitnan'));  % trials x time
                bp_B_avg = squeeze(mean(bp_B, 2, 'omitnan'));

                n_A = sum(idx_A); n_B = sum(idx_B);

                % Pointwise t-test across time
                mean_A = mean(bp_A_avg, 1, 'omitnan');
                mean_B = mean(bp_B_avg, 1, 'omitnan');
                var_A = var(bp_A_avg, 0, 1, 'omitnan');
                var_B = var(bp_B_avg, 0, 1, 'omitnan');
                se = sqrt(var_A / max(n_A,1) + var_B / max(n_B,1));
                se(se == 0) = eps;
                t_obs = (mean_A - mean_B) ./ se;

                % Cluster-based correction on 1D time series
                [sig_time, clust_stats, clust_p] = cluster_1d_permutation( ...
                    bp_A_avg, bp_B_avg, n_perms);

                % Effect size (Cohen's d per timepoint)
                pooled_std = sqrt(((n_A-1)*var_A + (n_B-1)*var_B) / max(n_A+n_B-2, 1));
                pooled_std(pooled_std < eps) = eps;
                cohens_d = (mean_A - mean_B) ./ pooled_std;

                % Per-channel significance
                ch_p = zeros(n_ch, 1);
                ch_d = zeros(n_ch, 1);
                for ch = 1:n_ch
                    ch_A = squeeze(mean(bp_A(:, ch, :), 3, 'omitnan'));
                    ch_B = squeeze(mean(bp_B(:, ch, :), 3, 'omitnan'));
                    ch_diff = mean(ch_A) - mean(ch_B);
                    ch_se = sqrt(var(ch_A)/max(n_A,1) + var(ch_B)/max(n_B,1));
                    if ch_se > 0
                        ch_d(ch) = ch_diff / ch_se;
                    end

                    % Quick permutation
                    combined = [ch_A; ch_B];
                    null_diff = zeros(min(n_perms, 200), 1);
                    for pi = 1:size(null_diff,1)
                        pidx = randperm(n_A + n_B);
                        null_diff(pi) = mean(combined(pidx(1:n_A))) - mean(combined(pidx(n_A+1:end)));
                    end
                    ch_p(ch) = (sum(abs(null_diff) >= abs(ch_diff)) + 1) / (size(null_diff,1) + 1);
                end

                br = struct();
                br.band_range = brange;
                br.t_obs = t_obs;
                br.sig_time = sig_time;
                br.cluster_stats = clust_stats;
                br.cluster_p = clust_p;
                br.cohens_d = cohens_d;
                br.mean_power_A = mean_A;
                br.mean_power_B = mean_B;
                br.ch_p_values = ch_p;
                br.ch_effect_size = ch_d;
                br.n_sig_channels = sum(ch_p < 0.05);
                br.significant = any(sig_time);

                r.band_results.(bname) = br;
                if br.significant
                    r.any_significant = true;
                    fprintf('  [Band] %s vs %s, %s: ** SIGNIFICANT ** (%d sig ch)\n', ...
                        conditions{ci}, conditions{cj}, bname, br.n_sig_channels);
                end
            end

            if isempty(results)
                results = r;
            else
                results(end+1) = r;
            end
        end
    end

    if isempty(results)
        results = struct([]);
    end
end


function [sig_mask, cluster_stats, cluster_p] = cluster_1d_permutation(data_A, data_B, n_perms)
% 1D cluster-based permutation test on time series.
    n_A = size(data_A, 1);
    n_B = size(data_B, 1);
    n_time = size(data_A, 2);
    thresh = 2.0;

    % Observed t-statistic
    mean_A = mean(data_A, 1, 'omitnan');
    mean_B = mean(data_B, 1, 'omitnan');
    se = sqrt(var(data_A,0,1,'omitnan')/n_A + var(data_B,0,1,'omitnan')/n_B);
    se(se == 0) = eps;
    t_obs = (mean_A - mean_B) ./ se;

    % Find observed clusters
    obs_stats = find_1d_clusters(t_obs, thresh);

    % Null distribution
    combined = [data_A; data_B];
    n_total = n_A + n_B;
    null_max = zeros(n_perms, 1);

    for pi = 1:n_perms
        pidx = randperm(n_total);
        pA = combined(pidx(1:n_A), :);
        pB = combined(pidx(n_A+1:end), :);
        pse = sqrt(var(pA,0,1,'omitnan')/n_A + var(pB,0,1,'omitnan')/n_B);
        pse(pse == 0) = eps;
        t_perm = (mean(pA,1,'omitnan') - mean(pB,1,'omitnan')) ./ pse;
        perm_stats = find_1d_clusters(t_perm, thresh);
        if ~isempty(perm_stats)
            null_max(pi) = max(abs(perm_stats));
        end
    end

    % P-values
    n_clusters = numel(obs_stats);
    cluster_p = ones(n_clusters, 1);
    sig_mask = false(1, n_time);

    % Identify cluster locations
    pos_mask = t_obs > thresh;
    neg_mask = t_obs < -thresh;
    all_mask = pos_mask | neg_mask;
    if any(all_mask)
        cc = bwconncomp(all_mask);
        for c = 1:min(cc.NumObjects, n_clusters)
            cluster_p(c) = (sum(null_max >= abs(obs_stats(c))) + 1) / (n_perms + 1);
            if cluster_p(c) < 0.05
                sig_mask(cc.PixelIdxList{c}) = true;
            end
        end
    end

    cluster_stats = obs_stats;
end


function stats = find_1d_clusters(t_series, thresh)
    stats = [];
    pos_mask = t_series > thresh;
    neg_mask = t_series < -thresh;

    for sign = [1, -1]
        if sign == 1; mask = pos_mask; else; mask = neg_mask; end
        cc = bwconncomp(mask);
        for i = 1:cc.NumObjects
            stats(end+1) = sum(t_series(cc.PixelIdxList{i}));
        end
    end
end


%% ======================================================================
%  4. Multivariate pattern analysis on TF features
%% ======================================================================
function mvpa = run_tf_mvpa(tf_power, condition_labels, conditions, freqs, time_vec, cfg)
% Time-resolved multivariate decoding using TF features.
%
% Instead of decoding from single-channel ERP, uses the full
% channel x frequency feature vector at each time point.

    n_conds = numel(conditions);
    if n_conds < 2
        mvpa = struct([]);
        return;
    end

    n_trials = size(tf_power, 1);
    n_ch = size(tf_power, 2);
    n_freq = numel(freqs);
    n_time = size(tf_power, 4);

    n_folds = 5;
    if isfield(cfg, 'n_cv_folds'); n_folds = cfg.n_cv_folds; end

    % Use first two conditions for binary decoding
    idx_A = find(strcmp(condition_labels, conditions{1}));
    idx_B = find(strcmp(condition_labels, conditions{2}));
    all_idx = [idx_A; idx_B];
    labels = [ones(numel(idx_A), 1); -ones(numel(idx_B), 1)];
    n_total = numel(all_idx);

    if n_total < 2 * n_folds
        mvpa = struct('accuracy', [], 'note', 'insufficient trials');
        return;
    end

    % Create CV folds
    cv = crossvalind_simple(n_total, n_folds);

    % Time-resolved decoding
    accuracy = zeros(1, n_time);
    accuracy_per_band = struct();

    if isfield(cfg, 'freq_bands')
        band_names = fieldnames(cfg.freq_bands);
        for bi = 1:numel(band_names)
            accuracy_per_band.(band_names{bi}) = zeros(1, n_time);
        end
    end

    % Subsample time for speed (every 4th point)
    time_step = max(1, floor(n_time / 200));
    time_idx = 1:time_step:n_time;

    for ti_idx = 1:numel(time_idx)
        ti = time_idx(ti_idx);

        % Feature matrix: trials x (ch * freq)
        X = reshape(tf_power(all_idx, :, :, ti), n_total, []);
        X(isnan(X)) = 0;

        % Cross-validated LDA
        pred = zeros(n_total, 1);
        for fold = 1:n_folds
            test_mask = cv == fold;
            train_mask = ~test_mask;

            X_train = X(train_mask, :);
            y_train = labels(train_mask);
            X_test = X(test_mask, :);

            % Regularized LDA
            w = lda_classify(X_train, y_train);
            pred(test_mask) = sign(X_test * w);
        end
        accuracy(ti) = mean(pred == labels);

        % Per-band decoding
        if isfield(cfg, 'freq_bands')
            for bi = 1:numel(band_names)
                bname = band_names{bi};
                brange = cfg.freq_bands.(bname);
                freq_mask = freqs >= brange(1) & freqs <= brange(2);
                if ~any(freq_mask); continue; end

                X_band = reshape(tf_power(all_idx, :, freq_mask, ti), n_total, []);
                X_band(isnan(X_band)) = 0;

                pred_band = zeros(n_total, 1);
                for fold = 1:n_folds
                    test_mask = cv == fold;
                    train_mask = ~test_mask;
                    w = lda_classify(X_band(train_mask, :), labels(train_mask));
                    pred_band(test_mask) = sign(X_band(test_mask, :) * w);
                end
                accuracy_per_band.(bname)(ti) = mean(pred_band == labels);
            end
        end
    end

    % Interpolate to full time vector
    if numel(time_idx) < n_time
        accuracy_full = interp1(time_idx, accuracy, 1:n_time, 'linear', 0.5);
    else
        accuracy_full = accuracy;
    end

    % Permutation test for peak accuracy
    n_perm = min(200, cfg.n_permutations);
    null_peak = zeros(n_perm, 1);
    for pi = 1:n_perm
        perm_labels = labels(randperm(n_total));
        perm_acc = zeros(1, numel(time_idx));
        for ti_idx2 = 1:numel(time_idx)
            ti = time_idx(ti_idx2);
            X = reshape(tf_power(all_idx, :, :, ti), n_total, []);
            X(isnan(X)) = 0;
            pred = zeros(n_total, 1);
            for fold = 1:n_folds
                test_mask = cv == fold;
                w = lda_classify(X(~test_mask, :), perm_labels(~test_mask));
                pred(test_mask) = sign(X(test_mask, :) * w);
            end
            perm_acc(ti_idx2) = mean(pred == perm_labels);
        end
        null_peak(pi) = max(perm_acc);
    end

    peak_acc = max(accuracy);
    p_peak = (sum(null_peak >= peak_acc) + 1) / (n_perm + 1);

    mvpa = struct();
    mvpa.accuracy = accuracy_full;
    mvpa.time_vec = time_vec;
    mvpa.peak_accuracy = peak_acc;
    mvpa.p_peak = p_peak;
    mvpa.accuracy_per_band = accuracy_per_band;
    mvpa.conditions = {conditions{1}, conditions{2}};
    mvpa.n_features = n_ch * n_freq;

    fprintf('[MVPA-TF] Peak accuracy: %.1f%% (p=%.4f), %d features\n', ...
        peak_acc * 100, p_peak, n_ch * n_freq);
end


function w = lda_classify(X, y)
% Simple regularized LDA.
    classes = unique(y);
    mu1 = mean(X(y == classes(1), :), 1);
    mu2 = mean(X(y == classes(2), :), 1);
    n1 = sum(y == classes(1));
    n2 = sum(y == classes(2));

    % Handle NaN/Inf features
    X(~isfinite(X)) = 0;

    % Remove zero-variance features
    feat_var = var(X, 0, 1);
    keep = feat_var > 0;
    if sum(keep) == 0
        w = zeros(size(X, 2), 1);
        return;
    end
    X_red = X(:, keep);

    mu1_r = mean(X_red(y == classes(1), :), 1);
    mu2_r = mean(X_red(y == classes(2), :), 1);

    S1 = cov(X_red(y == classes(1), :));
    S2 = cov(X_red(y == classes(2), :));
    Sw = ((n1 - 1) * S1 + (n2 - 1) * S2) / (n1 + n2 - 2);

    % Adaptive regularization: scale with trace to handle any feature magnitude
    lambda = max(0.1 * trace(Sw) / size(Sw, 1), 1e-3);
    Sw = Sw + lambda * eye(size(Sw, 1));

    w_red = Sw \ (mu1_r - mu2_r)';

    % Map back to full feature space
    w = zeros(size(X, 2), 1);
    w(keep) = w_red;
end


function cv = crossvalind_simple(n, k)
% Simple k-fold cross-validation index assignment.
    cv = zeros(n, 1);
    idx = randperm(n);
    fold_size = floor(n / k);
    for f = 1:k
        if f < k
            cv(idx((f-1)*fold_size + 1 : f*fold_size)) = f;
        else
            cv(idx((f-1)*fold_size + 1 : end)) = f;
        end
    end
end


%% ======================================================================
%  5. Phase-amplitude coupling
%% ======================================================================
function pac = compute_pac_stats(trial_tensor, condition_labels, conditions, cfg)
% Compute phase-amplitude coupling (modulation index) between
% low-frequency phase and high-frequency amplitude.

    n_trials = size(trial_tensor, 1);
    n_ch = size(trial_tensor, 2);
    fs = cfg.fs;

    % Phase frequencies (theta, alpha) and amplitude frequencies (gamma, HFA)
    phase_bands = [4 8; 8 12];     % theta, alpha
    amp_bands = [30 70; 70 150];   % gamma, HFA
    phase_names = {'theta', 'alpha'};
    amp_names = {'gamma', 'hfa'};

    n_phase = size(phase_bands, 1);
    n_amp = size(amp_bands, 1);

    % Subsample channels for speed
    ch_step = max(1, floor(n_ch / 20));
    ch_idx = 1:ch_step:n_ch;
    n_ch_sub = numel(ch_idx);

    pac = struct();
    pac.phase_bands = phase_bands;
    pac.amp_bands = amp_bands;
    pac.phase_names = phase_names;
    pac.amp_names = amp_names;
    pac.channel_idx = ch_idx;

    % Compute MI per condition
    n_conds = numel(conditions);
    pac.mi = struct();

    for ci = 1:n_conds
        cname = matlab.lang.makeValidName(conditions{ci});
        idx = strcmp(condition_labels, conditions{ci});
        cond_data = trial_tensor(idx, ch_idx, :);  % n_c x ch_sub x time
        n_c = sum(idx);

        mi_matrix = zeros(n_phase, n_amp, n_ch_sub);

        for phi = 1:n_phase
            for ai = 1:n_amp
                for ch = 1:n_ch_sub
                    mi_trials = zeros(n_c, 1);
                    for tr = 1:n_c
                        sig = squeeze(cond_data(tr, ch, :))';
                        mi_trials(tr) = compute_mi(sig, fs, phase_bands(phi,:), amp_bands(ai,:));
                    end
                    mi_matrix(phi, ai, ch) = mean(mi_trials, 'omitnan');
                end
            end
        end

        pac.mi.(cname) = mi_matrix;
    end

    % Contrast MI between conditions (if 2+)
    pac.contrast = struct([]);
    if n_conds >= 2
        for ci = 1:n_conds
            for cj = (ci+1):n_conds
                nameA = matlab.lang.makeValidName(conditions{ci});
                nameB = matlab.lang.makeValidName(conditions{cj});
                mi_diff = pac.mi.(nameA) - pac.mi.(nameB);
                c = struct();
                c.cond_A = conditions{ci};
                c.cond_B = conditions{cj};
                c.mi_diff = mi_diff;
                c.mean_diff = mean(mi_diff(:));
                c.max_diff = max(abs(mi_diff(:)));

                if isempty(pac.contrast)
                    pac.contrast = c;
                else
                    pac.contrast(end+1) = c;
                end
            end
        end
    end
end


function mi = compute_mi(sig, fs, phase_band, amp_band)
% Modulation index (Tort et al., 2010).
    try
        % Extract phase of low frequency
        phase_sig = bandpass_filter(sig, fs, phase_band);
        phase_angle = angle(hilbert(phase_sig));

        % Extract amplitude of high frequency
        amp_sig = bandpass_filter(sig, fs, amp_band);
        amp_env = abs(hilbert(amp_sig));

        % Binned MI
        n_bins = 18;
        bin_edges = linspace(-pi, pi, n_bins + 1);
        mean_amp = zeros(1, n_bins);
        for b = 1:n_bins
            mask = phase_angle >= bin_edges(b) & phase_angle < bin_edges(b+1);
            if any(mask)
                mean_amp(b) = mean(amp_env(mask));
            end
        end

        % Normalize
        mean_amp = mean_amp / sum(mean_amp);
        mean_amp(mean_amp == 0) = eps;

        % KL divergence from uniform
        uniform = ones(1, n_bins) / n_bins;
        mi = sum(mean_amp .* log(mean_amp ./ uniform)) / log(n_bins);
    catch
        mi = NaN;
    end
end


function y = bandpass_filter(x, fs, band)
% Simple 4th-order Butterworth bandpass.
    nyq = fs / 2;
    lo = max(band(1) / nyq, 0.001);
    hi = min(band(2) / nyq, 0.999);
    [b, a] = butter(4, [lo, hi], 'bandpass');
    y = filtfilt(b, a, double(x));
end
