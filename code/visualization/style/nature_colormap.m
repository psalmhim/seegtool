function cmap = nature_colormap(name, n)
% NATURE_COLORMAP Perceptually uniform colormaps for publication figures.
%
%   cmap = nature_colormap('diverging')    - blue-white-red for TF power
%   cmap = nature_colormap('sequential')   - white-to-dark-blue for ITPC
%   cmap = nature_colormap('thermal')      - white-yellow-red for significance
%   cmap = nature_colormap('viridis')      - perceptually uniform sequential
%
%   cmap = nature_colormap(name, n) returns n-entry colormap (default: 256)

    if nargin < 2
        n = 256;
    end

    switch lower(name)
        case 'diverging'
            % Blue - white - red (symmetric, for normalized power)
            anchors = [
                0.019, 0.188, 0.380;   % dark blue
                0.400, 0.600, 0.850;   % light blue
                0.970, 0.970, 0.970;   % near white
                0.890, 0.500, 0.380;   % light red
                0.600, 0.050, 0.050;   % dark red
            ];

        case 'sequential'
            % White to dark blue (for ITPC, coherence)
            anchors = [
                0.970, 0.970, 0.970;   % white
                0.700, 0.800, 0.920;   % light blue
                0.300, 0.500, 0.780;   % medium blue
                0.100, 0.250, 0.580;   % dark blue
                0.020, 0.100, 0.350;   % very dark blue
            ];

        case 'thermal'
            % White to yellow to red to dark (for significance/effect maps)
            anchors = [
                0.970, 0.970, 0.970;   % white
                1.000, 0.900, 0.400;   % yellow
                0.950, 0.500, 0.200;   % orange
                0.800, 0.150, 0.150;   % red
                0.350, 0.050, 0.100;   % dark red
            ];

        case 'viridis'
            % Approximation of matplotlib viridis
            anchors = [
                0.267, 0.004, 0.329;
                0.282, 0.140, 0.458;
                0.253, 0.265, 0.530;
                0.191, 0.407, 0.556;
                0.127, 0.566, 0.551;
                0.199, 0.718, 0.489;
                0.565, 0.843, 0.262;
                0.993, 0.906, 0.144;
            ];

        otherwise
            error('Unknown colormap: %s', name);
    end

    x_anchors = linspace(0, 1, size(anchors, 1));
    x_interp = linspace(0, 1, n);
    cmap = interp1(x_anchors, anchors, x_interp, 'pchip');
    cmap = max(0, min(1, cmap));
end
