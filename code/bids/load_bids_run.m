function [raw, events, electrodes, channels, meta] = load_bids_run(ieeg_dir, vhdr_file, varargin)
% LOAD_BIDS_RUN Load a single BIDS iEEG run with all associated sidecar files.
%
%   [raw, events, electrodes, channels, meta] = load_bids_run(ieeg_dir, vhdr_file)
%   [raw, events, electrodes, channels, meta] = load_bids_run(..., 'mni', true)
%
%   Inputs:
%       ieeg_dir  - path to ieeg/ directory
%       vhdr_file - filename (not full path) of the .vhdr file
%       Name-Value:
%           'mni'          - use MNI-space electrodes if available (default: true)
%           'filter_seeg'  - keep only SEEG channels (default: true)
%           'stim_only'    - keep only stimulus events (default: false)
%
%   Outputs:
%       raw        - struct with .data, .fs, .label
%       events     - struct array
%       electrodes - struct with .label, .x, .y, .z, .group, .hemisphere
%       channels   - struct from channels.tsv
%       meta       - struct with task name, session, run info, ieeg.json

    p = inputParser;
    addParameter(p, 'mni', true);
    addParameter(p, 'filter_seeg', true);
    addParameter(p, 'stim_only', false);
    parse(p, varargin{:});

    %% Parse BIDS filename components
    [~, base, ~] = fileparts(vhdr_file);
    base = strrep(base, '_ieeg', '');  % remove _ieeg suffix

    % Extract BIDS entities
    meta = parse_bids_filename(base);
    meta.vhdr_file = vhdr_file;
    meta.ieeg_dir = ieeg_dir;

    %% Load recording
    full_vhdr = fullfile(ieeg_dir, vhdr_file);
    fprintf('[BIDS] Loading: %s\n', vhdr_file);
    raw = load_bids_ieeg_file(full_vhdr);

    %% Load ieeg.json for metadata
    json_file = fullfile(ieeg_dir, [base '_ieeg.json']);
    if isfile(json_file)
        meta.ieeg_json = jsondecode(fileread(json_file));
        if isfield(meta.ieeg_json, 'SamplingFrequency')
            meta.fs = meta.ieeg_json.SamplingFrequency;
        end
        if isfield(meta.ieeg_json, 'PowerLineFrequency')
            meta.line_freq = meta.ieeg_json.PowerLineFrequency;
        end
    end

    %% Load channels.tsv (run-specific)
    chan_file = fullfile(ieeg_dir, [base '_channels.tsv']);
    if isfile(chan_file)
        channels = load_bids_channels(chan_file);
    else
        % fallback: search for any channels.tsv
        cf = dir(fullfile(ieeg_dir, '*_channels.tsv'));
        if ~isempty(cf)
            channels = load_bids_channels(fullfile(cf(1).folder, cf(1).name));
        else
            channels = struct('name', {raw.label}, ...
                'type', {repmat({'SEEG'}, size(raw.label))}, ...
                'status', {repmat({'good'}, size(raw.label))});
        end
    end

    %% Load events.tsv (run-specific)
    events_file = fullfile(ieeg_dir, [base '_events.tsv']);
    if isfile(events_file)
        events = load_bids_events(events_file, raw.fs);
        fprintf('[BIDS] Loaded %d events\n', numel(events));
    else
        events = struct([]);
        warning('BIDS:NoEvents', 'No events.tsv found for this run');
    end

    %% Load electrodes.tsv (session-level, prefer MNI)
    electrodes = [];
    if p.Results.mni
        mni_files = dir(fullfile(ieeg_dir, '*space-MNI*_electrodes.tsv'));
        if ~isempty(mni_files)
            electrodes = load_bids_electrodes(fullfile(mni_files(1).folder, mni_files(1).name));
            meta.coord_space = 'MNI152NLin2009cAsym';
            fprintf('[BIDS] Using MNI electrodes (%d)\n', numel(electrodes.label));
        end
    end
    if isempty(electrodes)
        ef = dir(fullfile(ieeg_dir, '*_electrodes.tsv'));
        % exclude MNI files
        ef = ef(~contains({ef.name}, 'space-'));
        if ~isempty(ef)
            electrodes = load_bids_electrodes(fullfile(ef(1).folder, ef(1).name));
            meta.coord_space = 'native';
        else
            electrodes = struct('label', {raw.label}, 'x', [], 'y', [], 'z', []);
            meta.coord_space = 'none';
        end
    end

    %% Filter to SEEG channels only
    if p.Results.filter_seeg && isfield(channels, 'type')
        seeg_mask = strcmpi(channels.type, 'SEEG') | strcmpi(channels.type, 'ECOG');
        if sum(seeg_mask) < numel(channels.type)
            n_removed = sum(~seeg_mask);
            removed_types = unique(channels.type(~seeg_mask));
            fprintf('[BIDS] Filtering: keeping %d SEEG channels, removing %d (%s)\n', ...
                sum(seeg_mask), n_removed, strjoin(removed_types, ', '));

            raw.data = raw.data(seeg_mask, :);
            raw.label = raw.label(seeg_mask);
            channels.name = channels.name(seeg_mask);
            channels.type = channels.type(seeg_mask);
            channels.status = channels.status(seeg_mask);
            if isfield(channels, 'status_description')
                channels.status_description = channels.status_description(seeg_mask);
            end
        end
    end

    %% Filter stimulus-only events
    if p.Results.stim_only && ~isempty(events)
        stim_mask = strcmp({events.condition}, 'stimulus');
        if any(stim_mask)
            events = events(stim_mask);
            fprintf('[BIDS] Filtered to %d stimulus events\n', numel(events));
        end
    end

    %% Attach metadata
    raw.electrodes = electrodes;
    raw.channels = channels;
    raw.fs_nominal = raw.fs;

    fprintf('[BIDS] Ready: %d channels, %d samples, fs=%g Hz, task=%s\n', ...
        size(raw.data, 1), size(raw.data, 2), raw.fs, meta.task);
end


function meta = parse_bids_filename(base)
% Parse BIDS entities from filename
    meta = struct();
    meta.base = base;

    % Extract sub-
    tok = regexp(base, 'sub-([^_]+)', 'tokens');
    if ~isempty(tok); meta.subject = tok{1}{1}; else; meta.subject = ''; end

    % Extract ses-
    tok = regexp(base, 'ses-([^_]+)', 'tokens');
    if ~isempty(tok); meta.session = tok{1}{1}; else; meta.session = ''; end

    % Extract task-
    tok = regexp(base, 'task-([^_]+)', 'tokens');
    if ~isempty(tok); meta.task = tok{1}{1}; else; meta.task = ''; end

    % Extract run-
    tok = regexp(base, 'run-([^_]+)', 'tokens');
    if ~isempty(tok); meta.run = tok{1}{1}; else; meta.run = '01'; end
end
