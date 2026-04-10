function result = compute_trajectory_recurrence(trajectory, epsilon)
% COMPUTE_TRAJECTORY_RECURRENCE Compute recurrence matrix of a trajectory.
%
%   result = compute_trajectory_recurrence(trajectory)
%   result = compute_trajectory_recurrence(trajectory, epsilon)
%
%   Constructs a recurrence matrix R where R(i,j) = 1 if
%   ||z(t_i) - z(t_j)|| < epsilon, and 0 otherwise.
%
%   Inputs:
%       trajectory - [n_dims x n_time] matrix of latent state trajectory
%       epsilon    - (optional) distance threshold. Default: 10% of the
%                    maximum pairwise distance in the trajectory.
%
%   Outputs:
%       result - struct with fields:
%           .recurrence_matrix - [n_time x n_time] binary recurrence matrix
%           .recurrence_rate   - scalar fraction of recurrent points
%           .epsilon           - scalar threshold used
%           .distance_matrix   - [n_time x n_time] pairwise distance matrix

    if nargin < 1
        error('compute_trajectory_recurrence:missingInput', ...
            'trajectory is required.');
    end

    [n_dims, n_time] = size(trajectory);

    % Compute pairwise Euclidean distance matrix
    % distance_matrix(i,j) = ||z(:,i) - z(:,j)||
    distance_matrix = zeros(n_time, n_time);
    for i = 1:n_time
        diff = trajectory - trajectory(:, i);
        distance_matrix(i, :) = sqrt(sum(diff .^ 2, 1));
    end

    % Default epsilon: 10% of maximum distance
    if nargin < 2 || isempty(epsilon)
        max_dist = max(distance_matrix(:));
        if max_dist > 0
            epsilon = 0.1 * max_dist;
        else
            epsilon = 1;
        end
    end

    % Build recurrence matrix
    recurrence_matrix = double(distance_matrix < epsilon);

    % Recurrence rate: fraction of recurrent points excluding the diagonal
    n_recurrent = sum(recurrence_matrix(:)) - n_time;  % subtract diagonal
    n_possible = n_time * (n_time - 1);

    if n_possible > 0
        recurrence_rate = n_recurrent / n_possible;
    else
        recurrence_rate = 0;
    end

    % Build output struct
    result.recurrence_matrix = recurrence_matrix;
    result.recurrence_rate = recurrence_rate;
    result.epsilon = epsilon;
    result.distance_matrix = distance_matrix;

end
