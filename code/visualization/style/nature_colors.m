function colors = nature_colors(n)
% NATURE_COLORS Return colorblind-safe color palette for conditions.
%
%   colors = nature_colors(n)
%
%   Returns an n x 3 matrix of RGB colors from the Wong (2011) palette.
%   For n > 8, generates additional colors by interpolation in Lab space.

    s = nature_style();
    base = s.colors.palette;

    if nargin < 1
        colors = base;
        return;
    end

    if n <= size(base, 1)
        colors = base(1:n, :);
    else
        % Interpolate additional colors in Lab space
        base_lab = rgb2lab(base);
        idx = linspace(1, size(base, 1), n);
        colors_lab = interp1(1:size(base, 1), base_lab, idx, 'pchip');
        colors = lab2rgb(colors_lab);
        colors = max(0, min(1, colors));
    end
end

function lab = rgb2lab(rgb)
% Simplified RGB -> Lab conversion via XYZ
    % Linearize sRGB
    lin = rgb;
    mask = rgb > 0.04045;
    lin(mask) = ((rgb(mask) + 0.055) / 1.055).^2.4;
    lin(~mask) = rgb(~mask) / 12.92;

    % RGB to XYZ (D65)
    M = [0.4124564 0.3575761 0.1804375;
         0.2126729 0.7151522 0.0721750;
         0.0193339 0.1191920 0.9503041];
    xyz = (M * lin')';

    % XYZ to Lab
    ref = [0.95047 1.0 1.08883];
    xyz_n = xyz ./ ref;
    f = xyz_n;
    mask = xyz_n > 0.008856;
    f(mask) = xyz_n(mask).^(1/3);
    f(~mask) = 7.787 * xyz_n(~mask) + 16/116;

    lab = zeros(size(rgb));
    lab(:,1) = 116 * f(:,2) - 16;
    lab(:,2) = 500 * (f(:,1) - f(:,2));
    lab(:,3) = 200 * (f(:,2) - f(:,3));
end

function rgb = lab2rgb(lab)
% Simplified Lab -> RGB conversion via XYZ
    fy = (lab(:,1) + 16) / 116;
    fx = lab(:,2) / 500 + fy;
    fz = fy - lab(:,3) / 200;

    f = [fx fy fz];
    xyz = f;
    mask = f > 0.206893;
    xyz(mask) = f(mask).^3;
    xyz(~mask) = (f(~mask) - 16/116) / 7.787;

    ref = [0.95047 1.0 1.08883];
    xyz = xyz .* ref;

    % XYZ to linear RGB
    M_inv = [ 3.2404542 -1.5371385 -0.4985314;
             -0.9692660  1.8760108  0.0415560;
              0.0556434 -0.2040259  1.0572252];
    lin = (M_inv * xyz')';

    % Gamma
    rgb = lin;
    mask = lin > 0.0031308;
    rgb(mask) = 1.055 * lin(mask).^(1/2.4) - 0.055;
    rgb(~mask) = 12.92 * lin(~mask);
end
