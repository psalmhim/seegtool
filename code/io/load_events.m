function events = load_events(filepath)
% LOAD_EVENTS Load event table from .mat or .csv file.
%
%   events = load_events(filepath)
%
%   Inputs:
%       filepath - path to .mat or .csv file
%
%   Outputs:
%       events - struct array with fields: type, timestamp, trial_id, condition

    if ~ischar(filepath) && ~isstring(filepath)
        error('load_events:invalidInput', 'filepath must be a string.');
    end
    if ~isfile(filepath)
        error('load_events:fileNotFound', 'File not found: %s', filepath);
    end

    [~, ~, ext] = fileparts(filepath);

    switch lower(ext)
        case '.mat'
            loaded = load(filepath);
            if isfield(loaded, 'events')
                events = loaded.events;
            else
                fn = fieldnames(loaded);
                events = loaded.(fn{1});
            end

        case '.csv'
            tbl = readtable(filepath);
            n_events = height(tbl);
            events = struct('type', cell(n_events, 1), ...
                            'timestamp', cell(n_events, 1), ...
                            'trial_id', cell(n_events, 1), ...
                            'condition', cell(n_events, 1));
            for i = 1:n_events
                if ismember('type', tbl.Properties.VariableNames)
                    events(i).type = tbl.type{i};
                end
                if ismember('timestamp', tbl.Properties.VariableNames)
                    events(i).timestamp = tbl.timestamp(i);
                end
                if ismember('trial_id', tbl.Properties.VariableNames)
                    events(i).trial_id = tbl.trial_id(i);
                end
                if ismember('condition', tbl.Properties.VariableNames)
                    events(i).condition = tbl.condition{i};
                end
            end

        otherwise
            error('load_events:unsupportedFormat', 'Unsupported file format: %s', ext);
    end

    required_fields = {'type', 'timestamp', 'trial_id', 'condition'};
    for i = 1:numel(required_fields)
        if ~isfield(events, required_fields{i})
            error('load_events:missingField', 'Events must have field: %s', required_fields{i});
        end
    end
end
