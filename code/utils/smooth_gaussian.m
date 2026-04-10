function smoothed = smooth_gaussian(data, kernel_width, fs)
% SMOOTH_GAUSSIAN Apply Gaussian smoothing to data.
%
%   smoothed = smooth_gaussian(data, kernel_width, fs)
%
%   Inputs:
%       data         - vector or matrix (smooth each row)
%       kernel_width - kernel width in milliseconds
%       fs           - sampling rate (Hz)
%
%   Outputs:
%       smoothed - smoothed data, same size as input

    kernel_samples = round(kernel_width / 1000 * fs);
    if kernel_samples < 1
        smoothed = data;
        return;
    end

    half_width = 3 * kernel_samples;
    t = -half_width:half_width;
    kernel = exp(-t.^2 / (2 * kernel_samples^2));
    kernel = kernel / sum(kernel);

    if isvector(data)
        smoothed = conv(data, kernel, 'same');
    else
        smoothed = zeros(size(data));
        for r = 1:size(data, 1)
            smoothed(r, :) = conv(data(r, :), kernel, 'same');
        end
    end
end
