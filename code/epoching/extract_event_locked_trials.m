function [trial_tensor, time_vec] = extract_event_locked_trials(data, fs, event_times, pre_time, post_time)
% EXTRACT_EVENT_LOCKED_TRIALS Extract event-locked epochs from continuous data.
%
%   [trial_tensor, time_vec] = extract_event_locked_trials(data, fs, event_times, pre_time, post_time)
%
%   Inputs:
%       data        - channels x time continuous signal
%       fs          - sampling rate (Hz)
%       event_times - vector of event timestamps in seconds
%       pre_time    - time before event in seconds (positive value)
%       post_time   - time after event in seconds (positive value)
%
%   Outputs:
%       trial_tensor - trials x channels x time_samples
%       time_vec     - time vector relative to event (seconds)

    if ~isnumeric(data) || ~ismatrix(data)
        error('extract_event_locked_trials:invalidData', 'data must be a 2D numeric matrix.');
    end

    n_channels = size(data, 1);
    n_total_samples = size(data, 2);

    pre_samples = round(pre_time * fs);
    post_samples = round(post_time * fs);
    epoch_length = pre_samples + post_samples + 1;

    time_vec = (-pre_samples:post_samples) / fs;

    % Filter valid events
    valid_events = [];
    for k = 1:numel(event_times)
        event_sample = round(event_times(k) * fs) + 1;
        start_sample = event_sample - pre_samples;
        end_sample = event_sample + post_samples;

        if start_sample >= 1 && end_sample <= n_total_samples
            valid_events = [valid_events, k]; %#ok<AGROW>
        end
    end

    n_trials = numel(valid_events);
    if n_trials == 0
        warning('extract_event_locked_trials:noValidTrials', 'No valid trials found.');
        trial_tensor = zeros(0, n_channels, epoch_length);
        return;
    end

    trial_tensor = zeros(n_trials, n_channels, epoch_length);

    for t = 1:n_trials
        event_sample = round(event_times(valid_events(t)) * fs) + 1;
        start_sample = event_sample - pre_samples;
        end_sample = event_sample + post_samples;
        trial_tensor(t, :, :) = data(:, start_sample:end_sample);
    end
end
