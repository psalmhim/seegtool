%% DEMO_BIDS_LOADER_EXAMPLE
% Demonstrates loading a BIDS-format iEEG dataset and running the
% SEEG population dynamics pipeline.
%
% Before running:
%   1. Ensure your BIDS dataset is organized as:
%       bids_root/
%           sub-01/
%               ses-01/
%                   ieeg/
%                       sub-01_ses-01_task-xxx_ieeg.edf
%                       sub-01_ses-01_task-xxx_events.tsv
%                       sub-01_ses-01_task-xxx_electrodes.tsv
%                       sub-01_ses-01_task-xxx_channels.tsv
%   2. Run startup.m or add_paths() first.

%% Configuration
bids_root = '/data/seeg_bids';   % <-- Change to your BIDS root
subject   = '01';
session   = '01';                 % Leave empty if no sessions

%% Step 1: Load BIDS Dataset
fprintf('=== BIDS Loader Demo ===\n\n');

[raw, events, electrodes, channels] = load_bids_dataset(bids_root, subject, session);

fprintf('\nData summary:\n');
fprintf('  Channels: %d\n', size(raw.data, 1));
fprintf('  Samples:  %d\n', size(raw.data, 2));
fprintf('  Fs:       %g Hz\n', raw.fs);
fprintf('  Events:   %d\n', numel(events));
fprintf('  Duration: %.1f seconds\n\n', size(raw.data, 2) / raw.fs);

%% Step 2: Remove Bad Channels
[clean_data, good_idx, bad_labels] = apply_bids_channel_status(raw);
fprintf('Good channels: %d / %d\n', sum(good_idx), numel(good_idx));

%% Step 3: Parse Electrode Shaft Information
roi_info = infer_electrode_roi_fields(electrodes);
fprintf('\nElectrode shafts:\n');
for i = 1:numel(roi_info.unique_shafts)
    n = sum(roi_info.shaft_idx == i);
    fprintf('  %s: %d contacts\n', roi_info.unique_shafts{i}, n);
end

%% Step 4: Build ROI Groups
roi_groups = build_roi_groups(electrodes, 'shaft');

%% Step 5: Run Pipeline with BIDS Data
cfg = default_config();
cfg.fs = raw.fs;
cfg.channel_labels = raw.label(good_idx);

% Update raw struct with cleaned data
raw_clean = raw;
raw_clean.data = clean_data;
raw_clean.label = raw.label(good_idx);

fprintf('\n=== Running Pipeline ===\n');
results_dir = fullfile(bids_root, 'derivatives', 'seegring');
results = run_seeg_pipeline(subject, 'default', ...
    fullfile(bids_root, 'sourcedata'), results_dir);

fprintf('\n=== Demo Complete ===\n');

%% Step 6: ROI-based Latent Analysis (Optional)
% Uncomment below after running the full pipeline:
%
% trial_tensor = results.trial_tensor;  % if saved
% roi_results = run_roi_latent_analysis(trial_tensor, roi_groups, ...
%     results.time_vec, events, cfg);
% fig = plot_roi_trajectory_summary(roi_results, results.time_vec);
