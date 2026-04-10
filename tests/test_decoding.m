classdef test_decoding < matlab.unittest.TestCase
    % TEST_DECODING Unit tests for neural decoding functions.
    %
    % Tests cover: perfectly separable data, chance-level performance,
    % cross-validation fold counts, time-resolved decoding output shape,
    % and permutation null distribution.

    properties
        Tol
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.Tol = 1e-6;
        end
    end

    % ------------------------------------------------------------------
    methods (Test)

        function test_perfect_separation(testCase)
            % Perfectly separable data should yield 100% decoding accuracy.
            rng(1);
            nSamples = 100;
            nFeatures = 5;

            X = [randn(nSamples/2, nFeatures) + 10;
                 randn(nSamples/2, nFeatures) - 10];
            y = [ones(nSamples/2, 1); 2*ones(nSamples/2, 1)];

            nFolds = 5;
            acc = run_cross_validation(X, y, nFolds);

            testCase.verifyEqual(acc, 1.0, 'AbsTol', 0.01, ...
                'Perfectly separable data should yield 100% accuracy.');
        end

        function test_chance_performance(testCase)
            % Random labels should produce accuracy near chance (50% for
            % two classes).
            rng(2);
            nSamples  = 200;
            nFeatures = 10;

            X = randn(nSamples, nFeatures);
            y = randi(2, nSamples, 1);

            nFolds = 5;
            acc = run_cross_validation(X, y, nFolds);

            % Should be near 0.5 for binary classification with random labels
            testCase.verifyEqual(acc, 0.5, 'AbsTol', 0.15, ...
                'Random labels should produce near-chance accuracy.');
        end

        function test_cross_validation_folds(testCase)
            % Verify that the cross-validation procedure produces the
            % correct number of folds and that every sample gets a prediction.
            rng(3);
            nSamples  = 100;
            nFeatures = 5;
            nFolds    = 10;

            X = randn(nSamples, nFeatures);
            y = randi(2, nSamples, 1);

            [acc, predictions, fold_acc] = run_cross_validation(X, y, nFolds);

            testCase.verifyLength(fold_acc, nFolds, ...
                'Number of fold accuracies does not match nFolds.');

            % Every sample should have a non-zero prediction
            testCase.verifyEqual(numel(predictions), nSamples, ...
                'Predictions vector length should match nSamples.');
            testCase.verifyTrue(all(predictions > 0), ...
                'All samples should have a non-zero prediction.');
        end

        function test_cross_validation_fixed_folds(testCase)
            % Verify that providing a fixed fold_idx produces consistent results.
            rng(6);
            nSamples  = 100;
            nFeatures = 5;
            nFolds    = 5;

            X = randn(nSamples, nFeatures);
            y = [ones(nSamples/2, 1); 2*ones(nSamples/2, 1)];

            % Create fixed folds
            fold_idx = zeros(nSamples, 1);
            for i = 1:nSamples
                fold_idx(i) = mod(i - 1, nFolds) + 1;
            end

            [acc1, ~, ~] = run_cross_validation(X, y, nFolds, 'lda', fold_idx);
            [acc2, ~, ~] = run_cross_validation(X, y, nFolds, 'lda', fold_idx);

            testCase.verifyEqual(acc1, acc2, ...
                'Fixed fold_idx should produce identical accuracy.');
        end

        function test_time_resolved_shape(testCase)
            % Time-resolved decoding output should have one accuracy value
            % per time point, with consistent fold structure.
            rng(4);
            nTrials   = 80;
            nTime     = 50;
            nFeatures = 10;
            nFolds    = 5;

            X = randn(nTrials, nFeatures, nTime);
            y = randi(2, nTrials, 1);

            acc_time = run_time_resolved_decoding(X, y, nFolds);

            testCase.verifySize(acc_time, [1, nTime], ...
                'Time-resolved decoding output shape is incorrect.');
        end

        function test_permutation_null(testCase)
            % The permutation null distribution should be centered near
            % chance level (0.5 for binary).
            rng(5);
            nTrials   = 100;
            nFeatures = 5;
            nTime     = 10;
            nPerms    = 50;
            nFolds    = 5;

            % permutation_test_decoding expects a 3D tensor
            X = randn(nTrials, nFeatures, nTime);
            y = randi(2, nTrials, 1);

            observed_acc = run_time_resolved_decoding(X, y, nFolds);
            [p_values, null_dist] = permutation_test_decoding(X, y, observed_acc, nPerms, nFolds);

            testCase.verifySize(null_dist, [nPerms, nTime], ...
                'Null distribution shape should be [nPerms, nTime].');
            testCase.verifySize(p_values, [1, nTime], ...
                'P-values shape should be [1, nTime].');
            testCase.verifyEqual(mean(null_dist(:)), 0.5, 'AbsTol', 0.1, ...
                'Null distribution should be centered near chance.');
        end

        function test_onset_post_stimulus_only(testCase)
            % Onset detection should only find post-stimulus timepoints.
            rng(7);
            time_vec = linspace(-0.5, 2.0, 100);
            accuracy = 0.5 * ones(1, 100);
            p_values = ones(1, 100);

            % Make pre-stimulus significant (should be ignored)
            p_values(1:10) = 0.001;
            % Make post-stimulus significant
            post_idx = find(time_vec >= 0.5, 5, 'first');
            p_values(post_idx) = 0.001;

            [onset_time, ~] = estimate_decoding_onset(accuracy, p_values, time_vec);

            testCase.verifyGreaterThanOrEqual(onset_time, 0, ...
                'Decoding onset should be post-stimulus (>= 0).');
        end

    end
end
