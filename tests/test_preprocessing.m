classdef test_preprocessing < matlab.unittest.TestCase
    % TEST_PREPROCESSING Unit tests for SEEG preprocessing functions.
    %
    % Tests cover: highpass filtering, lowpass filtering, line noise removal,
    % common average re-referencing, bipolar re-referencing, bad channel
    % detection, and artifact detection.

    properties
        Fs          % sampling rate (Hz)
        Duration    % signal duration (s)
        NChan       % number of channels
        T           % time vector
        Tol         % numeric tolerance
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.Fs       = 1000;
            testCase.Duration = 2;
            testCase.NChan    = 16;
            testCase.T        = (0 : 1/testCase.Fs : testCase.Duration - 1/testCase.Fs)';
            testCase.Tol      = 1e-6;
        end
    end

    % ------------------------------------------------------------------
    methods (Test)

        function test_highpass_removes_dc(testCase)
            % A signal with a large DC offset should have that offset
            % removed after highpass filtering.
            dc_offset = 100;
            signal    = dc_offset + 0.5 * randn(length(testCase.T), 1);
            cutoff_hz = 1;

            filtered = apply_highpass(signal, testCase.Fs, cutoff_hz);

            % After highpass the mean should be close to zero.
            testCase.verifyLessThan(abs(mean(filtered)), 1, ...
                'DC component was not adequately removed by highpass filter.');
        end

        function test_lowpass_removes_high_freq(testCase)
            % Inject a high-frequency component and verify it is
            % attenuated after lowpass filtering.
            low_freq  = 5;   % Hz - should be preserved
            high_freq = 200; % Hz - should be removed
            cutoff_hz = 50;

            signal = sin(2*pi*low_freq*testCase.T) + ...
                     sin(2*pi*high_freq*testCase.T);

            filtered = apply_lowpass(signal, testCase.Fs, cutoff_hz);

            % Compute power at high frequency via FFT
            N    = length(filtered);
            fft_vals = abs(fft(filtered));
            freqs    = (0:N-1) * (testCase.Fs / N);
            high_idx = find(freqs >= high_freq - 2 & freqs <= high_freq + 2);
            low_idx  = find(freqs >= low_freq - 2 & freqs <= low_freq + 2);

            high_power = max(fft_vals(high_idx));
            low_power  = max(fft_vals(low_idx));

            testCase.verifyLessThan(high_power / low_power, 0.05, ...
                'High frequency component was not sufficiently attenuated.');
        end

        function test_line_noise_removal(testCase)
            % Inject 60 Hz line noise on top of a broadband signal and
            % verify that the notch / removal function attenuates it.
            line_freq    = 60;
            noise_amp    = 10;
            signal       = randn(length(testCase.T), 1);
            signal_noisy = signal + noise_amp * sin(2*pi*line_freq*testCase.T);

            cleaned = remove_line_noise(signal_noisy, testCase.Fs, line_freq);

            % Measure remaining 60 Hz power
            N        = length(cleaned);
            fft_vals = abs(fft(cleaned));
            freqs    = (0:N-1) * (testCase.Fs / N);
            idx_60   = find(freqs >= 59 & freqs <= 61);

            fft_orig = abs(fft(signal_noisy));
            ratio    = max(fft_vals(idx_60)) / max(fft_orig(idx_60));

            testCase.verifyLessThan(ratio, 0.1, ...
                '60 Hz line noise was not adequately attenuated.');
        end

        function test_car_referencing(testCase)
            % After common-average re-referencing the mean across channels
            % at each time point should be approximately zero.
            data = randn(length(testCase.T), testCase.NChan);

            reref = rereference_car(data);

            mean_across_chan = mean(reref, 2);
            testCase.verifyLessThan(max(abs(mean_across_chan)), testCase.Tol, ...
                'Mean across channels is not zero after CAR.');
        end

        function test_bipolar_referencing(testCase)
            % Bipolar re-referencing should produce adjacent-contact
            % differences: bipolar(:,k) = data(:,k) - data(:,k+1).
            data = randn(length(testCase.T), testCase.NChan);

            bipolar = rereference_bipolar(data);

            % Output should have NChan-1 channels
            testCase.verifySize(bipolar, ...
                [length(testCase.T), testCase.NChan - 1], ...
                'Bipolar output has unexpected dimensions.');

            % Verify first bipolar channel equals difference of first two
            expected_first = data(:,1) - data(:,2);
            testCase.verifyEqual(bipolar(:,1), expected_first, ...
                'AbsTol', testCase.Tol, ...
                'Bipolar channel does not match adjacent contact difference.');
        end

        function test_bad_channel_detection(testCase)
            % Create clean multichannel data, then corrupt one channel
            % with large noise. The detector should flag the bad channel.
            data = randn(length(testCase.T), testCase.NChan);
            bad_ch = 5;
            data(:, bad_ch) = 50 * randn(length(testCase.T), 1);

            bad_channels = detect_bad_channels(data, testCase.Fs);

            testCase.verifyTrue(ismember(bad_ch, bad_channels), ...
                'Bad channel was not detected.');
        end

        function test_artifact_detection(testCase)
            % Inject a large amplitude spike into clean data and verify
            % that the artifact detector marks the correct segment.
            data = 0.5 * randn(length(testCase.T), 1);
            spike_center = round(length(testCase.T) / 2);
            spike_half   = 5;  % samples
            idx_range    = (spike_center - spike_half):(spike_center + spike_half);
            data(idx_range) = 100;

            artifact_mask = detect_artifact_segments(data, testCase.Fs);

            % artifact_mask is logical vector same length as data
            testCase.verifySize(artifact_mask, size(data(:,1)), ...
                'Artifact mask has unexpected size.');

            % The spike region must be flagged
            testCase.verifyTrue(all(artifact_mask(idx_range)), ...
                'Artifact spike region was not detected.');
        end

    end
end
