function electrodes = load_bids_electrodes(file)
% LOAD_BIDS_ELECTRODES Load electrode information from BIDS electrodes.tsv.
%
%   electrodes = load_bids_electrodes(file)
%
%   Output:
%       electrodes.label - cell array of electrode names
%       electrodes.x     - x coordinates (mm)
%       electrodes.y     - y coordinates (mm)
%       electrodes.z     - z coordinates (mm)
%       electrodes.size  - electrode size (if available)
%       electrodes.group - anatomical group (if available)

    T = readtable(file, 'FileType', 'text', 'Delimiter', '\t');

    if ismember('name', T.Properties.VariableNames)
        electrodes.label = T.name;
    elseif ismember('label', T.Properties.VariableNames)
        electrodes.label = T.label;
    else
        error('BIDS:MissingField', 'electrodes.tsv must have a name or label column');
    end

    if iscell(electrodes.label)
        % already cell
    elseif isstring(electrodes.label)
        electrodes.label = cellstr(electrodes.label);
    end

    electrodes.x = parse_coord(T, 'x');
    electrodes.y = parse_coord(T, 'y');
    electrodes.z = parse_coord(T, 'z');

    if ismember('size', T.Properties.VariableNames)
        electrodes.size = T.size;
    end

    if ismember('group', T.Properties.VariableNames)
        if iscell(T.group)
            electrodes.group = T.group;
        else
            electrodes.group = cellstr(T.group);
        end
    end
end

function vals = parse_coord(T, name)
    if ismember(name, T.Properties.VariableNames)
        vals = T.(name);
        if iscell(vals)
            vals = cellfun(@(x) str2double(x), vals);
        end
    else
        vals = nan(height(T), 1);
    end
end
