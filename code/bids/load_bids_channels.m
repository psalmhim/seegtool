function channels = load_bids_channels(file)
% LOAD_BIDS_CHANNELS Load channel information from BIDS channels.tsv.
%
%   channels = load_bids_channels(file)
%
%   Output:
%       channels.name       - cell array of channel names
%       channels.type       - cell array of channel types (e.g., 'SEEG', 'ECOG')
%       channels.status     - cell array of status ('good' or 'bad')
%       channels.status_description - description of bad status (if available)
%       channels.sampling_frequency - per-channel fs (if available)

    T = readtable(file, 'FileType', 'text', 'Delimiter', '\t');

    channels.name = ensure_cell(T, 'name');
    channels.type = ensure_cell(T, 'type');

    if ismember('status', T.Properties.VariableNames)
        channels.status = ensure_cell(T, 'status');
    else
        channels.status = repmat({'good'}, height(T), 1);
    end

    if ismember('status_description', T.Properties.VariableNames)
        channels.status_description = ensure_cell(T, 'status_description');
    end

    if ismember('sampling_frequency', T.Properties.VariableNames)
        channels.sampling_frequency = T.sampling_frequency;
    end

    if ismember('group', T.Properties.VariableNames)
        channels.group = ensure_cell(T, 'group');
    end

    if ismember('units', T.Properties.VariableNames)
        channels.units = ensure_cell(T, 'units');
    end
end

function vals = ensure_cell(T, name)
    if ~ismember(name, T.Properties.VariableNames)
        vals = repmat({''}, height(T), 1);
        return;
    end
    vals = T.(name);
    if isstring(vals)
        vals = cellstr(vals);
    elseif isnumeric(vals)
        vals = arrayfun(@num2str, vals, 'UniformOutput', false);
    end
end
