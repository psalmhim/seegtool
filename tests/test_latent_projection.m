classdef test_latent_projection < matlab.unittest.TestCase
    % TEST_LATENT_PROJECTION Unit tests for latent space / dimensionality
    % reduction functions.
    %
    % Tests cover: PCA reconstruction error, variance explained,
    % orthogonality, projection output shape, condition averaging,
    % and trajectory smoothing.

    properties
        Tol
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.Tol = 1e-8;
        end
    end

    % ------------------------------------------------------------------
    methods (Test)

        function test_pca_reconstruction(testCase)
            % Project high-dimensional data to k PCs and reconstruct.
            % With k = full rank the reconstruction error should be tiny.
            rng(1);
            N = 200;  % observations
            D = 10;   % dimensions
            X = randn(N, D);
            k = D;    % keep all components

            model = fit_pca_model(X, k);
            Z     = project_to_latent_space(X, model);
            X_rec = Z * model.components' + model.mean_vec;

            err = max(abs(X - X_rec), [], 'all');
            testCase.verifyLessThan(err, 1e-6, ...
                'Full-rank PCA reconstruction error is too large.');
        end

        function test_pca_variance_explained(testCase)
            % The sum of all eigenvalues should equal the total variance
            % of the data (trace of covariance matrix).
            rng(2);
            N = 300;
            D = 8;
            X = randn(N, D) * diag(1:D);  % varying variances

            model = fit_pca_model(X, D);

            total_var_data  = sum(var(X, 0, 1));  % unbiased variance per column
            total_var_eigen = sum(model.eigenvalues);

            testCase.verifyEqual(total_var_eigen, total_var_data, ...
                'RelTol', 1e-6, ...
                'Eigenvalue sum does not equal total data variance.');
        end

        function test_pca_orthogonality(testCase)
            % Principal components should be mutually orthogonal.
            rng(3);
            N = 200;
            D = 6;
            k = 4;
            X = randn(N, D);

            model = fit_pca_model(X, k);

            % model.components: [D x k] each column is a PC loading
            G = model.components' * model.components;  % should be identity
            I_k = eye(k);

            testCase.verifyEqual(G, I_k, 'AbsTol', 1e-10, ...
                'PCA components are not orthogonal.');
        end

        function test_latent_projection_shape(testCase)
            % Verify the output dimensions after projection.
            rng(4);
            N = 150;
            D = 20;
            k = 3;
            X = randn(N, D);

            model = fit_pca_model(X, k);
            Z     = project_to_latent_space(X, model);

            testCase.verifySize(Z, [N, k], ...
                'Latent projection output has unexpected shape.');
        end

        function test_condition_averaging(testCase)
            % Verify that condition-averaged trajectories match manual
            % computation of the mean per condition per time point.
            rng(5);
            nTrials = 60;
            nTime   = 100;
            k       = 3;

            % latent trajectories: [nTrials x nTime x k]
            Z = randn(nTrials, nTime, k);
            labels = repmat([1; 2; 3], [nTrials/3, 1]);

            avg = compute_condition_averaged_trajectories(Z, labels);

            % Manual average for condition 1
            idx1         = labels == 1;
            expected_c1  = squeeze(mean(Z(idx1, :, :), 1));

            testCase.verifyEqual(squeeze(avg(1, :, :)), expected_c1, ...
                'AbsTol', testCase.Tol, ...
                'Condition average does not match manual mean.');
        end

        function test_trajectory_smoothing(testCase)
            % Smoothing should reduce the noise level (measured as the
            % mean absolute second derivative) compared to the raw signal.
            rng(6);
            nTime = 200;
            k     = 3;
            % Noisy trajectory
            Z_noisy = cumsum(randn(nTime, k), 1) + 2*randn(nTime, k);

            Z_smooth = smooth_latent_trajectories(Z_noisy);

            % Measure roughness via second derivative
            rough_raw    = mean(abs(diff(Z_noisy, 2, 1)), 'all');
            rough_smooth = mean(abs(diff(Z_smooth, 2, 1)), 'all');

            testCase.verifyLessThan(rough_smooth, rough_raw, ...
                'Smoothing did not reduce trajectory roughness.');
        end

    end
end
