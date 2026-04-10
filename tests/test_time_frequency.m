classdef test_time_frequency < matlab.unittest.TestCase
    % TEST_TIME_FREQUENCY Unit tests for time-frequency analysis functions.
    %
    % Tests cover: Morlet wavelet creation, wavelet convolution, known
    % frequency detection, baseline normalization (dB), inter-trial phase
    % coherence (ITPC), and band-power extraction.

    properties
        Fs
        Duration
        T
        Tol
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.Fs       = 1000;
            testCase.Duration = 2;
            testCase.T        = (0 : 1/testCase.Fs : testCase.Duration - 1/testCase.Fs)';
            testCase.Tol      = 1e-6;
        end
    end

    % ------------------------------------------------------------------
    methods (Test)

        function test_morlet_wavelet_shape(testCase)
            % A Morlet wavelet created for a given center frequency should
            % have its spectral peak at that frequency.
            center_freq = 30;  % Hz
            n_cycles    = 7;

            [wavelet, ~] = create_morlet_wavelet(center_freq, testCase.Fs, n_cycles);

            % Compute the spectrum of the wavelet
            N      = length(wavelet);
            fft_w  = abs(fft(wavelet, N));
            freqs  = (0:N-1) * (testCase.Fs / N);
            half   = 1:floor(N/2);

            [~, peak_idx] = max(fft_w(half));
            peak_freq     = freqs(peak_idx);

            testCase.verifyEqual(peak_freq, center_freq, ...
                'AbsTol', 2, ...
                'Wavelet spectral peak does not match center frequency.');
        end

        function test_wavelet_convolution_length(testCase)
            % Output of wavelet convolution should have the same length as
            % the input signal (after trimming).
            signal      = randn(length(testCase.T), 1);
            center_freq = 20;
            n_cycles    = 7;

            analytic = convolve_wavelet(signal, testCase.Fs, center_freq, n_cycles);

            testCase.verifyEqual(length(analytic), length(signal), ...
                'Convolution output length does not match input.');
        end

        function test_known_frequency_detection(testCase)
            % Generate a pure sine wave at a known frequency and verify
            % that the time-frequency representation peaks at that freq.
            target_freq = 40;  % Hz
            signal      = sin(2*pi*target_freq*testCase.T);
            freqs       = 5:2:80;

            tf_power = compute_time_frequency(signal, testCase.Fs, freqs);

            % tf_power: [nFreqs x nTime]
            mean_power   = mean(tf_power, 2);
            [~, max_idx] = max(mean_power);
            detected     = freqs(max_idx);

            testCase.verifyEqual(detected, target_freq, ...
                'AbsTol', 4, ...
                'Peak frequency in TF map does not match target.');
        end

        function test_baseline_normalization_db(testCase)
            % Verify dB normalization: dB = 10 * log10(power / baseline).
            nFreqs = 10;
            nTime  = 200;
            rng(42);
            tf_power      = 2 + rand(nFreqs, nTime);
            baseline_idx  = 1:50;

            tf_db = baseline_normalize_tf(tf_power, baseline_idx, 'db');

            % Manually compute expected dB for one frequency row
            row        = 1;
            bl_mean    = mean(tf_power(row, baseline_idx));
            expected   = 10 * log10(tf_power(row, :) / bl_mean);

            testCase.verifyEqual(tf_db(row, :), expected, ...
                'AbsTol', 1e-10, ...
                'dB normalization does not match manual computation.');
        end

        function test_itpc_perfect_phase_lock(testCase)
            % When all trials have identical phase, ITPC should equal 1.
            nTrials = 50;
            freq    = 10;
            nTime   = length(testCase.T);

            % All trials are identical sine waves -> identical phase
            phase_angles = repmat(2*pi*freq*testCase.T', [nTrials, 1]);
            % phase_angles: [nTrials x nTime]

            itpc = compute_itpc(exp(1i * phase_angles));

            % ITPC should be 1 everywhere
            testCase.verifyEqual(mean(itpc), 1.0, 'AbsTol', testCase.Tol, ...
                'ITPC should be 1.0 for perfectly phase-locked trials.');
        end

        function test_itpc_random_phase(testCase)
            % When trial phases are uniformly random, ITPC should be near 0.
            rng(123);
            nTrials = 500;
            nTime   = 200;

            random_phases = 2*pi*rand(nTrials, nTime);
            itpc = compute_itpc(exp(1i * random_phases));

            testCase.verifyLessThan(mean(itpc), 0.15, ...
                'ITPC should be near zero for random phases.');
        end

        function test_band_power_extraction(testCase)
            % Verify that band power extraction averages power over the
            % correct frequency range.
            nFreqs = 50;
            nTime  = 200;
            freqs  = linspace(1, 100, nFreqs);
            rng(7);
            tf_power = rand(nFreqs, nTime);

            band = [8 13];  % alpha band
            band_pow = compute_band_limited_power(tf_power, freqs, band);

            % Manual: average rows where freqs are within [8, 13]
            in_band  = freqs >= band(1) & freqs <= band(2);
            expected = mean(tf_power(in_band, :), 1);

            testCase.verifyEqual(band_pow, expected, 'AbsTol', testCase.Tol, ...
                'Band power does not match manual frequency-range average.');
        end

    end
end
