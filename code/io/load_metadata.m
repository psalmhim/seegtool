function metadata = load_metadata(filepath)
% LOAD_METADATA Load channel metadata from .mat or .csv file.
%
%   metadata = load_metadata(filepath)
%
%   Inputs:
%       filepath - path to .mat or .csv file
%
%   Outputs:
%       metadata - struct with fields: channel_labels, anatomical_labels,
%                  electrode_names, is_valid

    if ~ischar(filepath) && ~isstring(filepath)
        error('load_metadata:invalidInput', 'filepath must be a string.');
    end
    if ~isfile(filepath)
        error('load_metadata:fileNotFound', 'File not found: %s', filepath);
    end

    [~, ~, ext] = fileparts(filepath);

    switch lower(ext)
        case '.mat'
            loaded = load(filepath);
            if isfield(loaded, 'metadata')
                metadata = loaded.metadata;
            else
                metadata = loaded;
            end

        case '.csv'
            tbl = readtable(filepath);
            metadata.channel_labels = tbl.channel_labels;
            if ismember('anatomical_labels', tbl.Properties.VariableNames)
                metadata.anatomical_labels = tbl.anatomical_labels;
            else
                metadata.anatomical_labels = repmat({''}, height(tbl), 1);
            end
            if ismember('electrode_names', tbl.Properties.VariableNames)
                metadata.electrode_names = tbl.electrode_names;
            else
                metadata.electrode_names = repmat({''}, height(tbl), 1);
            end
            if ismember('is_valid', tbl.Properties.VariableNames)
                metadata.is_valid = logical(tbl.is_valid);
            else
                metadata.is_valid = true(height(tbl), 1);
            end

        otherwise
            error('load_metadata:unsupportedFormat', 'Unsupported file format: %s', ext);
    end
end
