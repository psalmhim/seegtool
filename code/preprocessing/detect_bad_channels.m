function [bad_channels, metrics] = detect_bad_channels(data, fs, zscore_threshold, line_freq)
% DETECT_BAD_CHANNELS Identify bad channels using statistical metrics.
%
%   [bad_channels, metrics] = detect_bad_channels(data, fs, zscore_threshold)
%
%   Metrics: variance, RMS, line noise ratio, kurtosis.
%   Channels with any z-scored metric exceeding threshold are flagged.
%
%   Inputs:
%       data             - channels x time matrix
%       fs               - sampling rate (Hz)
%       zscore_threshold - z-score threshold for bad channel detection (default: 3.0)
%
%   Outputs:
%       bad_channels - logical vector (true = bad)
%       metrics      - struct with individual metric values per channel

    if nargin < 3 || isempty(zscore_threshold)
        zscore_threshold = 3.0;
    end
    if nargin < 4 || isempty(line_freq)
        line_freq = 60;
    end

    n_channels = size(data, 1);

    % Compute metrics
    metrics.variance = var(data, 0, 2);
    metrics.rms = sqrt(mean(data.^2, 2));
    metrics.kurtosis = kurtosis(data, 1, 2);

    % Line noise ratio: power at line freq / total power
    nfft = 2^nextpow2(size(data, 2));
    freqs_fft = (0:nfft/2) * fs / nfft;
    line_idx = find(freqs_fft >= line_freq - 1 & freqs_fft <= line_freq + 1);

    metrics.line_noise_ratio = zeros(n_channels, 1);
    for ch = 1:n_channels
        psd = abs(fft(data(ch, :), nfft)).^2 / size(data, 2);
        psd = psd(1:nfft/2 + 1);
        total_power = sum(psd);
        if total_power > 0
            metrics.line_noise_ratio(ch) = sum(psd(line_idx)) / total_power;
        end
    end

    % Z-score each metric and flag bad channels
    metric_names = {'variance', 'rms', 'kurtosis', 'line_noise_ratio'};
    bad_channels = false(n_channels, 1);

    for m = 1:numel(metric_names)
        vals = metrics.(metric_names{m});
        mu = median(vals);
        sigma = mad(vals, 1) * 1.4826;
        if sigma > 0
            z = abs(vals - mu) / sigma;
        else
            z = zeros(size(vals));
        end
        metrics.([metric_names{m}, '_zscore']) = z;
        bad_channels = bad_channels | (z > zscore_threshold);
    end
end
