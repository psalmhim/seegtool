function events = load_bids_events(file, fs)
% LOAD_BIDS_EVENTS Load events from a BIDS events.tsv file.
%
%   events = load_bids_events(file, fs)
%
%   Inputs:
%       file - path to events.tsv
%       fs   - sampling rate (Hz) for computing sample indices
%
%   Output:
%       events - struct array with fields:
%           .onset     - event onset in seconds
%           .duration  - event duration in seconds
%           .condition - trial_type or 'event'
%           .type      - 'stim'
%           .sample    - sample index (onset * fs)
%           .timestamp - same as onset (for pipeline compatibility)

    if nargin < 2
        fs = 1;
    end

    T = readtable(file, 'FileType', 'text', 'Delimiter', '\t');

    n = height(T);
    if n == 0
        events = struct([]);
        return;
    end

    events = struct();
    for k = 1:n
        events(k).onset = T.onset(k);
        events(k).duration = T.duration(k);
        events(k).sample = round(T.onset(k) * fs) + 1;
        events(k).timestamp = T.onset(k);

        if ismember('trial_type', T.Properties.VariableNames)
            val = T.trial_type(k);
            if iscell(val)
                events(k).trial_type = val{1};
            else
                events(k).trial_type = char(val);
            end
        else
            events(k).trial_type = 'event';
        end

        % Set condition from trial_type initially (may be overridden by
        % TSV 'condition' column in extra_cols below, which is desired)
        events(k).condition = events(k).trial_type;

        events(k).type = 'stim';

        % Preserve all extra columns as fields for downstream enrichment
        extra_cols = setdiff(T.Properties.VariableNames, ...
            {'onset', 'duration', 'sample', 'trial_type', 'value'});
        for ci = 1:numel(extra_cols)
            col = extra_cols{ci};
            val = T.(col)(k);
            if iscell(val)
                events(k).(col) = val{1};
            elseif isnumeric(val) || islogical(val)
                events(k).(col) = val;
            elseif isstring(val)
                events(k).(col) = char(val);
            else
                events(k).(col) = val;
            end
        end
    end
end
