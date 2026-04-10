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
            % correct number of folds and that every sample appears in
            % exactly one test fold.
            rng(3);
            nSamples  = 100;
            nFeatures = 5;
            nFolds    = 10;

            X = randn(nSamples, nFeatures);
            y = randi(2, nSamples, 1);

            [acc, fold_results] = run_cross_validation(X, y, nFolds);

            testCase.verifyLength(fold_results, nFolds, ...
                'Number of fold results does not match nFolds.');

            % Collect all test indices and verify full coverage
            all_test_idx = [];
            for f = 1:nFolds
                all_test_idx = [all_test_idx; fold_results(f).test_idx(:)]; %#ok<AGROW>
            end
            testCase.verifyEqual(sort(all_test_idx), (1:nSamples)', ...
                'Not all samples were used in exactly one test fold.');
        end

        function test_time_resolved_shape(testCase)
            % Time-resolved decoding output should have one accuracy value
            % per time point.
            rng(4);
            nTrials   = 80;
            nTime     = 50;
            nFeatures = 10;
            nFolds    = 5;

            % X: [nTrials x nFeatures x nTime]
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
            nSamples  = 100;
            nFeatures = 5;
            nPerms    = 200;
            nFolds    = 5;

            X = randn(nSamples, nFeatures);
            y = randi(2, nSamples, 1);

            null_dist = permutation_test_decoding(X, y, nFolds, nPerms);

            testCase.verifyLength(null_dist, nPerms, ...
                'Null distribution length should equal nPerms.');
            testCase.verifyEqual(mean(null_dist), 0.5, 'AbsTol', 0.1, ...
                'Null distribution should be centered near chance.');
        end

    end
end
