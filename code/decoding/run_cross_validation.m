function [accuracy, predictions, fold_acc] = run_cross_validation(X, y, n_folds, method, fold_idx)
% RUN_CROSS_VALIDATION K-fold stratified cross-validation.
%   Optional fold_idx argument allows reusing a fixed fold assignment
%   (e.g., to maintain consistent splits across timepoints).
    if nargin < 3, n_folds = 5; end
    if nargin < 4, method = 'lda'; end

    n_samples = size(X, 1);

    % Convert to numeric labels
    if iscell(y)
        [class_names, ~, y_numeric] = unique(y);
    else
        [class_names_num, ~, y_numeric] = unique(y);
        class_names = class_names_num;  % numeric class values
    end
    n_classes = max(y_numeric);

    % Handle NaN/Inf in features
    nan_cols = all(isnan(X) | isinf(X), 1);
    X(:, nan_cols) = 0;
    X(isnan(X)) = 0;
    X(isinf(X)) = 0;

    % Use provided fold assignment or create new one
    if nargin < 5 || isempty(fold_idx)
        fold_idx = zeros(n_samples, 1);
        for c = 1:n_classes
            c_idx = find(y_numeric == c);
            c_idx = c_idx(randperm(numel(c_idx)));
            for i = 1:numel(c_idx)
                fold_idx(c_idx(i)) = mod(i - 1, n_folds) + 1;
            end
        end
    end

    predictions = zeros(n_samples, 1);
    fold_acc = zeros(n_folds, 1);

    for f = 1:n_folds
        test_mask = fold_idx == f;
        train_mask = ~test_mask;

        mdl = train_linear_decoder(X(train_mask, :), y_numeric(train_mask), method);

        X_test = X(test_mask, :);
        n_test = sum(test_mask);
        pred = zeros(n_test, 1);

        for i = 1:n_test
            if n_classes == 2 && strcmp(method, 'lda') && isfield(mdl, 'w') && isfield(mdl, 'threshold')
                score = mdl.w' * X_test(i, :)';
                if score > mdl.threshold
                    pred(i) = 1;
                else
                    pred(i) = 2;
                end
            else
                % Nearest centroid fallback
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

        predictions(test_mask) = pred;
        fold_acc(f) = mean(pred == y_numeric(test_mask));
    end

    accuracy = mean(predictions == y_numeric);
end
