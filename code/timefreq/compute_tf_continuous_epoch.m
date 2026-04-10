function [tf_power, tf_phase, freqs, time_vec] = compute_tf_continuous_epoch( ...
    continuous_data, fs, event_times, pre_time, post_time, cfg)
% COMPUTE_TF_CONTINUOUS_EPOCH CWT on continuous signal, then epoch.
%
%   Runs CWT on the full continuous signal per channel, then extracts
%   event-locked epochs. Avoids edge artifacts from per-epoch CWT.
%
%   Backend priority: fCWT → MATLAB cwt() → manual Morlet convolution.
%
%   Inputs:
%       continuous_data - channels x time
%       fs              - sampling rate (Hz)
%       event_times     - event onset times (seconds)
%       pre_time        - pre-event window (positive, seconds)
%       post_time       - post-event window (positive, seconds)
%       cfg             - config with freq_range, num_freqs, wavelet_cycles
%
%   Outputs:
%       tf_power  - trials x channels x freqs x epoch_time  (single)
%       tf_phase  - trials x channels x freqs x epoch_time  (single)
%       freqs     - frequency vector (Hz)
%       time_vec  - epoch time vector relative to event (seconds)

    n_channels = size(continuous_data, 1);
    n_time_full = size(continuous_data, 2);

    % Epoch parameters
    pre_samples = round(pre_time * fs);
    post_samples = round(post_time * fs);
    epoch_length = pre_samples + post_samples + 1;
    time_vec = (-pre_samples:post_samples) / fs;

    % Identify valid events
    valid_idx = find_valid_events(event_times, fs, pre_samples, post_samples, n_time_full);
    n_trials = numel(valid_idx);

    if n_trials == 0
        warning('compute_tf_continuous_epoch:noTrials', 'No valid trials.');
        freqs = [];
        tf_power = zeros(0, n_channels, 0, epoch_length, 'single');
        tf_phase = zeros(0, n_channels, 0, epoch_length, 'single');
        return;
    end

    % Frequency axis
    freqs = logspace(log10(cfg.freq_range(1)), log10(cfg.freq_range(2)), cfg.num_freqs);
    n_freqs = numel(freqs);

    % Morlet parameter
    c0 = get_morlet_c0(cfg);

    % Output arrays
    tf_power = zeros(n_trials, n_channels, n_freqs, epoch_length, 'single');
    tf_phase = zeros(n_trials, n_channels, n_freqs, epoch_length, 'single');

    % Select backend
    backend = select_backend(cfg);
    fprintf('[TF] Backend: %s | %d ch x %d trials x %d freqs\n', backend, n_channels, n_trials, n_freqs);

    % Event sample indices (precompute)
    event_samples = zeros(n_trials, 1);
    for tr = 1:n_trials
        event_samples(tr) = round(event_times(valid_idx(tr)) * fs) + 1;
    end

    t_start = tic;

    switch backend
        case 'fcwt'
            [tf_power, tf_phase, freqs] = run_fcwt(continuous_data, fs, ...
                freqs, n_freqs, c0, n_channels, n_trials, epoch_length, ...
                event_samples, pre_samples, post_samples, tf_power, tf_phase, t_start);

        case 'matlab_cwt'
            [tf_power, tf_phase, freqs] = run_matlab_cwt(continuous_data, fs, ...
                freqs, n_freqs, n_channels, n_trials, epoch_length, ...
                event_samples, pre_samples, post_samples, tf_power, tf_phase, t_start);

        case 'morlet'
            [tf_power, tf_phase] = run_morlet(continuous_data, fs, ...
                freqs, n_freqs, cfg, n_channels, n_trials, epoch_length, ...
                event_samples, pre_samples, post_samples, tf_power, tf_phase, t_start);
    end

    fprintf('[TF] Done in %.1fs: %d trials x %d ch x %d freqs x %d time\n', ...
        toc(t_start), n_trials, n_channels, n_freqs, epoch_length);
end


%% ======================================================================
%  Backend implementations
%  ======================================================================

