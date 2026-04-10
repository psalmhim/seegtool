function [raw, events, electrodes, channels] = load_bids_dataset(bids_root, subject, session)
% LOAD_BIDS_DATASET Load a complete BIDS iEEG dataset for one subject.
%
%   [raw, events, electrodes, channels] = load_bids_dataset(bids_root, subject, session)
%
%   Inputs:
%       bids_root - path to BIDS root directory
%       subject   - subject identifier (e.g., '01')
%       session   - session identifier (e.g., '01'), optional
%
%   Outputs:
%       raw        - struct with .data, .fs, .label, .electrodes, .channels
%       events     - struct array with .onset, .duration, .condition, .type, .sample
%       electrodes - struct with .label, .x, .y, .z
%       channels   - struct with .name, .type, .status

    sub_dir = fullfile(bids_root, sprintf('sub-%s', subject));

    if nargin > 2 && ~isempty(session)
        sub_dir = fullfile(sub_dir, sprintf('ses-%s', session));
    end

    ieeg_dir = fullfile(sub_dir, 'ieeg');

    if ~isfolder(ieeg_dir)
        error('BIDS:NotFound', 'iEEG directory not found: %s', ieeg_dir);
    end

    %% Find and load recording file
    exts = {'*.edf', '*.vhdr', '*.set'};
    files = [];
    for i = 1:numel(exts)
        found = dir(fullfile(ieeg_dir, ['*_ieeg' exts{i}(2:end)]));
        if ~isempty(found)
            files = found;
            break;
        end
    end

    if isempty(files)
        files = dir(fullfile(ieeg_dir, '*ieeg.*'));
    end

    if isempty(files)
        error('BIDS:NotFound', 'No iEEG recording file found in %s', ieeg_dir);
    end

    datafile = fullfile(files(1).folder, files(1).name);
    fprintf('[BIDS] Loading recording: %s\n', files(1).name);
    raw = load_bids_ieeg_file(datafile);

    %% Load events
    events_file = dir(fullfile(ieeg_dir, '*_events.tsv'));
    if ~isempty(events_file)
        events = load_bids_events(fullfile(events_file(1).folder, events_file(1).name), raw.fs);
        fprintf('[BIDS] Loaded %d events\n', numel(events));
    else
        events = struct([]);
        warning('BIDS:NoEvents', 'No events.tsv found');
    end

    %% Load electrodes
    elec_file = dir(fullfile(ieeg_dir, '*_electrodes.tsv'));
    if isempty(elec_file)
        elec_file = dir(fullfile(sub_dir, '*_electrodes.tsv'));
    end
    if ~isempty(elec_file)
        electrodes = load_bids_electrodes(fullfile(elec_file(1).folder, elec_file(1).name));
        fprintf('[BIDS] Loaded %d electrodes\n', numel(electrodes.label));
    else
        electrodes = struct('label', {raw.label}, 'x', [], 'y', [], 'z', []);
        warning('BIDS:NoElectrodes', 'No electrodes.tsv found');
    end

    %% Load channels
    chan_file = dir(fullfile(ieeg_dir, '*_channels.tsv'));
    if ~isempty(chan_file)
        channels = load_bids_channels(fullfile(chan_file(1).folder, chan_file(1).name));
        fprintf('[BIDS] Loaded %d channels\n', numel(channels.name));
    else
        channels = struct('name', {raw.label}, 'type', {repmat({'SEEG'}, size(raw.label))}, ...
            'status', {repmat({'good'}, size(raw.label))});
        warning('BIDS:NoChannels', 'No channels.tsv found');
    end

    %% Attach metadata to raw struct
    raw.electrodes = electrodes;
    raw.channels = channels;

    fprintf('[BIDS] Dataset loaded: %d channels, %d samples, fs=%g Hz\n', ...
        size(raw.data, 1), size(raw.data, 2), raw.fs);
end
