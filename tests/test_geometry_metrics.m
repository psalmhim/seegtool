classdef test_geometry_metrics < matlab.unittest.TestCase
    % TEST_GEOMETRY_METRICS Unit tests for trajectory geometry computations.
    %
    % Tests cover: velocity for constant-speed trajectories, curvature of
    % straight lines and circles, path length of straight lines, dispersion
    % for identical trials, and condition separation.

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

        function test_velocity_constant_speed(testCase)
            % A linear trajectory with constant step should yield constant
            % velocity at every time point.
            nTime = 200;
            dt    = 0.001;  % 1 ms
            speed = 5.0;    % units/s

            % Linear trajectory in 3D: constant velocity along [1,0,0]
            traj = zeros(nTime, 3);
            traj(:,1) = speed * dt * (0:nTime-1)';

            vel = compute_velocity(traj, dt);

            % vel should be approximately constant = speed
            % (first/last might differ due to finite differences)
            interior = vel(2:end-1);
            testCase.verifyEqual(interior, speed * ones(size(interior)), ...
                'AbsTol', 0.1, ...
                'Velocity is not constant for a linear trajectory.');
        end

        function test_curvature_straight_line(testCase)
            % A straight-line trajectory should have zero curvature.
            nTime = 200;
            dt    = 0.001;
            traj  = [(1:nTime)', 2*(1:nTime)', 3*(1:nTime)'] * dt;

            kappa = compute_curvature(traj, dt);

            interior = kappa(3:end-2);
            testCase.verifyLessThan(max(abs(interior)), 0.01, ...
                'Curvature of a straight line should be zero.');
        end

        function test_curvature_circle(testCase)
            % A circular trajectory of radius r should have constant
            % curvature equal to 1/r.
            r     = 5;
            nTime = 1000;
            theta = linspace(0, 2*pi, nTime)';
            dt    = 1 / nTime;

            traj = [r*cos(theta), r*sin(theta), zeros(nTime, 1)];

            kappa = compute_curvature(traj, dt);

            % Interior points (avoid boundary effects)
            interior = kappa(10:end-10);
            expected = 1 / r;

            testCase.verifyEqual(mean(interior), expected, ...
                'RelTol', 0.05, ...
                'Curvature of a circle does not match 1/r.');
        end

        function test_path_length_straight(testCase)
            % For a straight-line path the total path length should equal
            % the Euclidean distance between start and end points.
            start_pt = [0 0 0];
            end_pt   = [3 4 0];  % distance = 5
            nTime    = 100;

            traj = zeros(nTime, 3);
            for d = 1:3
                traj(:,d) = linspace(start_pt(d), end_pt(d), nTime);
            end

            plen = compute_path_length(traj);

            eucl = norm(end_pt - start_pt);
            testCase.verifyEqual(plen, eucl, 'RelTol', 0.01, ...
                'Path length of straight line should equal Euclidean distance.');
        end

        function test_dispersion_identical_trials(testCase)
            % When all trials follow the exact same trajectory, dispersion
            % should be zero.
            nTime   = 100;
            k       = 3;
            nTrials = 20;

            base_traj  = cumsum(randn(nTime, k), 1);
            all_trials = repmat(base_traj, [1, 1, nTrials]);
            % Reshape to [nTrials x nTime x k]
            trials = permute(all_trials, [3, 1, 2]);

            disp_vals = compute_dispersion(trials);

            % disp_vals: [nTime x 1] or [1 x nTime]
            testCase.verifyLessThan(max(abs(disp_vals)), testCase.Tol, ...
                'Dispersion should be zero for identical trials.');
        end

        function test_condition_separation(testCase)
            % Two well-separated clusters in latent space should produce
            % a large separation metric.
            rng(10);
            nTime = 50;
            k     = 3;
            nTrials_per = 30;

            % Condition 1: centered at [10, 0, 0]
            trials_c1 = randn(nTrials_per, nTime, k) + ...
                        reshape([10, 0, 0], [1, 1, k]);
            % Condition 2: centered at [-10, 0, 0]
            trials_c2 = randn(nTrials_per, nTime, k) + ...
                        reshape([-10, 0, 0], [1, 1, k]);

            labels = [ones(nTrials_per, 1); 2*ones(nTrials_per, 1)];
            trials = cat(1, trials_c1, trials_c2);

            sep = compute_condition_separation(trials, labels);

            % Separation should be substantially greater than zero
            testCase.verifyGreaterThan(mean(sep), 5.0, ...
                'Condition separation too small for well-separated clusters.');
        end

    end
end
