function result = run_dynamical_systems_analysis(trajectories, dt, latent_tensor, opts)
% RUN_DYNAMICAL_SYSTEMS_ANALYSIS Main pipeline for dynamical systems analysis.
%
%   result = run_dynamical_systems_analysis(trajectories, dt, latent_tensor)
%   result = run_dynamical_systems_analysis(trajectories, dt, latent_tensor, opts)
%
%   Runs the full dynamical systems analysis pipeline:
%   1. jPCA analysis (rotational dynamics)
%   2. Tangent space analysis (time-resolved principal angles)
%   3. State space occupancy (effective dimensionality)
%   4. Trajectory recurrence (per condition)
%   5. Subspace overlap (between all condition pairs using jPCA projection)
%
%   Inputs:
%       trajectories  - cell array of [n_dims x n_time] condition-averaged trajectories
%       dt            - scalar time step between samples
%       latent_tensor - [n_trials x n_dims x n_time] tensor of single-trial latent states
%       opts          - (optional) struct with fields:
%           .epsilon       - recurrence threshold (default: [] for auto)
%           .n_dims_overlap - number of PCA dims for subspace overlap (default: 2)
%
%   Outputs:
%       result - struct with fields:
%           .jpca              - output of run_jpca_analysis
%           .tangent_space     - output of run_tangent_space_analysis
%           .state_space       - output of compute_state_space_occupancy
%           .recurrence        - cell array of recurrence results per condition
%           .subspace_overlap  - struct with overlap matrix and pair labels

    if nargin < 3
        error('run_dynamical_systems_analysis:missingInput', ...
            'trajectories, dt, and latent_tensor are required.');
    end

    if nargin < 4
        opts = struct();
    end

    % Default options
    if ~isfield(opts, 'epsilon')
        opts.epsilon = [];
    end
    if ~isfield(opts, 'n_dims_overlap')
        opts.n_dims_overlap = 2;
    end

    n_conditions = numel(trajectories);

    % 1. jPCA analysis
    fprintf('Running jPCA analysis...\n');
    jpca_result = run_jpca_analysis(trajectories, dt);

    % 2. Tangent space analysis
    fprintf('Running tangent space analysis...\n');
    tangent_result = run_tangent_space_analysis(trajectories, dt);

    % 3. State space occupancy
    fprintf('Computing state space occupancy...\n');
    state_space_result = compute_state_space_occupancy(latent_tensor);

    % 4. Trajectory recurrence (per condition)
    fprintf('Computing trajectory recurrence...\n');
    recurrence_results = cell(1, n_conditions);
    for c = 1:n_conditions
        recurrence_results{c} = compute_trajectory_recurrence( ...
            trajectories{c}, opts.epsilon);
    end

    % 5. Subspace overlap between condition pairs
    fprintf('Computing subspace overlap...\n');
    n_dims_overlap = min(opts.n_dims_overlap, size(trajectories{1}, 1));

    % Extract top PCA subspace per condition
    condition_subspaces = cell(1, n_conditions);
    for c = 1:n_conditions
        traj = trajectories{c};
        traj_centered = traj - mean(traj, 2);
        [U, ~, ~] = svd(traj_centered, 'econ');
        condition_subspaces{c} = U(:, 1:min(n_dims_overlap, size(U, 2)));
    end

    overlap_matrix = zeros(n_conditions, n_conditions);
    n_pairs = n_conditions * (n_conditions - 1) / 2;
    overlap_pairs = zeros(n_pairs, 2);
    overlap_values = zeros(n_pairs, 1);
    pair_idx = 0;

    for c1 = 1:n_conditions
        overlap_matrix(c1, c1) = 1;
        for c2 = (c1 + 1):n_conditions
            pair_idx = pair_idx + 1;
            overlap_pairs(pair_idx, :) = [c1, c2];

            ov = compute_subspace_overlap( ...
                condition_subspaces{c1}, condition_subspaces{c2});

            overlap_matrix(c1, c2) = ov;
            overlap_matrix(c2, c1) = ov;
            overlap_values(pair_idx) = ov;
        end
    end

    % Build output struct
    result.jpca = jpca_result;
    result.tangent_space = tangent_result;
    result.state_space = state_space_result;
    result.recurrence = recurrence_results;
    result.subspace_overlap.matrix = overlap_matrix;
    result.subspace_overlap.pair_labels = overlap_pairs;
    result.subspace_overlap.values = overlap_values;
    result.subspace_overlap.n_dims = n_dims_overlap;

    fprintf('Dynamical systems analysis complete.\n');

end
