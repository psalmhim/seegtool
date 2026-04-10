function decode_results = run_neural_decoding(latent_tensor, condition_labels, time_vec, cfg, pca_model, source_tensor)
% RUN_NEURAL_DECODING Main neural decoding pipeline.
    if nargin < 5
        pca_model = [];
    end
    if nargin < 6
        source_tensor = [];
    end

    decode_results = struct();
    use_foldwise_projection = ~isempty(source_tensor) && ~isempty(pca_model) && ...
        isfield(pca_model, 'W') && isfield(cfg, 'n_latent_dims');

    fprintf('[Decoding] Running time-resolved decoding...\n');
    if use_foldwise_projection
        fprintf('[Decoding] Refitting latent projection inside CV folds.\n');
        [decode_results.accuracy_time, decode_results.predictions] = ...
            run_time_resolved_decoding_cv_projection(source_tensor, condition_labels, cfg);
    else
        [decode_results.accuracy_time, decode_results.predictions] = ...
            run_time_resolved_decoding(latent_tensor, condition_labels, cfg.n_cv_folds, cfg.decode_method);
    end

    fprintf('[Decoding] Running permutation test...\n');
    n_perm = min(cfg.n_permutations, 200);
    if use_foldwise_projection
        [decode_results.p_values, decode_results.null_dist] = ...
            permutation_test_decoding_cv_projection(source_tensor, condition_labels, ...
            decode_results.accuracy_time, n_perm, cfg);
    else
        [decode_results.p_values, decode_results.null_dist] = ...
            permutation_test_decoding(latent_tensor, condition_labels, ...
            decode_results.accuracy_time, n_perm, cfg.n_cv_folds, cfg.decode_method);
    end

    [decode_results.onset_time, decode_results.onset_idx] = ...
        estimate_decoding_onset(decode_results.accuracy_time, decode_results.p_values, ...
        time_vec, cfg.alpha_level);
    n_classes = numel(unique(condition_labels));
    decode_results.chance_level = 1 / n_classes;
    decode_results.time_vec = time_vec;
    fprintf('[Decoding] Onset at %.3f s, peak accuracy %.1f%%\n', ...
        decode_results.onset_time, max(decode_results.accuracy_time) * 100);

    if ~isempty(pca_model) && isfield(pca_model, 'W')
        fprintf('[Decoding] Computing channel importance...\n');
        ch_imp = compute_channel_importance( ...
            latent_tensor, condition_labels, time_vec, pca_model, cfg);
        decode_results.channel_importance = ch_imp.channel_weights;
        decode_results.channel_rank = ch_imp.channel_rank;
        decode_results.channel_perm_importance = ch_imp.perm_importance;
        decode_results.channel_mean_weight = ch_imp.mean_weight;
        decode_results.channel_top = ch_imp.top_channels;
    end
end


function [accuracy_time, predictions_time] = run_time_resolved_decoding_cv_projection(source_tensor, condition_labels, cfg)
% Decode with latent projection fit only on training folds.
    [n_trials, ~, n_time] = size(source_tensor);
    [fold_idx, y_numeric] = make_stratified_folds(condition_labels, cfg.n_cv_folds);
    n_dims = min(cfg.n_latent_dims, size(source_tensor, 2));

    predictions_time = zeros(n_trials, n_time);
    accuracy_time = zeros(1, n_time);

    for f = 1:max(fold_idx)
        test_mask = fold_idx == f;
        train_mask = ~test_mask;
        if ~any(test_mask) || sum(train_mask) < 2
            continue;
        end

        fold_cfg = cfg;
        fold_cfg.n_latent_dims = n_dims;
        fold_model = fit_latent_model(source_tensor(train_mask, :, :), fold_cfg);
        train_latent = project_to_latent_space(source_tensor(train_mask, :, :), fold_model);
        test_latent = project_to_latent_space(source_tensor(test_mask, :, :), fold_model);

        for t = 1:n_time
            X_train = squeeze(train_latent(:, :, t));
            X_test = squeeze(test_latent(:, :, t));
            mdl = train_linear_decoder(X_train, y_numeric(train_mask), cfg.decode_method);
            predictions_time(test_mask, t) = predict_linear_decoder(mdl, X_test, numel(unique(y_numeric)));
        end
    end

    for t = 1:n_time
        accuracy_time(t) = mean(predictions_time(:, t) == y_numeric);
    end
end


function [p_values, null_dist] = permutation_test_decoding_cv_projection(source_tensor, condition_labels, observed_accuracy, n_perms, cfg)
% Permutation test matching foldwise latent refit.
    n_time = size(source_tensor, 3);
    null_dist = zeros(n_perms, n_time);
    for p = 1:n_perms
        perm_labels = condition_labels(randperm(numel(condition_labels)));
        [null_dist(p, :), ~] = run_time_resolved_decoding_cv_projection(source_tensor, perm_labels, cfg);
    end
    p_values = zeros(1, n_time);
    for t = 1:n_time
        p_values(t) = (sum(null_dist(:, t) >= observed_accuracy(t)) + 1) / (n_perms + 1);
    end
end


function [fold_idx, y_numeric] = make_stratified_folds(labels, n_folds)
% Shared stratified fold assignment.
    n_samples = numel(labels);
    [~, ~, y_numeric] = unique(labels);
    n_classes = max(y_numeric);
    fold_idx = zeros(n_samples, 1);
    for c = 1:n_classes
        c_idx = find(y_numeric == c);
        c_idx = c_idx(randperm(numel(c_idx)));
        for i = 1:numel(c_idx)
            fold_idx(c_idx(i)) = mod(i - 1, n_folds) + 1;
        end
    end
end


function pred = predict_linear_decoder(mdl, X_test, n_classes)
% Predict helper shared by foldwise decoding.
    X_test(isnan(X_test)) = 0;
    X_test(isinf(X_test)) = 0;
    n_test = size(X_test, 1);
    pred = zeros(n_test, 1);

    for i = 1:n_test
        if n_classes == 2 && strcmpi(mdl.method, 'lda') && isfield(mdl, 'w') && isfield(mdl, 'threshold')
            score = mdl.w' * X_test(i, :)';
            if score > mdl.threshold
                pred(i) = 1;
            else
                pred(i) = 2;
            end
        else
            dists = zeros(n_classes, 1);
            for c = 1:n_classes
                if c <= size(mdl.class_means, 1)
                    dists(c) = norm(X_test(i, :) - mdl.class_means(c, :));
                else
                    dists(c) = Inf;
                end
            end
            [~, pred(i)] = min(dists);
        end
    end
end
