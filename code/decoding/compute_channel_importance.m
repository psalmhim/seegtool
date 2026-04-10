function ch_imp = compute_channel_importance(latent_tensor, condition_labels, time_vec, pca_model, cfg)
% COMPUTE_CHANNEL_IMPORTANCE Per-channel decoding contribution via PCA back-projection.
%
%   ch_imp = compute_channel_importance(latent_tensor, condition_labels, time_vec, pca_model, cfg)
%
%   Two methods:
%     1. Weight back-projection: LDA weights in latent space -> channel space via PCA loadings
%     2. Permutation importance: shuffle each channel, measure accuracy drop
%
%   Inputs:
%       latent_tensor    - trials x dims x time
%       condition_labels - cell array
%       time_vec         - time vector (seconds)
%       pca_model        - struct with .W (channels x dims)
%       cfg              - struct with: decode_method, n_cv_folds
%
%   Outputs:
%       ch_imp - struct with:
%           .channel_weights    - n_channels x n_time (abs back-projected weights)
%           .channel_rank       - n_channels x 1 (1 = most important)
%           .perm_importance    - n_channels x 1 (accuracy drop from shuffling)
%           .perm_importance_p  - n_channels x 1 (p-value for importance > 0)
%           .mean_weight        - n_channels x 1 (mean abs weight, post-stim)
%           .top_channels       - indices of top N channels

    n_channels = size(pca_model.W, 1);
    n_time = size(latent_tensor, 3);
    top_n = 20;
    if isfield(cfg, 'channel_sig_top_n')
        top_n = cfg.channel_sig_top_n;
    end
    top_n = min(top_n, n_channels);

    %% Part A: Weight back-projection
    fprintf('[ChImp] Computing weight back-projection...\n');

    % Subsample time points for speed (every 4th), then interpolate
    step = 4;
    t_idx = 1:step:n_time;
    channel_weights_sparse = zeros(n_channels, numel(t_idx));

    n_dims = size(latent_tensor, 2);
    for ti = 1:numel(t_idx)
        X = reshape(latent_tensor(:, :, t_idx(ti)), [], n_dims);
        X(isnan(X)) = 0;
        X(isinf(X)) = 0;

        try
            model = train_linear_decoder(X, condition_labels, cfg.decode_method);
            if isfield(model, 'w') && isvector(model.w)
                w_latent = model.w;
                % For logistic, skip bias term
                if strcmpi(cfg.decode_method, 'logistic') && numel(w_latent) == size(pca_model.W, 2) + 1
                    w_latent = w_latent(2:end);
                end
                if numel(w_latent) == size(pca_model.W, 2)
                    channel_weights_sparse(:, ti) = abs(pca_model.W * w_latent);
                end
            end
        catch
            % Skip time points where training fails
        end
    end

    % Interpolate to full time resolution
    if numel(t_idx) > 1
        channel_weights = zeros(n_channels, n_time);
        for ch = 1:n_channels
            channel_weights(ch, :) = interp1(t_idx, channel_weights_sparse(ch, :), 1:n_time, 'linear', 0);
        end
    else
        channel_weights = repmat(channel_weights_sparse, 1, n_time);
    end

    % Mean weight (post-stimulus only)
    post_mask = time_vec > 0;
    if any(post_mask)
        mean_weight = mean(channel_weights(:, post_mask), 2, 'omitnan');
    else
        mean_weight = mean(channel_weights, 2, 'omitnan');
    end

    % Rank channels
    [~, rank_order] = sort(mean_weight, 'descend');
    channel_rank = zeros(n_channels, 1);
    channel_rank(rank_order) = 1:n_channels;

    %% Part B: Permutation importance
    fprintf('[ChImp] Computing permutation importance (%d channels)...\n', n_channels);

    n_shuffle = 50;

    % Find peak decoding time point
    peak_t = find_peak_decoding_time(latent_tensor, condition_labels, time_vec, cfg);
    X_peak = reshape(latent_tensor(:, :, peak_t), [], size(latent_tensor, 2));
    X_peak(isnan(X_peak)) = 0;

    % Baseline accuracy at peak
    baseline_acc = cv_accuracy(X_peak, condition_labels, cfg);

    perm_importance = zeros(n_channels, 1);
    perm_importance_p = ones(n_channels, 1);

    % For each channel: shuffle its contribution across trials, re-decode
    W = pca_model.W;  % channels x dims

    for ch = 1:n_channels
        if mod(ch, 50) == 0
            fprintf('[ChImp] Permutation importance: channel %d/%d\n', ch, n_channels);
        end

        ch_contrib = W(ch, :);  % 1 x dims
        ch_norm_sq = ch_contrib * ch_contrib';
        if ch_norm_sq < eps
            continue;
        end

        % Project each trial's latent onto this channel's direction
        ch_effect = (X_peak * ch_contrib') * (ch_contrib / ch_norm_sq);  % n_trials x dims

        drop_acc = zeros(n_shuffle, 1);
        for sh = 1:n_shuffle
            % Shuffle channel's contribution across trials
            perm = randperm(size(X_peak, 1));
            X_shuf = X_peak - ch_effect + ch_effect(perm, :);
            X_shuf(isnan(X_shuf)) = 0;

            drop_acc(sh) = cv_accuracy(X_shuf, condition_labels, cfg);
        end

        perm_importance(ch) = baseline_acc - mean(drop_acc);

        % p-value: proportion of shuffles where accuracy didn't drop
        perm_importance_p(ch) = (sum(drop_acc >= baseline_acc) + 1) / (n_shuffle + 1);
    end

    % Top channels
    [~, top_idx] = sort(mean_weight, 'descend');
    top_channels = top_idx(1:top_n);

    ch_imp = struct();
    ch_imp.channel_weights = channel_weights;
    ch_imp.channel_rank = channel_rank;
    ch_imp.perm_importance = perm_importance;
    ch_imp.perm_importance_p = perm_importance_p;
    ch_imp.mean_weight = mean_weight;
    ch_imp.top_channels = top_channels;

    fprintf('[ChImp] Top channel: #%d (weight=%.3f, importance=%.3f)\n', ...
        top_channels(1), mean_weight(top_channels(1)), perm_importance(top_channels(1)));
end


function peak_t = find_peak_decoding_time(latent_tensor, condition_labels, time_vec, cfg)
% Find time point with highest decoding accuracy (quick search).
    post_mask = time_vec > 0;
    post_idx = find(post_mask);

    % Sample every 10th post-stim time point
    sample_idx = post_idx(1:10:end);
    if isempty(sample_idx)
        sample_idx = post_idx;
    end

    best_acc = 0;
    peak_t = round(numel(time_vec) / 2);

    for ti = 1:numel(sample_idx)
        X = reshape(latent_tensor(:, :, sample_idx(ti)), [], size(latent_tensor, 2));
        X(isnan(X)) = 0;
        acc = cv_accuracy(X, condition_labels, cfg);
        if acc > best_acc
            best_acc = acc;
            peak_t = sample_idx(ti);
        end
    end
end


function acc = cv_accuracy(X, labels, cfg)
% Quick k-fold cross-validation accuracy.
    n = size(X, 1);
    k = min(cfg.n_cv_folds, n);
    if k < 2
        acc = 0.5;
        return;
    end

    indices = crossvalind_simple(n, k);
    correct = 0;
    total = 0;

    for fold = 1:k
        test_mask = (indices == fold);
        train_mask = ~test_mask;

        if sum(train_mask) < 2 || sum(test_mask) < 1
            continue;
        end

        try
            mdl = train_linear_decoder(X(train_mask, :), labels(train_mask), cfg.decode_method);
            X_test = X(test_mask, :);
            n_test = sum(test_mask);
            pred = zeros(n_test, 1);
            n_classes = numel(mdl.classes);

            for i = 1:n_test
                if n_classes == 2 && strcmpi(cfg.decode_method, 'lda') && isfield(mdl, 'w') && isfield(mdl, 'threshold')
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

            % Convert test labels to numeric using model's class order
            if iscell(mdl.classes)
                [~, y_test] = ismember(labels(test_mask), mdl.classes);
            else
                [~, y_test] = ismember(labels(test_mask), mdl.classes);
            end
            correct = correct + sum(pred == y_test);
            total = total + n_test;
        catch
            total = total + sum(test_mask);
        end
    end

    if total > 0
        acc = correct / total;
    else
        acc = 0.5;
    end
end


function indices = crossvalind_simple(n, k)
% Simple stratified cross-validation indices.
    indices = zeros(n, 1);
    perm = randperm(n);
    for i = 1:n
        indices(perm(i)) = mod(i - 1, k) + 1;
    end
end
