function L1 = compute_first_level_estimates(trial_tensor, condition_labels, time_vec, cfg, varargin)
% COMPUTE_FIRST_LEVEL_ESTIMATES Per-condition estimates across all domains.
%
%   L1 = compute_first_level_estimates(trial_tensor, condition_labels, time_vec, cfg)
%   L1 = compute_first_level_estimates(..., 'tf_power', tf, 'latent_tensor', lat, ...)
%
%   Level 1 of the hierarchical analysis framework. Computes condition-level
%   parameter estimates (betas) that contrast weights are later applied to.
%
%   This is analogous to the first-level GLM in SPM/FSL:
%     - Each condition → one parameter estimate (beta)
%     - Trial-level data → averaged per condition → beta_hat
%
%   Inputs:
%       trial_tensor     - trials x channels x time
%       condition_labels - cell array of condition strings per trial
%       time_vec         - time vector in seconds
%       cfg              - pipeline config struct
%
%   Name-Value:
%       'tf_power'       - trials x channels x freqs x time (TF power)
%       'freqs'          - frequency vector
%       'latent_tensor'  - trials x dims x time (latent space)
%       'tf_phase'       - trials x channels x freqs x time (phase)
%       'trial_weights'  - trials x 1 quality weights
%       'domains'        - cell of domains to compute (default: all)
%                          {'erp','tf','phase','latent','geometry'}
%
%   Output:
%       L1 - struct containing:
%         .conditions  - cell array of unique condition names
%         .n_per_cond  - trials per condition
%         .erp         - struct: .condA = [ch x time], .condB = ...
%         .erp_sem     - struct: .condA = [ch x time], .condB = ...
%         .tf          - struct: .condA = [freq x time], .condB = ...
%         .tf_sem      - struct: .condA = [freq x time], .condB = ...
%         .itpc        - struct: .condA = [freq x time], .condB = ...
%         .centroid    - struct: .condA = [dims x time], .condB = ...
%         .dispersion  - struct: .condA = [1 x time], .condB = ...
%         .variance    - struct: .condA = [ch x time], .condB = ...
%         .trial_tensor_by_cond - struct: .condA = [n_A x ch x time]

    p = inputParser;
    addParameter(p, 'tf_power', []);
    addParameter(p, 'freqs', []);
    addParameter(p, 'latent_tensor', []);
    addParameter(p, 'tf_phase', []);
    addParameter(p, 'trial_weights', ones(size(trial_tensor, 1), 1));
    addParameter(p, 'domains', {'erp', 'tf', 'phase', 'latent', 'geometry'});
    parse(p, varargin{:});

    domains = p.Results.domains;
    weights = p.Results.trial_weights;

    conditions = unique(condition_labels, 'stable');
    n_conds = numel(conditions);
    n_trials = size(trial_tensor, 1);
    n_ch = size(trial_tensor, 2);
    n_t = size(trial_tensor, 3);

    fprintf('[L1] Computing first-level estimates for %d conditions...\n', n_conds);

    L1 = struct();
    L1.conditions = conditions;
    L1.n_per_cond = zeros(1, n_conds);
    L1.cond_indices = struct();

    % Build condition masks
    for c = 1:n_conds
        cname = matlab.lang.makeValidName(conditions{c});
        mask = strcmp(condition_labels, conditions{c});
        L1.cond_indices.(cname) = find(mask)';
        L1.n_per_cond(c) = sum(mask);
    end

    %% ---- ERP domain ----
    if ismember('erp', domains)
        L1.erp = struct();
        L1.erp_sem = struct();
        L1.variance = struct();

        for c = 1:n_conds
            cname = matlab.lang.makeValidName(conditions{c});
            idx = L1.cond_indices.(cname);
            n_c = numel(idx);
            w_c = weights(idx);
            w_c = w_c / sum(w_c);

            % Weighted mean ERP per condition
            cond_data = trial_tensor(idx, :, :);  % n_c x ch x time
            erp_c = zeros(n_ch, n_t);
            for i = 1:n_c
                erp_c = erp_c + w_c(i) * squeeze(cond_data(i, :, :));
            end
            L1.erp.(cname) = erp_c;

            % SEM
            if n_c > 1
                erp_mean = squeeze(mean(cond_data, 1));
                erp_var = squeeze(var(cond_data, 0, 1));
                L1.erp_sem.(cname) = sqrt(erp_var / n_c);
                L1.variance.(cname) = erp_var;
            else
                L1.erp_sem.(cname) = zeros(n_ch, n_t);
                L1.variance.(cname) = zeros(n_ch, n_t);
            end
        end
        fprintf('[L1] ERP: %d conditions x %d channels x %d time\n', n_conds, n_ch, n_t);
    end

    %% ---- Time-frequency domain ----
    if ismember('tf', domains) && ~isempty(p.Results.tf_power)
        tf = p.Results.tf_power;
        n_freq = size(tf, 3);
        L1.tf = struct();
        L1.tf_sem = struct();

        for c = 1:n_conds
            cname = matlab.lang.makeValidName(conditions{c});
            idx = L1.cond_indices.(cname);
            n_c = numel(idx);

            % Average TF across trials and channels for this condition
            cond_tf = tf(idx, :, :, :);  % n_c x ch x freq x time
            % Collapse channels → freq x time
            tf_avg = squeeze(mean(mean(cond_tf, 1), 2));
            L1.tf.(cname) = tf_avg;

            if n_c > 1
                tf_var = squeeze(var(mean(cond_tf, 2), 0, 1));
                L1.tf_sem.(cname) = sqrt(tf_var / n_c);
            else
                L1.tf_sem.(cname) = zeros(size(tf_avg));
            end
        end
        fprintf('[L1] TF: %d conditions x %d freq x %d time\n', n_conds, n_freq, n_t);
    end

    %% ---- Phase domain (ITPC) ----
    if ismember('phase', domains) && ~isempty(p.Results.tf_phase)
        phase = p.Results.tf_phase;
        L1.itpc = struct();

        for c = 1:n_conds
            cname = matlab.lang.makeValidName(conditions{c});
            idx = L1.cond_indices.(cname);

            cond_phase = phase(idx, :, :, :);  % n_c x ch x freq x time
            % ITPC = |mean(exp(j*phase))|, average across channels
            itpc_c = abs(mean(exp(1i * cond_phase), 1));
            L1.itpc.(cname) = squeeze(mean(itpc_c, 2));  % freq x time
        end
        fprintf('[L1] ITPC: %d conditions\n', n_conds);
    end

    %% ---- Latent space domain ----
    if ismember('latent', domains) && ~isempty(p.Results.latent_tensor)
        lat = p.Results.latent_tensor;
        n_dims = size(lat, 2);
        L1.centroid = struct();
        L1.dispersion = struct();
        L1.latent_cov = struct();

        for c = 1:n_conds
            cname = matlab.lang.makeValidName(conditions{c});
            idx = L1.cond_indices.(cname);
            n_c = numel(idx);

            cond_lat = lat(idx, :, :);  % n_c x dims x time

            % Centroid (mean trajectory)
            L1.centroid.(cname) = squeeze(mean(cond_lat, 1));  % dims x time

            % Dispersion (mean distance to centroid)
            disp_t = zeros(1, n_t);
            for t = 1:n_t
                points = squeeze(cond_lat(:, :, t));  % n_c x dims
                center = mean(points, 1);
                dists = sqrt(sum((points - center).^2, 2));
                disp_t(t) = mean(dists);
            end
            L1.dispersion.(cname) = disp_t;

            % Covariance at each time point (for Mahalanobis)
            if n_c > n_dims
                cov_t = zeros(n_dims, n_dims, n_t);
                for t = 1:n_t
                    points = squeeze(cond_lat(:, :, t));
                    cov_t(:, :, t) = cov(points);
                end
                L1.latent_cov.(cname) = cov_t;
            end
        end
        fprintf('[L1] Latent: %d conditions x %d dims x %d time\n', n_conds, n_dims, n_t);
    end

    %% ---- Store trial-level data partitioned by condition (for L2 permutation) ----
    L1.trial_tensor_by_cond = struct();
    for c = 1:n_conds
        cname = matlab.lang.makeValidName(conditions{c});
        idx = L1.cond_indices.(cname);
        L1.trial_tensor_by_cond.(cname) = trial_tensor(idx, :, :);
    end

    if ~isempty(p.Results.latent_tensor)
        L1.latent_by_cond = struct();
        lat = p.Results.latent_tensor;
        for c = 1:n_conds
            cname = matlab.lang.makeValidName(conditions{c});
            idx = L1.cond_indices.(cname);
            L1.latent_by_cond.(cname) = lat(idx, :, :);
        end
    end

    fprintf('[L1] First-level estimation complete.\n');
end
