function [tf_power, tf_phase, freqs, time_vec] = compute_time_frequency(trial_tensor, fs, cfg)
% COMPUTE_TIME_FREQUENCY Time-frequency analysis using Morlet wavelets.
%
%   [tf_power, tf_phase, freqs, time_vec] = compute_time_frequency(trial_tensor, fs, cfg)
%
%   Uses fCWT (fast Continuous Wavelet Transform) when available for
%   GPU-accelerated / multi-threaded computation. Falls back to pure
%   MATLAB Morlet convolution otherwise.
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       fs           - sampling rate (Hz)
%       cfg          - config struct with freq_range, num_freqs, wavelet_cycles
%
%   Outputs:
%       tf_power  - trials x channels x freqs x time spectral power
%       tf_phase  - trials x channels x freqs x time phase angles (radians)
%       freqs     - frequency vector (Hz)
%       time_vec  - time vector (seconds)

    n_trials = size(trial_tensor, 1);
    n_channels = size(trial_tensor, 2);
    n_time = size(trial_tensor, 3);

    freqs = logspace(log10(cfg.freq_range(1)), log10(cfg.freq_range(2)), cfg.num_freqs);
    n_freqs = numel(freqs);

    time_vec = (0:n_time-1) / fs;

    % Morlet wavelet parameter (c0): mean of cycle range
    if isfield(cfg, 'wavelet_cycles_range')
        c0 = mean(cfg.wavelet_cycles_range);
    elseif isfield(cfg, 'wavelet_cycles') && numel(cfg.wavelet_cycles) >= 2
        c0 = mean(cfg.wavelet_cycles([1 end]));
    else
        c0 = 6;
    end

    % Try fCWT first (10-100x faster)
    use_fcwt = exist('fCWT', 'file') == 3;  % MEX file

    if use_fcwt
        try
            fprintf('[TF] Using fCWT (fast CWT) - %d trials x %d channels\n', n_trials, n_channels);

            % cd to fCWT MATLAB dir so wisdom files (.wis) are found
            fcwt_dir = fileparts(which('fCWT'));
            old_dir = cd(fcwt_dir);
            dir_guard = onCleanup(@() cd(old_dir));

            n_threads = 1;  % MATLAB MEX limitation (see fCWT Issue #17)
            tf_power = zeros(n_trials, n_channels, n_freqs, n_time, 'single');
            tf_phase = zeros(n_trials, n_channels, n_freqs, n_time, 'single');

            % Suppress fCWT thread warning (MEX always warns, even with nthreads=1)
            w_state = warning('off', 'fcwt:nothreads');
            warn_guard = onCleanup(@() warning(w_state));

            for k = 1:n_trials
                for ch = 1:n_channels
                    sig = single(squeeze(trial_tensor(k, ch, :))');
                    [tfm, f_out] = fCWT(sig, c0, fs, freqs(1), freqs(end), n_freqs, n_threads);
                    % fCWT returns [time x freq] complex matrix
                    % We need [freq x time], so transpose
                    tfm = tfm.';
                    % Trim or pad to match n_time
                    n_t_out = size(tfm, 2);
                    n_use = min(n_t_out, n_time);
                    tf_power(k, ch, :, 1:n_use) = abs(tfm(:, 1:n_use)).^2;
                    tf_phase(k, ch, :, 1:n_use) = angle(tfm(:, 1:n_use));
                end
            end
            % Use fCWT's frequency vector on first call to verify alignment
            freqs = double(f_out(:)');
            return;
        catch me
            fprintf('[TF] fCWT failed (%s), falling back to MATLAB wavelets\n', me.message);
            use_fcwt = false;
        end
    end

    if ~use_fcwt
        fprintf('[TF] Using MATLAB Morlet wavelets - %d trials x %d channels x %d freqs\n', ...
            n_trials, n_channels, n_freqs);

        if isfield(cfg, 'wavelet_cycles') && numel(cfg.wavelet_cycles) == n_freqs
            cycles = cfg.wavelet_cycles;
        else
            cycles = linspace(cfg.wavelet_cycles_range(1), cfg.wavelet_cycles_range(2), n_freqs);
        end

        tf_power = zeros(n_trials, n_channels, n_freqs, n_time);
        tf_phase = zeros(n_trials, n_channels, n_freqs, n_time);

        for fi = 1:n_freqs
            wavelet = create_morlet_wavelet(freqs(fi), cycles(fi), fs);
            for k = 1:n_trials
                for ch = 1:n_channels
                    sig = squeeze(trial_tensor(k, ch, :))';
                    analytic = convolve_wavelet(sig, wavelet);
                    tf_power(k, ch, fi, :) = abs(analytic).^2;
                    tf_phase(k, ch, fi, :) = angle(analytic);
                end
            end
        end
    end
end
