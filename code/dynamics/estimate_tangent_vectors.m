function tangent_vectors = estimate_tangent_vectors(trajectory, dt)
% ESTIMATE_TANGENT_VECTORS Estimate tangent vectors via central differences.
%
%   tangent_vectors = estimate_tangent_vectors(trajectory, dt)
%
%   Computes v(t) = (z(t+dt) - z(t-dt)) / (2*dt) for each interior time point.
%
%   Inputs:
%       trajectory      - [n_dims x time] matrix of latent state trajectories
%       dt              - scalar time step between samples
%
%   Outputs:
%       tangent_vectors - [n_dims x (time-2)] matrix of estimated tangent vectors
%
%   The first and last time points are excluded because central differences
%   require neighboring points on both sides.

    if nargin < 2
        error('estimate_tangent_vectors:missingInput', ...
            'Both trajectory and dt are required.');
    end

    [n_dims, n_time] = size(trajectory);

    if n_time < 3
        error('estimate_tangent_vectors:tooFewTimepoints', ...
            'Trajectory must have at least 3 time points for central differences.');
    end

    if ~isscalar(dt) || dt <= 0
        error('estimate_tangent_vectors:invalidDt', ...
            'dt must be a positive scalar.');
    end

    % Central difference: v(t) = (z(t+1) - z(t-1)) / (2*dt)
    z_forward = trajectory(:, 3:end);       % z(t+dt)
    z_backward = trajectory(:, 1:end-2);    % z(t-dt)

    tangent_vectors = (z_forward - z_backward) / (2 * dt);

end
