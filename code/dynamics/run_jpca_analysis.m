function result = run_jpca_analysis(trajectories, dt)
% RUN_JPCA_ANALYSIS Run jPCA analysis on condition-averaged trajectories.
%
%   result = run_jpca_analysis(trajectories, dt)
%
%   Performs jPCA analysis:
%   1. Stack condition trajectories and compute dz/dt via central differences
%   2. Fit skew-symmetric dynamics M: min||dZ - M*Z||^2 s.t. M = -M'
%      using M_skew = (M_raw - M_raw') / 2
%   3. Extract the dominant rotational plane from M_skew
%   4. Project each condition trajectory into the rotational plane
%
%   Inputs:
%       trajectories - cell array of [n_dims x n_time] matrices, one per condition
%       dt           - scalar time step between samples
%
%   Outputs:
%       result - struct with fields:
%           .M_raw                   - [n_dims x n_dims] unconstrained dynamics matrix
%           .M_skew                  - [n_dims x n_dims] skew-symmetric dynamics matrix
%           .eigenvalues             - [n_dims x 1] eigenvalues of M_skew
%           .W_rot                   - [n_dims x 2] rotational plane basis
%           .rotation_freq           - scalar rotation frequency
%           .r_squared_raw           - scalar R^2 for unconstrained fit
%           .r_squared_skew          - scalar R^2 for skew-symmetric fit
%           .projected_trajectories  - cell array of [2 x n_time_trimmed] projections
%           .var_explained           - scalar variance explained by rotational plane

    if nargin < 2
        error('run_jpca_analysis:missingInput', ...
            'Both trajectories and dt are required.');
    end

    n_conditions = numel(trajectories);
    n_dims = size(trajectories{1}, 1);

    % Step 1: Stack conditions, compute derivatives via central differences
    Z_all = [];
    dZ_all = [];

    for c = 1:n_conditions
        traj = trajectories{c};
        n_time = size(traj, 2);

        if n_time < 3
            error('run_jpca_analysis:tooFewTimepoints', ...
                'Each trajectory must have at least 3 time points.');
        end

        % Central difference derivative
        dz = estimate_tangent_vectors(traj, dt);

        % Corresponding state values (interior points only)
        z = traj(:, 2:end-1);

        Z_all = [Z_all, z];
        dZ_all = [dZ_all, dz];
    end

    % Step 2a: Fit unconstrained linear dynamics
    [M_raw, r_squared_raw] = fit_linear_dynamics(Z_all, dZ_all);

    % Step 2b: Enforce skew-symmetry: M_skew = (M_raw - M_raw') / 2
    M_skew = (M_raw - M_raw') / 2;

    % Compute R-squared for skew-symmetric fit
    dZ_pred_skew = M_skew * Z_all;
    residuals_skew = dZ_all - dZ_pred_skew;
    ss_res_skew = sum(residuals_skew(:) .^ 2);
    dZ_mean = mean(dZ_all, 2);
    dZ_centered = dZ_all - dZ_mean;
    ss_tot = sum(dZ_centered(:) .^ 2);

    if ss_tot > 0
        r_squared_skew = 1 - ss_res_skew / ss_tot;
    else
        r_squared_skew = 0;
    end

    % Eigenvalues of M_skew
    eigenvalues = eig(M_skew);

    % Step 3: Extract dominant rotational plane
    [W_rot, rotation_freq, var_explained] = extract_rotational_plane(M_skew, Z_all);

    % Step 4: Project each condition trajectory into the rotational plane
    projected_trajectories = cell(1, n_conditions);
    for c = 1:n_conditions
        traj = trajectories{c};
        traj_centered = traj - mean(traj, 2);
        projected_trajectories{c} = W_rot' * traj_centered;
    end

    % Build output struct
    result.M_raw = M_raw;
    result.M_skew = M_skew;
    result.eigenvalues = eigenvalues;
    result.W_rot = W_rot;
    result.rotation_freq = rotation_freq;
    result.r_squared_raw = r_squared_raw;
    result.r_squared_skew = r_squared_skew;
    result.projected_trajectories = projected_trajectories;
    result.var_explained = var_explained;

end
