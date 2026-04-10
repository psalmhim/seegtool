function lnr_vals = compute_line_noise_ratio(trial_tensor, time_vec, fs, line_freq, baseline_window)
% COMPUTE_LINE_NOISE_RATIO Compute line noise power ratio in baseline.
%
%   lnr_vals = compute_line_noise_ratio(trial_tensor, time_vec, fs, line_freq, baseline_window)
%
%   Inputs:
%       trial_tensor    - trials x channels x time
%       time_vec        - time vector in seconds
%       fs              - sampling rate (Hz)
%       line_freq       - line noise frequency (Hz)
%       baseline_window - [start_time, end_time] in seconds
%
%   Outputs:
%       lnr_vals - trials x channels matrix of line noise ratios

    if nargin < 4 || isempty(line_freq)
        line_freq = 60;
    end

    base_idx = time_vec >= baseline_window(1) & time_vec <= baseline_window(2);
    base_data = trial_tensor(:, :, base_idx);

    n_trials = size(base_data, 1);
    n_channels = size(base_data, 2);
    n_base = size(base_data, 3);

    nfft = 2^nextpow2(n_base);
    freqs_fft = (0:nfft/2) * fs / nfft;
    line_idx = freqs_fft >= (line_freq - 1) & freqs_fft <= (line_freq + 1);

    lnr_vals = zeros(n_trials, n_channels);
    for k = 1:n_trials
        for ch = 1:n_channels
            sig = squeeze(base_data(k, ch, :))';
            psd = abs(fft(sig, nfft)).^2 / n_base;
            psd = psd(1:nfft/2 + 1);
            total_power = sum(psd);
            if total_power > 0
                lnr_vals(k, ch) = sum(psd(line_idx)) / total_power;
            end
        end
    end
end
