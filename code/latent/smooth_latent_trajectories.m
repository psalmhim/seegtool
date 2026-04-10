function smoothed = smooth_latent_trajectories(latent_tensor, kernel_ms, fs)
% SMOOTH_LATENT_TRAJECTORIES Apply Gaussian smoothing to latent trajectories.
%
%   smoothed = smooth_latent_trajectories(latent_tensor, kernel_ms, fs)
%
%   Inputs:
%       latent_tensor - trials x n_dims x time
%       kernel_ms     - kernel width in milliseconds
%       fs            - sampling rate (Hz)
%
%   Outputs:
%       smoothed - smoothed latent tensor, same size

    kernel_samples = round(kernel_ms / 1000 * fs);
    if kernel_samples < 1
        smoothed = latent_tensor;
        return;
    end

    % Create Gaussian kernel
    half_width = 3 * kernel_samples;
    t = -half_width:half_width;
    kernel = exp(-t.^2 / (2 * kernel_samples^2));
    kernel = kernel / sum(kernel);

    [n_trials, n_dims, n_time] = size(latent_tensor);
    smoothed = zeros(size(latent_tensor));

    for k = 1:n_trials
        for d = 1:n_dims
            sig = squeeze(latent_tensor(k, d, :))';
            smoothed(k, d, :) = conv(sig, kernel, 'same');
        end
    end
end
