function [velocity, speed] = compute_velocity(trajectory, dt)
% COMPUTE_VELOCITY Compute trajectory velocity using finite differences.
%   v(t) = z(t+dt) - z(t). trajectory: n_dims x time, dt: time step
    if nargin < 2, dt = 1; end
    velocity = diff(trajectory, 1, 2) / dt;
    speed = sqrt(sum(velocity.^2, 1));
end
