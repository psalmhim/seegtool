function result = run_tangent_space_analysis(trajectories, dt)
% RUN_TANGENT_SPACE_ANALYSIS Tangent space analysis across conditions.
%
%   result = run_tangent_space_analysis(trajectories, dt)
%
%   For each condition, estimates tangent vectors via central differences.
%   Then computes time-resolved principal angles between all pairs of conditions.
%
%   Inputs:
%       trajectories - cell array of [n_dims x n_time] matrices, one per condition
%       dt           - scalar time step between samples
%
%   Outputs:
%       result - struct with fields:
%           .tangent_vectors  - cell array of [n_dims x (n_time-2)] tangent vectors
%                               per condition
%           .principal_angles - struct with fields:
%               .angles       - [n_pairs x n_angles x n_time_common] array of
%                                principal angles over time (radians)
%               .pair_labels  - [n_pairs x 2] matrix of condition index pairs
%               .time_indices - [1 x n_time_common] indices into interior time points

    if nargin < 2
        error('run_tangent_space_analysis:missingInput', ...
            'Both trajectories and dt are required.');
    end

    n_conditions = numel(trajectories);

    % Step 1: Estimate tangent vectors for each condition
    tangent_vectors = cell(1, n_conditions);
    n_time_trimmed = zeros(1, n_conditions);

    for c = 1:n_conditions
        tangent_vectors{c} = estimate_tangent_vectors(trajectories{c}, dt);
        n_time_trimmed(c) = size(tangent_vectors{c}, 2);
    end

    % Common time length (minimum across conditions)
    n_time_common = min(n_time_trimmed);

    if n_time_common < 1
        error('run_tangent_space_analysis:noCommonTime', ...
            'No common time points available after computing tangent vectors.');
    end

    % Step 2: Compute time-resolved principal angles between all condition pairs
    n_pairs = n_conditions * (n_conditions - 1) / 2;
    pair_labels = zeros(n_pairs, 2);

    % Determine number of principal angles (1 per tangent vector at each time)
    % At each time point, we compare single tangent vectors -> 1 angle per pair
    % But we can use a sliding window to build local subspaces
    % For single-vector comparison, principal angle = angle between two vectors

    pair_idx = 0;

    % Pre-allocate: for single tangent vectors, there is 1 principal angle per pair per time
    angles_all = zeros(n_pairs, 1, n_time_common);

    for c1 = 1:n_conditions
        for c2 = (c1 + 1):n_conditions
            pair_idx = pair_idx + 1;
            pair_labels(pair_idx, :) = [c1, c2];

            for t = 1:n_time_common
                v_A = tangent_vectors{c1}(:, t);
                v_B = tangent_vectors{c2}(:, t);

                % Principal angle between two 1-D subspaces
                angles_t = compute_principal_angles(v_A, v_B);
                angles_all(pair_idx, 1:numel(angles_t), t) = angles_t;
            end
        end
    end

    % Build output struct
    result.tangent_vectors = tangent_vectors;
    result.principal_angles.angles = angles_all;
    result.principal_angles.pair_labels = pair_labels;
    result.principal_angles.time_indices = 1:n_time_common;

end
