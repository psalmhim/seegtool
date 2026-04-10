classdef test_bootstrap < matlab.unittest.TestCase
    % TEST_BOOTSTRAP Unit tests for bootstrap and uncertainty quantification.
    %
    % Tests cover: bootstrap sample count, confidence interval coverage,
    % confidence tube dimensions, and reproducibility with fixed seed.

    properties
        Tol
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.Tol = 1e-10;
        end
    end

    % ------------------------------------------------------------------
    methods (Test)

        function test_bootstrap_sample_size(testCase)
            % Verify that the bootstrap procedure generates the correct
            % number of resampled statistics.
            rng(1);
            nTrials = 50;
            nTime   = 100;
            k       = 3;
            nBoot   = 500;

            % trajectories: [nTrials x nTime x k]
            Z = randn(nTrials, nTime, k);

            boot_stats = bootstrap_condition_trajectories(Z, nBoot);

            % boot_stats should have nBoot entries along the bootstrap
            % dimension: [nBoot x nTime x k]
            testCase.verifySize(boot_stats, [nBoot, nTime, k], ...
                'Bootstrap output does not have the expected number of samples.');
        end

        function test_confidence_interval_coverage(testCase)
            % For a known Gaussian distribution, the 95% bootstrap CI
            % should contain the true mean in roughly 95% of experiments.
            % We run a simplified version: generate data from N(5, 1) and
            % verify the 95% CI of the mean covers the true value.
            rng(42);
            true_mean = 5.0;
            nSamples  = 200;
            nBoot     = 1000;
            alpha     = 0.05;

            data = true_mean + randn(nSamples, 1);

            boot_means = zeros(nBoot, 1);
            for b = 1:nBoot
                idx = randi(nSamples, nSamples, 1);
                boot_means(b) = mean(data(idx));
            end

            ci_lo = quantile(boot_means, alpha/2);
            ci_hi = quantile(boot_means, 1 - alpha/2);

            testCase.verifyGreaterThanOrEqual(true_mean, ci_lo, ...
                'True mean is below the lower CI bound.');
            testCase.verifyLessThanOrEqual(true_mean, ci_hi, ...
                'True mean is above the upper CI bound.');
        end

        function test_confidence_tubes_shape(testCase)
            % Confidence tubes output should have the correct dimensions:
            % [2 x nTime x k] for lower and upper bounds.
            rng(2);
            nTrials = 40;
            nTime   = 80;
            k       = 3;
            nBoot   = 200;
            alpha   = 0.05;

            Z = randn(nTrials, nTime, k);

            tubes = compute_confidence_tubes(Z, nBoot, alpha);

            % Expected: [2 x nTime x k] where dim1 = [lower; upper]
            testCase.verifySize(tubes, [2, nTime, k], ...
                'Confidence tubes have unexpected dimensions.');

            % Lower bound should be less than or equal to upper bound
            lower = squeeze(tubes(1, :, :));
            upper = squeeze(tubes(2, :, :));
            testCase.verifyTrue(all(lower(:) <= upper(:)), ...
                'Lower CI bound exceeds upper CI bound.');
        end

        function test_bootstrap_reproducibility(testCase)
            % Using the same random seed should produce identical results.
            nTrials = 30;
            nTime   = 50;
            k       = 3;
            nBoot   = 100;
            seed    = 999;

            Z = randn(nTrials, nTime, k);

            rng(seed);
            result1 = bootstrap_condition_trajectories(Z, nBoot);

            rng(seed);
            result2 = bootstrap_condition_trajectories(Z, nBoot);

            testCase.verifyEqual(result1, result2, 'AbsTol', testCase.Tol, ...
                'Bootstrap results differ despite identical random seed.');
        end

    end
end
