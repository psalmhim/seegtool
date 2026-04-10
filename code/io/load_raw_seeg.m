function [data, fs, channel_labels] = load_raw_seeg(filepath)
% LOAD_RAW_SEEG Load raw SEEG data from a .mat file.
%
%   [data, fs, channel_labels] = load_raw_seeg(filepath)
%
%   Inputs:
%       filepath - path to .mat file containing SEEG data
%
%   Outputs:
%       data           - channels x time matrix of raw signals
%       fs             - sampling rate in Hz
%       channel_labels - cell array of channel name strings
%
%   Expected .mat fields: data, fs, channel_labels

    if ~ischar(filepath) && ~isstring(filepath)
        error('load_raw_seeg:invalidInput', 'filepath must be a string.');
    end
    if ~isfile(filepath)
        error('load_raw_seeg:fileNotFound', 'File not found: %s', filepath);
    end

    loaded = load(filepath);

    if ~isfield(loaded, 'data')
        error('load_raw_seeg:missingField', 'File must contain a "data" variable.');
    end
    if ~isfield(loaded, 'fs')
        error('load_raw_seeg:missingField', 'File must contain an "fs" variable.');
    end
    if ~isfield(loaded, 'channel_labels')
        error('load_raw_seeg:missingField', 'File must contain a "channel_labels" variable.');
    end

    data = loaded.data;
    fs = loaded.fs;
    channel_labels = loaded.channel_labels;

    if ~isnumeric(data) || ~ismatrix(data)
        error('load_raw_seeg:invalidData', 'data must be a 2D numeric matrix.');
    end
    if ~isnumeric(fs) || ~isscalar(fs) || fs <= 0
        error('load_raw_seeg:invalidFs', 'fs must be a positive scalar.');
    end
    if ~iscell(channel_labels)
        error('load_raw_seeg:invalidLabels', 'channel_labels must be a cell array.');
    end
    if numel(channel_labels) ~= size(data, 1)
        error('load_raw_seeg:dimensionMismatch', ...
            'Number of channel labels (%d) must match rows in data (%d).', ...
            numel(channel_labels), size(data, 1));
    end
end
