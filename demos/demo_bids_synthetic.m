%% DEMO_BIDS_SYNTHETIC
% Creates a synthetic BIDS dataset and demonstrates the full BIDS loading
% and ROI analysis workflow without requiring real data.
%
% This demo:
%   1. Creates a temporary BIDS directory structure
%   2. Generates synthetic SEEG data with known properties
%   3. Loads using the BIDS loader
%   4. Runs ROI grouping and electrode parsing
%   5. Cleans up temporary files

%% Setup
fprintf('=== Synthetic BIDS Demo ===\n\n');

% Create temporary BIDS directory
tmp_root = fullfile(tempdir, 'seeg_bids_demo');
ieeg_dir = fullfile(tmp_root, 'sub-01', 'ses-01', 'ieeg');
if ~isfolder(ieeg_dir)
    mkdir(ieeg_dir);
end

%% Generate Synthetic Data

% Parameters
fs = 1000;
duration_sec = 60;
n_samples = fs * duration_sec;

% Define electrodes: 3 shafts, 4 contacts each
electrode_labels = {'LA1','LA2','LA3','LA4', ...
                    'RH1','RH2','RH3','RH4', ...
                    'LPF1','LPF2','LPF3','LPF4'};
n_ch = numel(electrode_labels);

% Generate synthetic signals
rng(42);
data = randn(n_ch, n_samples) * 50;  % background noise in uV

% Add oscillations per region
t = (0:n_samples-1) / fs;
% LA (left amygdala): theta oscillation
for i = 1:4
    data(i, :) = data(i, :) + 30 * sin(2*pi*6*t + randn*pi);
end
% RH (right hippocampus): theta + gamma
for i = 5:8
    data(i, :) = data(i, :) + 40 * sin(2*pi*5*t) + 10 * sin(2*pi*80*t);
end
% LPF (left prefrontal): beta
for i = 9:12
    data(i, :) = data(i, :) + 25 * sin(2*pi*20*t);
end

%% Write BIDS Files

% --- electrodes.tsv ---
coords = [
    -25, -5, -20;  -24, -4, -18;  -23, -3, -16;  -22, -2, -14;  % LA
     28, -15, -12;  27, -14, -10;  26, -13, -8;   25, -12, -6;   % RH
    -35, 40, 10;   -34, 38, 12;   -33, 36, 14;   -32, 34, 16     % LPF
];

fid = fopen(fullfile(ieeg_dir, 'sub-01_ses-01_electrodes.tsv'), 'w');
fprintf(fid, 'name\tx\ty\tz\n');
for i = 1:n_ch
    fprintf(fid, '%s\t%.1f\t%.1f\t%.1f\n', electrode_labels{i}, ...
        coords(i,1), coords(i,2), coords(i,3));
end
fclose(fid);

% --- channels.tsv ---
fid = fopen(fullfile(ieeg_dir, 'sub-01_ses-01_channels.tsv'), 'w');
fprintf(fid, 'name\ttype\tstatus\n');
for i = 1:n_ch
    status = 'good';
    if i == 4  % Mark LA4 as bad for demo
        status = 'bad';
    end
    fprintf(fid, '%s\tSEEG\t%s\n', electrode_labels{i}, status);
end
fclose(fid);

% --- events.tsv ---
n_events = 20;
event_onsets = sort(rand(1, n_events) * (duration_sec - 5) + 1);
conditions = repmat({'stim_A', 'stim_B'}, 1, n_events/2);
conditions = conditions(1:n_events);

fid = fopen(fullfile(ieeg_dir, 'sub-01_ses-01_events.tsv'), 'w');
fprintf(fid, 'onset\tduration\ttrial_type\n');
for i = 1:n_events
    fprintf(fid, '%.3f\t0.5\t%s\n', event_onsets(i), conditions{i});
end
fclose(fid);

% --- Save EDF (using simple .mat as fallback since edfwrite may not exist) ---
% We create a minimal .mat file simulating the data
save_file = fullfile(ieeg_dir, 'sub-01_ses-01_task-demo_ieeg.mat');
ieeg_data = data;
ieeg_fs = fs;
ieeg_labels = electrode_labels;
save(save_file, 'ieeg_data', 'ieeg_fs', 'ieeg_labels');

fprintf('Created synthetic BIDS dataset at:\n  %s\n\n', tmp_root);

%% Load with BIDS Loader (manual since .mat isn't auto-detected)

fprintf('--- Loading electrodes ---\n');
electrodes = load_bids_electrodes(fullfile(ieeg_dir, 'sub-01_ses-01_electrodes.tsv'));

fprintf('--- Loading channels ---\n');
channels = load_bids_channels(fullfile(ieeg_dir, 'sub-01_ses-01_channels.tsv'));

fprintf('--- Loading events ---\n');
events = load_bids_events(fullfile(ieeg_dir, 'sub-01_ses-01_events.tsv'), fs);

% Build raw struct manually for .mat
raw.data = data;
raw.fs = fs;
raw.label = electrode_labels;
raw.electrodes = electrodes;
raw.channels = channels;

%% Apply Channel Status
fprintf('\n--- Applying channel status ---\n');
[clean_data, good_idx, bad_labels] = apply_bids_channel_status(raw);
fprintf('Removed channels: %s\n', strjoin(bad_labels, ', '));

%% Electrode ROI Parsing
fprintf('\n--- Electrode ROI info ---\n');
roi_info = infer_electrode_roi_fields(electrodes);
for i = 1:numel(roi_info.unique_shafts)
    n = sum(roi_info.shaft_idx == i);
    fprintf('  Shaft %s: %d contacts, hemisphere %s\n', ...
        roi_info.unique_shafts{i}, n, ...
        roi_info.hemisphere{find(roi_info.shaft_idx == i, 1)});
end

%% Build ROI Groups
fprintf('\n--- ROI Groups ---\n');
roi_groups = build_roi_groups(electrodes, 'shaft');
for g = 1:numel(roi_groups)
    fprintf('  %s: channels %s\n', roi_groups(g).name, ...
        strjoin(roi_groups(g).labels, ', '));
end

%% Summary
fprintf('\n=== Synthetic BIDS Demo Complete ===\n');
fprintf('Electrodes: %d (good: %d)\n', n_ch, sum(good_idx));
fprintf('Events: %d\n', numel(events));
fprintf('ROI groups: %d\n', numel(roi_groups));
fprintf('Conditions: %s\n', strjoin(unique(conditions), ', '));

%% Cleanup
% rmdir(tmp_root, 's');  % Uncomment to remove temp files
fprintf('\nTemp files at: %s\n', tmp_root);
