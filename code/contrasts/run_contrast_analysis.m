function results = run_contrast_analysis(trial_tensor, contrasts, time_vec, cfg, varargin)
% RUN_CONTRAST_ANALYSIS Hierarchical contrast analysis (Level 1 → Level 2).
%
%   results = run_contrast_analysis(trial_tensor, contrasts, time_vec, cfg)
%   results = run_contrast_analysis(..., 'L1', L1, 'latent_tensor', lat)
%
%   Two-level hierarchical framework analogous to SPM/FSL:
%
%     LEVEL 1 (First-level estimation):
%       Per-condition parameter estimates (betas):
%         - ERP: mean waveform per condition
%         - TF: mean spectral power per condition
%         - Latent: centroid trajectory per condition
%         - Dispersion, variance, covariance per condition
%
%     LEVEL 2 (Contrast application + inference):
%       For each contrast c = [w1, w2, ...]:
%         - Contrast value: c' * beta (weighted combination of L1 estimates)
%         - Permutation test on contrast (shuffling trial labels)
%         - Effect size (Cohen's d from contrast t-statistic)
%         - Time-resolved decoding (binary classification)
%
%   Inputs:
%       trial_tensor  - trials x channels x time
%       contrasts     - struct array from define_contrasts()
%       time_vec      - time vector in seconds
%       cfg           - pipeline config
%
%   Name-Value:
%       'L1'              - pre-computed L1 (skips re-computation)
%       'latent_tensor'   - trials x dims x time
%       'condition_labels'- cell array (required if L1 not provided)
%       'tf_power'        - trials x ch x freq x time
%       'tf_phase'        - trials x ch x freq x time
%       'freqs'           - frequency vector
%       'trial_weights'   - trials x 1
%       'n_permutations'  - override cfg.n_permutations
%       'alpha'           - significance level
%       'analyses'        - {'permutation','separation','decoding','effect_size'}
%
%   Output:
%       results - struct with:
%         .L1         - first-level estimates
%         .contrasts  - struct array, one per contrast, each with:
%             .contrast    - spec
%             .values      - contrast values from apply_contrast_weights
%             .permutation - L2 permutation test results
%             .decoding    - L2 decoding results
%             .significant - logical
%             .p_min       - minimum p-value
%             .sig_windows - cell of [start_ms, end_ms]

    p = inputParser;
    addParameter(p, 'L1', []);
    addParameter(p, 'latent_tensor', []);
    addParameter(p, 'condition_labels', {});
    addParameter(p, 'tf_power', []);
    addParameter(p, 'tf_phase', []);
    addParameter(p, 'freqs', []);
    addParameter(p, 'trial_weights', []);
    addParameter(p, 'n_permutations', []);
    addParameter(p, 'alpha', []);
    addParameter(p, 'analyses', {'permutation', 'separation', 'decoding', 'effect_size'});
    parse(p, varargin{:});

    latent = p.Results.latent_tensor;
    run_analyses = p.Results.analyses;

    n_perms = cfg.n_permutations;
    if ~isempty(p.Results.n_permutations); n_perms = p.Results.n_permutations; end

    alpha = 0.05;
    if isfield(cfg, 'alpha'); alpha = cfg.alpha; end
    if ~isempty(p.Results.alpha); alpha = p.Results.alpha; end

    %% ================================================================
    %  LEVEL 1: First-level estimation (per-condition betas)
    %% ================================================================
    if ~isempty(p.Results.L1)
        L1 = p.Results.L1;
        fprintf('[Contrast] Using pre-computed L1 estimates\n');
    else
        cond_labels = p.Results.condition_labels;
        if isempty(cond_labels)
            % Reconstruct from first contrast's groups
            cond_labels = cell(size(trial_tensor, 1), 1);
            for ci = 1:numel(contrasts)
                con = contrasts(ci);
                if ~isempty(con.idx_A)
                    cond_labels(con.idx_A) = con.groups{1}(1);
                end
                if ~isempty(con.idx_B)
                    cond_labels(con.idx_B) = con.groups{2}(1);
                end
            end
        end

        L1_args = {};
        if ~isempty(latent); L1_args = [L1_args, 'latent_tensor', latent]; end
        if ~isempty(p.Results.tf_power); L1_args = [L1_args, 'tf_power', p.Results.tf_power]; end
        if ~isempty(p.Results.tf_phase); L1_args = [L1_args, 'tf_phase', p.Results.tf_phase]; end
        if ~isempty(p.Results.freqs); L1_args = [L1_args, 'freqs', p.Results.freqs]; end
        if ~isempty(p.Results.trial_weights); L1_args = [L1_args, 'trial_weights', p.Results.trial_weights]; end

        L1 = compute_first_level_estimates(trial_tensor, cond_labels, time_vec, cfg, L1_args{:});
    end

    results = struct();
    results.L1 = L1;

    %% ================================================================
    %  LEVEL 2: Contrast application + statistical inference
    %% ================================================================
    n_contrasts = numel(contrasts);
    con_results_cell = cell(1, n_contrasts);

    for ci = 1:n_contrasts
        con = contrasts(ci);
        fprintf('\n[L2 %d/%d] Contrast: %s (nA=%d, nB=%d)\n', ...
            ci, n_contrasts, con.name, con.n_A, con.n_B);

        cr = make_empty_cr(con, run_analyses);

        if con.n_A < 2 || con.n_B < 2
            fprintf('  Skipping: insufficient trials\n');
            con_results_cell{ci} = cr;
            continue;
        end

        %% Step 2a: Apply contrast weights to L1 estimates
        cr.values = apply_contrast_weights(L1, con);

        %% Step 2b: Permutation test on contrast (label shuffling)
        if ismember('permutation', run_analyses)
            try
                cr.permutation = permutation_test_contrast( ...
                    cr.values, L1, con, time_vec, n_perms, alpha);
            catch ME
                fprintf('  Permutation failed: %s\n', ME.message);
            end
        end

        %% Step 2c: Effect size from contrast t-statistic
        if ismember('effect_size', run_analyses) && isfield(cr.values, 'erp_t')
            cr.effect_size = struct();
            cr.effect_size.t_map = cr.values.erp_t;
            df = cr.values.n_A + cr.values.n_B - 2;
            cr.effect_size.cohens_d = 2 * cr.values.erp_t / sqrt(max(df, 1));
            cr.effect_size.mean_d = mean(cr.effect_size.cohens_d, 1);
        end

        %% Step 2d: Separation in latent space (from contrast centroids)
        if ismember('separation', run_analyses) && isfield(cr.values, 'separation_norm')
            try
                cr.separation = permutation_test_separation( ...
                    cr.values, L1, con, time_vec, n_perms, alpha);
            catch ME
                fprintf('  Separation test failed: %s\n', ME.message);
            end
        end

        %% Step 2e: Decoding (binary classification)
        if ismember('decoding', run_analyses)
            try
                cr.decoding = run_contrast_decoding(cr.values, time_vec, cfg);
            catch ME
                fprintf('  Decoding failed: %s\n', ME.message);
            end
        end

        %% Aggregate significance across analyses
        cr = aggregate_significance(cr, alpha, time_vec);
        con_results_cell{ci} = cr;

        if cr.significant
            fprintf('  ** SIGNIFICANT ** (p_min = %.4f)\n', cr.p_min);
        else
            fprintf('  Not significant (p_min = %.4f)\n', cr.p_min);
        end
    end

    % Convert cell to struct array with uniform fields
    con_results = [con_results_cell{:}];

    results.contrasts = con_results;

    n_sig = sum([con_results.significant]);
    fprintf('\n[Contrast] %d/%d contrasts significant\n', n_sig, n_contrasts);
end


%% ======================================================================
%  Level 2 statistical inference functions
%% ======================================================================

function perm = permutation_test_contrast(C, L1, con, time_vec, n_perms, alpha)
% Permutation test: shuffle trial labels, recompute L1 betas, reapply contrast.
%
%   Under H0, the condition labels are exchangeable.
%   For each permutation:
%     1. Shuffle trial labels
%     2. Recompute per-condition means (L1 betas) with shuffled labels
%     3. Apply the same contrast weights → null contrast value
%     4. Compare observed vs null

    if ~isfield(C, 'trial_data_A') || ~isfield(C, 'trial_data_B')
        perm = struct();
        return;
    end

    data_A = C.trial_data_A;  % n_A x ch x time
    data_B = C.trial_data_B;  % n_B x ch x time
    n_A = size(data_A, 1);
    n_B = size(data_B, 1);
    n_total = n_A + n_B;
    all_data = cat(1, data_A, data_B);

    % Observed contrast ERP
    obs_mean_A = squeeze(mean(data_A, 1));
    obs_mean_B = squeeze(mean(data_B, 1));
    obs_diff = obs_mean_A - obs_mean_B;

    n_ch = size(obs_diff, 1);
    n_t = size(obs_diff, 2);

    % Observed t-statistic
    obs_t = compute_tstat_two(data_A, data_B);
    obs_mass = max_cluster_mass(obs_t, 2.0);

    % Null distribution by permutation
    null_mass = zeros(n_perms, 1);
    null_diff = zeros(n_perms, n_ch, n_t);

    for pi = 1:n_perms
        perm_idx = randperm(n_total);
        perm_A = all_data(perm_idx(1:n_A), :, :);
        perm_B = all_data(perm_idx(n_A+1:end), :, :);

        perm_mean_A = squeeze(mean(perm_A, 1));
        perm_mean_B = squeeze(mean(perm_B, 1));
        null_diff(pi, :, :) = perm_mean_A - perm_mean_B;

        perm_t = compute_tstat_two(perm_A, perm_B);
        null_mass(pi) = max_cluster_mass(perm_t, 2.0);
    end

    % Cluster-corrected p-value
    p_global = (sum(null_mass >= obs_mass) + 1) / (n_perms + 1);

    % Pointwise p-values
    p_values = zeros(n_ch, n_t);
    for ch = 1:n_ch
        for t = 1:n_t
            p_values(ch, t) = (sum(abs(null_diff(:, ch, t)) >= abs(obs_diff(ch, t))) + 1) / (n_perms + 1);
        end
    end

    perm = struct();
    perm.p_values = p_values;
    perm.p_global = p_global;
    perm.observed_diff = obs_diff;
    perm.observed_t = obs_t;
    perm.null_distribution = null_mass;
    perm.observed_stat = obs_mass;
    perm.sig_mask = p_values < alpha;
    perm.time_vec = time_vec;
end


function sep = permutation_test_separation(C, L1, con, time_vec, n_perms, alpha)
% Permutation test on latent space separation.
%
%   Under H0: shuffle trial labels → recompute centroids → recompute separation.

    if ~isfield(C, 'latent_data_A') || ~isfield(C, 'latent_data_B')
        sep = struct();
        return;
    end

    lat_A = C.latent_data_A;  % n_A x dims x time
    lat_B = C.latent_data_B;  % n_B x dims x time
    n_A = size(lat_A, 1);
    n_B = size(lat_B, 1);
    n_total = n_A + n_B;
    all_lat = cat(1, lat_A, lat_B);
    n_t = size(all_lat, 3);

    % Observed separation (already in C.separation_norm if available)
    if isfield(C, 'separation_norm')
        obs_sep = C.separation_norm;
    else
        obs_sep = C.separation;
    end

    % Null distribution
    null_sep = zeros(n_perms, n_t);
    for pi = 1:n_perms
        perm_idx = randperm(n_total);
        perm_A = all_lat(perm_idx(1:n_A), :, :);
        perm_B = all_lat(perm_idx(n_A+1:end), :, :);

        for t = 1:n_t
            c_A = mean(squeeze(perm_A(:, :, t)), 1);
            c_B = mean(squeeze(perm_B(:, :, t)), 1);

            d_A = mean(sqrt(sum((squeeze(perm_A(:, :, t)) - c_A).^2, 2)));
            d_B = mean(sqrt(sum((squeeze(perm_B(:, :, t)) - c_B).^2, 2)));
            denom = (d_A + d_B) / 2;
            if denom > 0
                null_sep(pi, t) = norm(c_A - c_B) / denom;
            end
        end
    end

    % P-values
    p_values = zeros(1, n_t);
    for t = 1:n_t
        p_values(t) = (sum(null_sep(:, t) >= obs_sep(t)) + 1) / (n_perms + 1);
    end

    sep = struct();
    sep.index = obs_sep;
    sep.p_values = p_values;
    sep.time_vec = time_vec;
    sep.null_distribution = null_sep;
    sep.sig_mask = p_values < alpha;
end


function dec = run_contrast_decoding(C, time_vec, cfg)
% Time-resolved decoding between contrast groups.
%
%   Uses trial-level data from the two contrast groups.
%   Classification operates on group A vs group B at each time point.

    if ~isfield(C, 'trial_data_A') || ~isfield(C, 'trial_data_B')
        dec = struct();
        return;
    end

    % Use latent data if available (better for decoding), else raw
    if isfield(C, 'latent_data_A') && ~isempty(C.latent_data_A)
        data_A = C.latent_data_A;
        data_B = C.latent_data_B;
    else
        data_A = C.trial_data_A;
        data_B = C.trial_data_B;
    end

    n_A = size(data_A, 1);
    n_B = size(data_B, 1);
    n_t = size(data_A, 3);

    all_data = cat(1, data_A, data_B);
    labels = [repmat({'A'}, n_A, 1); repmat({'B'}, n_B, 1)];

    n_folds = min(cfg.n_cv_folds, min(n_A, n_B));
    if n_folds < 2
        dec = struct();
        return;
    end

    % Time-resolved cross-validated accuracy
    accuracy = zeros(1, n_t);
    for t = 1:n_t
        X = squeeze(all_data(:, :, t));
        accuracy(t) = cross_validate_single(X, labels, n_folds);
    end

    % Permutation test
    n_perms = min(cfg.n_permutations, 200);
    null_acc = zeros(n_perms, n_t);
    for pi = 1:n_perms
        perm_labels = labels(randperm(numel(labels)));
        for t = 1:n_t
            X = squeeze(all_data(:, :, t));
            null_acc(pi, t) = cross_validate_single(X, perm_labels, n_folds);
        end
    end

    p_values = zeros(1, n_t);
    for t = 1:n_t
        p_values(t) = (sum(null_acc(:, t) >= accuracy(t)) + 1) / (n_perms + 1);
    end

    % Onset detection
    sig_mask = p_values < 0.05;
    onset_idx = find(sig_mask & time_vec > 0, 1);
    onset_time = NaN;
    if ~isempty(onset_idx)
        onset_time = time_vec(onset_idx);
    end

    dec = struct();
    dec.accuracy_time = accuracy;
    dec.p_values = p_values;
    dec.time_vec = time_vec;
    dec.chance_level = 0.5;
    dec.onset_time = onset_time;
end


%% ======================================================================
%  Statistical utilities
%% ======================================================================

function t = compute_tstat_two(data_A, data_B)
% Independent two-sample t-stat at each channel x time point.
    n_A = size(data_A, 1);
    n_B = size(data_B, 1);
    mean_A = squeeze(mean(data_A, 1));
    mean_B = squeeze(mean(data_B, 1));
    var_A = squeeze(var(data_A, 0, 1));
    var_B = squeeze(var(data_B, 0, 1));
    se = sqrt(var_A / n_A + var_B / n_B);
    se(se == 0) = eps;
    t = (mean_A - mean_B) ./ se;
end


function mass = max_cluster_mass(t_map, threshold)
    sig = abs(t_map) > threshold;
    if ~any(sig(:))
        mass = 0;
        return;
    end
    if size(t_map, 1) == 1
        labeled = label_clusters_1d(sig);
        mass = 0;
        for c = 1:max(labeled)
            mass = max(mass, abs(sum(t_map(labeled == c))));
        end
    else
        mass = sum(abs(t_map(sig)));
    end
end


function labeled = label_clusters_1d(mask)
    labeled = zeros(size(mask));
    cluster_id = 0;
    in_cluster = false;
    for i = 1:numel(mask)
        if mask(i) && ~in_cluster
            cluster_id = cluster_id + 1;
            in_cluster = true;
        elseif ~mask(i)
            in_cluster = false;
        end
        if mask(i)
            labeled(i) = cluster_id;
        end
    end
end


function acc = cross_validate_single(X, labels, n_folds)
    n = size(X, 1);
    cv = zeros(n, 1);
    idx = randperm(n);
    fold_size = floor(n / n_folds);
    for f = 1:n_folds
        if f < n_folds
            cv(idx((f-1)*fold_size+1 : f*fold_size)) = f;
        else
            cv(idx((f-1)*fold_size+1 : end)) = f;
        end
    end

    correct = 0;
    total = 0;
    unique_labels = unique(labels);

    for fold = 1:n_folds
        test_mask = cv == fold;
        train_mask = ~test_mask;

        X_train = X(train_mask, :);
        y_train = labels(train_mask);
        X_test = X(test_mask, :);
        y_test = labels(test_mask);

        % Nearest centroid
        centroids = zeros(numel(unique_labels), size(X_train, 2));
        for c = 1:numel(unique_labels)
            mask_c = strcmp(y_train, unique_labels{c});
            if any(mask_c)
                centroids(c, :) = mean(X_train(mask_c, :), 1);
            end
        end

        for i = 1:size(X_test, 1)
            dists = sum((centroids - X_test(i, :)).^2, 2);
            [~, best] = min(dists);
            if strcmp(unique_labels{best}, y_test{i})
                correct = correct + 1;
            end
            total = total + 1;
        end
    end

    acc = correct / max(total, 1);
end


function cr = aggregate_significance(cr, alpha, time_vec)
    cr.p_min = NaN;
    cr.significant = false;
    cr.sig_windows = {};

    % Check separation
    if isfield(cr, 'separation') && isfield(cr.separation, 'p_values')
        p_min = min(cr.separation.p_values);
        if isnan(cr.p_min) || p_min < cr.p_min
            cr.p_min = p_min;
        end
        if p_min < alpha
            cr.significant = true;
            cr.sig_windows = find_sig_windows(cr.separation.time_vec, ...
                cr.separation.p_values < alpha);
        end
    end

    % Check permutation
    if isfield(cr, 'permutation') && isfield(cr.permutation, 'p_global')
        if cr.permutation.p_global < alpha
            cr.significant = true;
        end
        if isnan(cr.p_min) || cr.permutation.p_global < cr.p_min
            cr.p_min = cr.permutation.p_global;
        end
    end

    % Check decoding
    if isfield(cr, 'decoding') && isfield(cr.decoding, 'p_values')
        p_min = min(cr.decoding.p_values);
        if p_min < alpha
            cr.significant = true;
        end
    end
end


function windows = find_sig_windows(time_vec, sig_mask)
    windows = {};
    in_win = false;
    start_t = 0;
    for i = 1:numel(sig_mask)
        if sig_mask(i) && ~in_win
            in_win = true;
            start_t = time_vec(i);
        elseif ~sig_mask(i) && in_win
            in_win = false;
            windows{end+1} = [start_t * 1000, time_vec(i-1) * 1000];
        end
    end
    if in_win
        windows{end+1} = [start_t * 1000, time_vec(end) * 1000];
    end
end


function cr = make_empty_cr(con, analyses)
% Create a contrast result struct with ALL fields pre-initialized.
% This ensures uniform struct fields across all contrasts.
    cr = struct();
    cr.contrast = con;
    cr.significant = false;
    cr.p_min = NaN;
    cr.sig_windows = {};
    cr.values = struct();
    cr.permutation = struct();
    cr.separation = struct();
    cr.decoding = struct();
    cr.effect_size = struct();
end
