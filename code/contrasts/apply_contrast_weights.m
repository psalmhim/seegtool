function C = apply_contrast_weights(L1, contrast)
% APPLY_CONTRAST_WEIGHTS Apply contrast weight vector to first-level estimates.
%
%   C = apply_contrast_weights(L1, contrast)
%
%   Level 2 of the hierarchical analysis framework. Takes per-condition
%   parameter estimates (betas from L1) and applies a contrast vector
%   to produce contrast values across all domains.
%
%   This is analogous to c' * beta_hat in SPM:
%     contrast_value(t) = sum_i( w_i * beta_i(t) )
%
%   For a simple A > B pairwise contrast with weights [1, -1]:
%     contrast_erp = 1 * erp_A - 1 * erp_B = erp_A - erp_B
%
%   For a one-vs-rest contrast with weights [1, -0.5, -0.5]:
%     contrast_erp = 1 * erp_A - 0.5 * erp_B - 0.5 * erp_C
%
%   Inputs:
%       L1       - first-level estimates struct from compute_first_level_estimates
%       contrast - contrast struct from define_contrasts (with .weights, .groups)
%
%   Output:
%       C - struct containing contrast values for each domain:
%         .name          - contrast name
%         .erp           - [ch x time] weighted ERP difference
%         .erp_se        - [ch x time] standard error of contrast
%         .erp_t         - [ch x time] t-statistic for contrast
%         .tf            - [freq x time] weighted TF difference
%         .tf_se         - [freq x time] SE of TF contrast
%         .itpc_diff     - [freq x time] ITPC difference
%         .centroid_diff - [dims x time] centroid difference vector
%         .separation    - [1 x time] separation distance
%         .trial_data_A  - trial-level data for group A (for L2 permutation)
%         .trial_data_B  - trial-level data for group B
%         .n_A, .n_B     - trial counts per group

    C = struct();
    C.name = contrast.name;
    C.type = contrast.type;
    C.weights = contrast.weights;
    C.groups = contrast.groups;

    conditions = L1.conditions;
    n_conds = numel(conditions);
    cnames = cellfun(@matlab.lang.makeValidName, conditions, 'UniformOutput', false);

    % Build weight vector matching L1 condition order
    if numel(contrast.weights) == n_conds
        w = contrast.weights(:)';
    else
        % Reconstruct from groups
        w = zeros(1, n_conds);
        group_a = contrast.groups{1};
        group_b = contrast.groups{2};
        n_a = numel(group_a);
        n_b = numel(group_b);
        for i = 1:n_conds
            if ismember(conditions{i}, group_a)
                w(i) = 1 / n_a;
            elseif ismember(conditions{i}, group_b)
                w(i) = -1 / n_b;
            end
        end
    end

    C.weight_vector = w;

    %% ---- ERP domain: c' * beta ----
    if isfield(L1, 'erp')
        [n_ch, n_t] = size(L1.erp.(cnames{1}));

        % Contrast value = sum(w_i * erp_i)
        contrast_erp = zeros(n_ch, n_t);
        contrast_var = zeros(n_ch, n_t);

        for i = 1:n_conds
            contrast_erp = contrast_erp + w(i) * L1.erp.(cnames{i});
            if isfield(L1, 'variance')
                n_c = L1.n_per_cond(i);
                % Var(c'*beta) = sum(w_i^2 * var_i / n_i)
                contrast_var = contrast_var + w(i)^2 * L1.variance.(cnames{i}) / max(n_c, 1);
            end
        end

        C.erp = contrast_erp;
        C.erp_se = sqrt(contrast_var);
        C.erp_se(C.erp_se == 0) = eps;
        C.erp_t = contrast_erp ./ C.erp_se;
    end

    %% ---- TF domain: c' * beta_tf ----
    if isfield(L1, 'tf')
        tf_size = size(L1.tf.(cnames{1}));
        contrast_tf = zeros(tf_size);
        contrast_tf_var = zeros(tf_size);

        for i = 1:n_conds
            contrast_tf = contrast_tf + w(i) * L1.tf.(cnames{i});
            if isfield(L1, 'tf_sem')
                n_c = L1.n_per_cond(i);
                % SE -> Var: var = (sem * sqrt(n))^2 = sem^2 * n
                sem_i = L1.tf_sem.(cnames{i});
                contrast_tf_var = contrast_tf_var + w(i)^2 * sem_i.^2 * max(n_c, 1);
            end
        end

        C.tf = contrast_tf;
        C.tf_se = sqrt(contrast_tf_var / sum(L1.n_per_cond));
    end

    %% ---- ITPC domain ----
    if isfield(L1, 'itpc')
        itpc_size = size(L1.itpc.(cnames{1}));
        contrast_itpc = zeros(itpc_size);

        for i = 1:n_conds
            contrast_itpc = contrast_itpc + w(i) * L1.itpc.(cnames{i});
        end
        C.itpc_diff = contrast_itpc;
    end

    %% ---- Latent space domain: centroid contrast ----
    if isfield(L1, 'centroid')
        cent_size = size(L1.centroid.(cnames{1}));
        n_dims = cent_size(1);
        n_t_lat = cent_size(2);

        contrast_centroid = zeros(n_dims, n_t_lat);
        for i = 1:n_conds
            contrast_centroid = contrast_centroid + w(i) * L1.centroid.(cnames{i});
        end
        C.centroid_diff = contrast_centroid;

        % Separation = norm of centroid difference at each time point
        C.separation = zeros(1, n_t_lat);
        for t = 1:n_t_lat
            C.separation(t) = norm(contrast_centroid(:, t));
        end

        % Normalized separation (by pooled dispersion)
        if isfield(L1, 'dispersion')
            pooled_disp = zeros(1, n_t_lat);
            for i = 1:n_conds
                if abs(w(i)) > 0
                    pooled_disp = pooled_disp + L1.dispersion.(cnames{i});
                end
            end
            pooled_disp = pooled_disp / sum(abs(w) > 0);
            pooled_disp(pooled_disp == 0) = eps;
            C.separation_norm = C.separation ./ pooled_disp;
        end
    end

    %% ---- Partition trial-level data for L2 permutation testing ----
    group_a = contrast.groups{1};
    group_b = contrast.groups{2};

    idx_a = [];
    idx_b = [];
    for i = 1:n_conds
        if ismember(conditions{i}, group_a)
            idx_a = [idx_a, L1.cond_indices.(cnames{i})];
        elseif ismember(conditions{i}, group_b)
            idx_b = [idx_b, L1.cond_indices.(cnames{i})];
        end
    end

    C.idx_A = idx_a;
    C.idx_B = idx_b;
    C.n_A = numel(idx_a);
    C.n_B = numel(idx_b);

    if isfield(L1, 'trial_tensor_by_cond')
        all_a = [];
        all_b = [];
        for i = 1:n_conds
            if ismember(conditions{i}, group_a)
                all_a = cat(1, all_a, L1.trial_tensor_by_cond.(cnames{i}));
            elseif ismember(conditions{i}, group_b)
                all_b = cat(1, all_b, L1.trial_tensor_by_cond.(cnames{i}));
            end
        end
        C.trial_data_A = all_a;
        C.trial_data_B = all_b;
    end

    if isfield(L1, 'latent_by_cond')
        lat_a = [];
        lat_b = [];
        for i = 1:n_conds
            if ismember(conditions{i}, group_a)
                lat_a = cat(1, lat_a, L1.latent_by_cond.(cnames{i}));
            elseif ismember(conditions{i}, group_b)
                lat_b = cat(1, lat_b, L1.latent_by_cond.(cnames{i}));
            end
        end
        C.latent_data_A = lat_a;
        C.latent_data_B = lat_b;
    end

    fprintf('[L2] Contrast "%s": nA=%d, nB=%d\n', C.name, C.n_A, C.n_B);
end
