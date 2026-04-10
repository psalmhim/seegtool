function raw = load_bids_ieeg_file(filename)
% LOAD_BIDS_IEEG_FILE Load iEEG recording from EDF, BrainVision, or EEGLAB format.
%
%   raw = load_bids_ieeg_file(filename)
%
%   Supports:
%       .edf  - European Data Format (uses MATLAB's edfread)
%       .vhdr - BrainVision (requires EEGLAB pop_loadbv)
%       .set  - EEGLAB (requires EEGLAB pop_loadset)
%
%   Output:
%       raw.data  - channels x samples
%       raw.fs    - sampling rate in Hz
%       raw.label - cell array of channel labels

    if ~isfile(filename)
        error('BIDS:FileNotFound', 'Recording file not found: %s', filename);
    end

    [filepath, ~, ext] = fileparts(filename);

    switch lower(ext)
        case '.edf'
            raw = load_edf(filename);

        case '.vhdr'
            raw = load_brainvision(filepath, filename);

        case '.set'
            raw = load_eeglab(filename);

        otherwise
            error('BIDS:UnsupportedFormat', 'Unsupported file format: %s', ext);
    end

    % Ensure label is a row cell array
    if iscolumn(raw.label)
        raw.label = raw.label';
    end
    if isstring(raw.label)
        raw.label = cellstr(raw.label);
    end
end

function raw = load_edf(filename)
    hdr = edfinfo(filename);
    data = edfread(filename);

    raw.data = table2array(data)';
    raw.fs = hdr.NumSamples(1) / seconds(hdr.DataRecordDuration);
    raw.label = cellstr(hdr.SignalLabels);
end

function raw = load_brainvision(filepath, filename)
    [~, fname, ~] = fileparts(filename);
    vhdr_name = [fname '.vhdr'];

    if exist('pop_loadbv', 'file')
        % Use EEGLAB BrainVision loader
        EEG = pop_loadbv(filepath, vhdr_name);
        raw.data = EEG.data;
        raw.fs = EEG.srate;
        raw.label = {EEG.chanlocs.labels};
    else
        % Fallback: parse vhdr header and read binary directly
        raw = read_brainvision_raw(filepath, vhdr_name);
    end
end

function raw = read_brainvision_raw(filepath, vhdr_name)
% Read BrainVision format without EEGLAB dependency.
    vhdr_path = fullfile(filepath, vhdr_name);
    txt = fileread(vhdr_path);
    lines = strsplit(txt, {'\r\n', '\n', '\r'});

    % Parse sampling interval (microseconds)
    si_line = lines(contains(lines, 'SamplingInterval'));
    si_us = sscanf(si_line{1}, 'SamplingInterval=%f');
    raw.fs = 1e6 / si_us;

    % Parse number of channels
    nch_line = lines(contains(lines, 'NumberOfChannels'));
    n_ch = sscanf(nch_line{1}, 'NumberOfChannels=%d');

    % Parse channel names
    raw.label = cell(1, n_ch);
    for i = 1:n_ch
        pattern = sprintf('Ch%d=', i);
        ch_line = lines(contains(lines, pattern));
        if ~isempty(ch_line)
            parts = strsplit(ch_line{1}, '=');
            name_parts = strsplit(parts{2}, ',');
            raw.label{i} = strtrim(name_parts{1});
        else
            raw.label{i} = sprintf('Ch%d', i);
        end
    end

    % Parse data file name
    df_line = lines(contains(lines, 'DataFile'));
    df_parts = strsplit(df_line{1}, '=');
    data_file = fullfile(filepath, strtrim(df_parts{2}));

    % Parse binary format
    if any(contains(lines, 'IEEE_FLOAT_32'))
        precision = 'float32';
        bytes_per_sample = 4;
    else
        precision = 'int16';
        bytes_per_sample = 2;
    end

    % Read binary data
    fid = fopen(data_file, 'rb');
    raw.data = fread(fid, [n_ch, Inf], precision);
    fclose(fid);

    % Apply resolution if int16
    if strcmp(precision, 'int16')
        % Parse resolution from channel info
        for i = 1:n_ch
            pattern = sprintf('Ch%d=', i);
            ch_line = lines(contains(lines, pattern));
            if ~isempty(ch_line)
                parts = strsplit(ch_line{1}, ',');
                if numel(parts) >= 3
                    res = str2double(strtrim(parts{3}));
                    if ~isnan(res) && res > 0
                        raw.data(i, :) = raw.data(i, :) * res;
                    end
                end
            end
        end
    end
end

function raw = load_eeglab(filename)
    EEG = pop_loadset(filename);

    raw.data = EEG.data;
    raw.fs = EEG.srate;
    raw.label = {EEG.chanlocs.labels};
end
