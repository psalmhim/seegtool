%% DEMO_ROI_LATENT_ANALYSIS
% Demonstrates ROI-based latent trajectory analysis using synthetic data.
%
% This demo:
%   1. Creates synthetic multi-region SEEG data with condition differences
%   2. Groups channels by electrode shaft (ROI)
%   3. Runs latent dynamics analysis per ROI
%   4. Visualizes ROI trajectory summaries

%% Setup
fprintf('=== ROI Latent Analysis Demo ===\n\n');

rng(123);

%% Generate Synthetic Trial Data
fs = 1000;
n_trials = 40;
n_channels = 12;
epoch_pre = 0.5;
epoch_post = 1.0;
n_time = round((epoch_pre + epoch_post) * fs);
time_vec = linspace(-epoch_pre, epoch_post, n_time);

% Electrode labels: 3 shafts x 4 contacts
labels = {'LA1','LA2','LA3','LA4', 'RH1','RH2','RH3','RH4', ...
          'LPF1','LPF2','LPF3','LPF4'};

% Build trial tensor: trials x channels x time
trial_tensor = randn(n_trials, n_channels, n_time) * 10;

% Add condition-specific signals
% Condition A: first 20 trials -- strong evoked response in LA and RH
% Condition B: last 20 trials -- weaker, different timing
for tr = 1:20
    % LA channels: early response
    for ch = 1:4
        resp = 50 * exp(-((time_vec - 0.1).^2) / (2*0.03^2));
        trial_tensor(tr, ch, :) = squeeze(trial_tensor(tr, ch, :))' + resp;
    end
    % RH channels: late response
    for ch = 5:8
        resp = 40 * exp(-((time_vec - 0.3).^2) / (2*0.05^2));
        trial_tensor(tr, ch, :) = squeeze(trial_tensor(tr, ch, :))' + resp;
    end
end
for tr = 21:40
    % LA channels: delayed, smaller
    for ch = 1:4
        resp = 30 * exp(-((time_vec - 0.2).^2) / (2*0.04^2));
        trial_tensor(tr, ch, :) = squeeze(trial_tensor(tr, ch, :))' + resp;
    end
    % RH channels: earlier, different shape
    for ch = 5:8
        resp = 35 * exp(-((time_vec - 0.15).^2) / (2*0.03^2));
        trial_tensor(tr, ch, :) = squeeze(trial_tensor(tr, ch, :))' + resp;
    end
end

%% Build Electrode and Event Structs
electrodes.label = labels';
electrodes.x = [-25;-24;-23;-22; 28;27;26;25; -35;-34;-33;-32];
electrodes.y = [-5;-4;-3;-2; -15;-14;-13;-12; 40;38;36;34];
electrodes.z = [-20;-18;-16;-14; -12;-10;-8;-6; 10;12;14;16];

events = struct();
for i = 1:n_trials
    events(i).condition = 'condA';
    events(i).timestamp = (i-1) * 2;
    events(i).onset = (i-1) * 2;
    events(i).type = 'stim';
end
for i = 21:n_trials
    events(i).condition = 'condB';
end

%% Build ROI Groups
fprintf('--- Building ROI groups ---\n');
roi_groups = build_roi_groups(electrodes, 'shaft');

%% Configure and Run ROI Latent Analysis
cfg = default_config();
cfg.fs = fs;
cfg.n_latent_dims = 3;
cfg.latent_method = 'pca';
cfg.smooth_kernel_ms = 20;
cfg.channel_labels = labels;

fprintf('\n--- Running ROI latent analysis ---\n');
roi_results = run_roi_latent_analysis(trial_tensor, roi_groups, time_vec, events, cfg);

%% Display Results
fprintf('\n--- Results Summary ---\n');
for g = 1:numel(roi_results)
    r = roi_results(g);
    if ~r.skipped
        fprintf('  %s: %d channels, %.1f%% variance explained\n', ...
            r.name, r.n_channels, r.explained_var * 100);
        if isfield(r, 'geometry') && isfield(r.geometry, 'mean_speed')
            fprintf('    Mean trajectory speed: %.2f\n', mean(r.geometry.mean_speed));
        end
    else
        fprintf('  %s: skipped\n', r.name);
    end
end

%% Visualize
fprintf('\n--- Generating trajectory plots ---\n');
fig = plot_roi_trajectory_summary(roi_results, time_vec, ...
    'title', 'ROI Latent Trajectories (Synthetic Data)');

fprintf('\n=== Demo Complete ===\n');
