function aligned_data = align_to_events(data, fs, event_times, target_event)
% ALIGN_TO_EVENTS Realign continuous data to a different event type.
%
%   aligned_data = align_to_events(data, fs, event_times, target_event)
%
%   Inputs:
%       data         - channels x time matrix
%       fs           - sampling rate (Hz)
%       event_times  - struct array with fields: type, timestamp
%       target_event - string specifying the target event type
%
%   Outputs:
%       aligned_data - struct with event_timestamps and aligned indices

    if ~ischar(target_event) && ~isstring(target_event)
        error('align_to_events:invalidInput', 'target_event must be a string.');
    end

    target_timestamps = [];
    for i = 1:numel(event_times)
        if strcmp(event_times(i).type, target_event)
            target_timestamps = [target_timestamps, event_times(i).timestamp]; %#ok<AGROW>
        end
    end

    if isempty(target_timestamps)
        error('align_to_events:noEvents', 'No events of type "%s" found.', target_event);
    end

    aligned_data.event_type = target_event;
    aligned_data.timestamps = target_timestamps;
    aligned_data.sample_indices = round(target_timestamps * fs) + 1;
    aligned_data.n_events = numel(target_timestamps);
end
