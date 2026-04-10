function model = train_linear_decoder(X_train, y_train, method)
% TRAIN_LINEAR_DECODER Train LDA or logistic decoder.
    if nargin < 3, method = 'lda'; end

    % Handle NaN/Inf in features
    X_train(isnan(X_train)) = 0;
    X_train(isinf(X_train)) = 0;

    classes = unique(y_train);
    if ~iscell(classes), classes = classes(:)'; end

    model.classes = classes;
    model.method = method;
    n_classes = numel(classes);
    n_features = size(X_train, 2);

    switch lower(method)
        case 'lda'
            class_means = zeros(n_classes, n_features);
            S_w = zeros(n_features);
            class_counts = zeros(n_classes, 1);
            for c = 1:n_classes
                if iscell(classes)
                    idx = strcmp(y_train, classes{c});
                else
                    idx = y_train == classes(c);
                end
                class_counts(c) = sum(idx);
                class_means(c, :) = mean(X_train(idx, :), 1, 'omitnan');
                centered = X_train(idx, :) - class_means(c, :);
                % Weight each class equally regardless of sample count
                S_w = S_w + (centered' * centered) / max(class_counts(c), 1);
            end
            S_w = S_w / n_classes;
            % Stronger regularization to prevent singular matrix
            S_w = S_w + 1e-3 * eye(n_features);
            model.class_means = class_means;
            model.S_w_inv = S_w \ eye(n_features);  % more stable than inv()
            if n_classes == 2
                model.w = model.S_w_inv * (class_means(1, :) - class_means(2, :))';
                model.threshold = 0.5 * model.w' * (class_means(1, :) + class_means(2, :))';
            end

        case 'logistic'
            n_samples = size(X_train, 1);
            if iscell(classes)
                y_binary = double(strcmp(y_train, classes{1}));
            else
                y_binary = double(y_train == classes(1));
            end
            w = zeros(n_features + 1, 1);
            X_aug = [ones(n_samples, 1), X_train];
            lr = 0.01; max_iter = 200;
            for iter = 1:max_iter
                z = X_aug * w;
                z = max(min(z, 500), -500);  % prevent overflow
                p = 1 ./ (1 + exp(-z));
                grad = X_aug' * (p - y_binary) / n_samples + 1e-4 * w;  % L2 reg
                w = w - lr * grad;
            end
            model.w = w;
    end
end
