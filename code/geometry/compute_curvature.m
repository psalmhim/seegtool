function curvature = compute_curvature(trajectory, dt)
% COMPUTE_CURVATURE Compute trajectory curvature: kappa = ||v x a|| / ||v||^3
    if nargin < 2, dt = 1; end
    v = diff(trajectory, 1, 2) / dt;
    a = diff(v, 1, 2) / dt;
    n_time = size(a, 2);
    n_dims = size(trajectory, 1);
    curvature = zeros(1, n_time);
    for t = 1:n_time
        vt = v(:, t);
        at = a(:, t);
        v_norm = norm(vt);
        if v_norm > eps
            if n_dims == 2
                cross_mag = abs(vt(1)*at(2) - vt(2)*at(1));
            elseif n_dims == 3
                cross_mag = norm(cross(vt, at));
            else
                % General: use ||a - (a.v/||v||^2)v|| * ||v||
                a_perp = at - (dot(at, vt)/dot(vt,vt)) * vt;
                cross_mag = norm(a_perp) * v_norm;
            end
            curvature(t) = cross_mag / v_norm^3;
        end
    end
end