function [tf_power, tf_phase, freqs] = run_fcwt(continuous_data, fs, ...
    freqs, n_freqs, c0, n_channels, n_trials, epoch_length, ...
    event_samples, pre_samples, post_samples, tf_power, tf_phase, t_start)

    fcwt_dir = fileparts(which('fCWT'));
    old_dir = cd(fcwt_dir);
    dir_guard = onCleanup(@() cd(old_dir));
    w_state = warning('off', 'fcwt:nothreads');
    warn_guard = onCleanup(@() warning(w_state));

    % Try first channel — if it fails, error out so caller can retry with fallback
    sig = single(continuous_data(1, :));
    [cwt_mat, f_out] = fCWT(sig, c0, fs, freqs(1), freqs(end), n_freqs, 1);
    cwt_mat = cwt_mat.';
    epoch_cwt(cwt_mat, 1, n_trials, event_samples, pre_samples, post_samples, tf_power, tf_phase);

    for ch = 2:n_channels
        print_progress(ch, n_channels, t_start);
        sig = single(continuous_data(ch, :));
        [cwt_mat, ~] = fCWT(sig, c0, fs, freqs(1), freqs(end), n_freqs, 1);
        cwt_mat = cwt_mat.';
        epoch_cwt(cwt_mat, ch, n_trials, event_samples, pre_samples, post_samples, tf_power, tf_phase);
    end
    freqs = double(f_out(:)');
end


function [tf_power, tf_phase, freqs] = run_matlab_cwt(continuous_data, fs, ...
    freqs, n_freqs, n_channels, n_trials, epoch_length, ...
    event_samples, pre_samples, post_samples, tf_power, tf_phase, t_start)

    % Use MATLAB's built-in cwt (Wavelet Toolbox) — reliable and optimized
    % cwt() returns [freqs x time] complex coefficients
    for ch = 1:n_channels
        print_progress(ch, n_channels, t_start);
        sig = double(continuous_data(ch, :));
        [wt, f_cwt] = cwt(sig, 'amor', fs, 'FrequencyLimits', [freqs(1) freqs(end)]);
        % wt is [n_cwt_freqs x time] — interpolate to our target freq grid
        if ch == 1
            % Map cwt frequencies to our target frequencies
            [f_cwt_sorted, sort_idx] = sort(f_cwt);
            wt = wt(sort_idx, :);
            freqs_interp = freqs;
            n_freqs_cwt = size(wt, 1);
        end

        % Interpolate to target frequency grid if needed
        if n_freqs_cwt ~= n_freqs
            wt_interp = interp1(f_cwt_sorted, abs(wt), freqs_interp, 'linear', 'extrap') .* ...
                exp(1i * interp1(f_cwt_sorted, unwrap(angle(wt), [], 1), freqs_interp, 'linear', 'extrap'));
        else
            wt_interp = wt;
        end

        epoch_cwt(wt_interp, ch, n_trials, event_samples, pre_samples, post_samples, tf_power, tf_phase);
    end
    freqs = freqs_interp;
end


function [tf_power, tf_phase] = run_morlet(continuous_data, fs, ...
    freqs, n_freqs, cfg, n_channels, n_trials, epoch_length, ...
    event_samples, pre_samples, post_samples, tf_power, tf_phase, t_start)

    if isfield(cfg, 'wavelet_cycles') && numel(cfg.wavelet_cycles) == n_freqs
        cycles = cfg.wavelet_cycles;
    else
        cycles = linspace(cfg.wavelet_cycles_range(1), cfg.wavelet_cycles_range(2), n_freqs);
    end

    for ch = 1:n_channels
        print_progress(ch, n_channels, t_start);
        sig = double(continuous_data(ch, :));
        for fi = 1:n_freqs
            wavelet = create_morlet_wavelet(freqs(fi), cycles(fi), fs);
            analytic = convolve_wavelet(sig, wavelet);
            for tr = 1:n_trials
                es = event_samples(tr);
                idx_start = es - pre_samples;
                idx_end = es + post_samples;
                tf_power(tr, ch, fi, :) = single(abs(analytic(idx_start:idx_end)).^2);
                tf_phase(tr, ch, fi, :) = single(angle(analytic(idx_start:idx_end)));
            end
        end
    end
end


%% ======================================================================
%  Helpers
%  ======================================================================

function epoch_cwt(cwt_mat, ch, n_trials, event_samples, pre_samples, post_samples, tf_power, tf_phase)
% Extract epochs from continuous CWT result (in-place update)
    for tr = 1:n_trials
        es = event_samples(tr);
        idx_start = es - pre_samples;
        idx_end = es + post_samples;
        segment = cwt_mat(:, idx_start:idx_end);
        tf_power(tr, ch, :, :) = single(abs(segment).^2);
        tf_phase(tr, ch, :, :) = single(angle(segment));
    end
end


function valid_idx = find_valid_events(event_times, fs, pre_samples, post_samples, n_time_full)
    valid_mask = false(1, numel(event_times));
    for k = 1:numel(event_times)
        es = round(event_times(k) * fs) + 1;
        valid_mask(k) = (es - pre_samples >= 1) && (es + post_samples <= n_time_full);
    end
    valid_idx = find(valid_mask);
end


function c0 = get_morlet_c0(cfg)
    if isfield(cfg, 'wavelet_cycles_range')
        c0 = mean(cfg.wavelet_cycles_range);
    elseif isfield(cfg, 'wavelet_cycles') && numel(cfg.wavelet_cycles) >= 2
        c0 = mean(cfg.wavelet_cycles([1 end]));
    else
        c0 = 6;
    end
end


function backend = select_backend(cfg)
% Priority: fCWT > MATLAB cwt > manual Morlet
    if isfield(cfg, 'tf_backend')
        backend = cfg.tf_backend;
        return;
    end

    % Try fCWT
    if exist('fCWT', 'file') == 3
        try
            % Quick smoke test with tiny signal
            test_sig = single(randn(1, 256));
            fcwt_dir = fileparts(which('fCWT'));
            old_dir = cd(fcwt_dir);
            w_state = warning('off', 'fcwt:nothreads');
            fCWT(test_sig, 6, 256, 2, 100, 10, 1);
            warning(w_state);
            cd(old_dir);
            backend = 'fcwt';
            return;
        catch
            fprintf('[TF] fCWT smoke test failed, trying alternatives...\n');
        end
    end

    % Try MATLAB's cwt (Wavelet Toolbox)
    if exist('cwt', 'file') >= 2
        try
            cwt(randn(1, 256), 'amor', 256);
            backend = 'matlab_cwt';
            return;
        catch
            fprintf('[TF] MATLAB cwt not available, using manual Morlet.\n');
        end
    end

    backend = 'morlet';
end


function print_progress(ch, n_channels, t_start)
    if mod(ch, 20) == 1 || ch == n_channels
        elapsed = toc(t_start);
        if ch > 1
            eta = elapsed / (ch - 1) * (n_channels - ch);
            fprintf('[TF]   channel %d/%d (%.0fs elapsed, ETA %.0fs)\n', ch, n_channels, elapsed, eta);
        else
            fprintf('[TF]   channel %d/%d\n', ch, n_channels);
        end
    end
end
