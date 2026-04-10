%% RUN_CHANNEL_SIGNIFICANCE - Re-run stages 9 & 14 with new channel significance features
%
% Loads existing stage files, re-computes:
%   - Stage 9: channel x time significance map (cluster-corrected)
%   - Stage 14: channel importance via PCA back-projection
% Then prints significant channels.

%% Setup
code_root = fileparts(mfilename('fullpath'));
addpath(fullfile(code_root, 'code'));
add_paths();

results_base = '/Volumes/OHDD/DATA/epilepsy/sub-EP01AN96M1047/ses-task05/ieeg/results/task-saliencepain_run-01';
results_dir = fullfile(results_base, 'results');

fprintf('=== Channel Significance Analysis ===\n');
fprintf('Start: %s\n\n', datestr(now));

%% Load existing stage files
fprintf('Loading existing stage files...\n');
s1 = load(fullfile(results_dir, 'stage01_bids.mat'));
s2 = load(fullfile(results_dir, 'stage02_config.mat'));
s3 = load(fullfile(results_dir, 'stage03_preproc.mat'));
s4 = load(fullfile(results_dir, 'stage04_epochs.mat'));
s5 = load(fullfile(results_dir, 'stage05_qc.mat'));
cfg = s2.cfg;

% Override old config with current defaults
cfg.n_permutations = 1000;
cfg.n_latent_dims = 10;
cfg.smooth_kernel_ms = 10;
cfg.channel_sig_top_n = 20;
fprintf('Config overrides: n_permutations=%d, n_latent_dims=%d\n', cfg.n_permutations, cfg.n_latent_dims);

%% Re-run Stage 11 with 10 dims (was 6)
fprintf('\n--- Stage 11: Latent dynamics (10 dims) ---\n');
tic;
pop_tensor = build_population_tensor(s4.trial_tensor, 'voltage');
pop_tensor = normalize_population_tensor(pop_tensor, 'zscore');
model = fit_latent_model(pop_tensor, cfg);
latent_tensor = project_to_latent_space(pop_tensor, model);
latent_tensor = smooth_latent_trajectories(latent_tensor, cfg.smooth_kernel_ms, s1.fs);
clear pop_tensor;
[~, cond_indices] = make_condition_labels(s1.stim_events, 1:s4.n_trials);
cond_trajectories = compute_condition_averaged_trajectories(latent_tensor, cond_indices);
s11 = struct();
s11.latent_model = model;
s11.cond_trajectories = cond_trajectories;
s11.cond_indices = cond_indices;
s11.latent_tensor = latent_tensor;
save(fullfile(results_dir, 'stage11_latent.mat'), '-struct', 's11', '-v7.3');
t11 = toc;
fprintf('[Stage 11] %d dims, %.1f%% variance, done in %.1f s\n', ...
    cfg.n_latent_dims, sum(model.explained_variance)*100, t11);

% Use resampled channel labels if available
if isfield(s3, 'channel_labels') && ~isempty(s3.channel_labels)
    channel_labels = s3.channel_labels;
else
    channel_labels = s1.channel_labels;
end

fprintf('Task: %s\n', s1.task);
fprintf('Trials: %d, Channels: %d, Time: %d\n', s4.n_trials, s4.n_channels, s4.n_timepoints);
fprintf('Conditions: %s\n', strjoin(unique(s5.condition_labels), ', '));

%% Stage 9: Re-run permutation statistics with channel x time map
fprintf('\n--- Stage 9: Permutation Statistics (with channel x time map) ---\n');
tic;
stats_results = run_permutation_statistics(s4.trial_tensor, s5.condition_labels, s4.time_vec, cfg);
t9 = toc;
fprintf('[Stage 9] Done in %.1f seconds\n', t9);

% Save
save(fullfile(results_dir, 'stage09_stats.mat'), 'stats_results', '-v7.3');
fprintf('[Stage 9] Saved.\n');

%% Stage 14: Re-run decoding with channel importance
fprintf('\n--- Stage 14: Neural Decoding (with channel importance) ---\n');
tic;
pca_model = [];
if isfield(s11, 'latent_model') && isfield(s11.latent_model, 'W')
    pca_model = s11.latent_model;
    fprintf('PCA model loaded: %d channels x %d dims\n', size(pca_model.W, 1), size(pca_model.W, 2));
end
pop_tensor = build_population_tensor(s4.trial_tensor, 'voltage');
pop_tensor = normalize_population_tensor(pop_tensor, 'zscore');
decoding = run_neural_decoding(s11.latent_tensor, s5.condition_labels, s4.time_vec, cfg, pca_model, pop_tensor);
t14 = toc;
fprintf('[Stage 14] Done in %.1f seconds\n', t14);

% Save
save(fullfile(results_dir, 'stage14_decoding.mat'), 'decoding', '-v7.3');
fprintf('[Stage 14] Saved.\n');

%% Print results
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('CHANNEL SIGNIFICANCE RESULTS\n');
fprintf('%s\n\n', repmat('=', 1, 70));

% 1) ROI-based (post-stim average) FDR-corrected
sig_idx = find(stats_results.roi_significant);
fprintf('--- ROI-based significance (FDR corrected) ---\n');
if isempty(sig_idx)
    fprintf('No channels significant at FDR alpha=%.2f\n', cfg.alpha_level);
else
    fprintf('%d significant channels (FDR alpha=%.2f):\n', numel(sig_idx), cfg.alpha_level);
    [~, si] = sort(stats_results.roi_p_fdr(sig_idx));
    for i = 1:numel(sig_idx)
        ch = sig_idx(si(i));
        fprintf('  %3d. %-15s  d=%.2f  p(FDR)=%.4f  onset=%.3fs\n', ...
            i, channel_labels{ch}, stats_results.effect_sizes(ch), ...
            stats_results.roi_p_fdr(ch), stats_results.onset_times(ch));
    end
end

% 2) Channel x time cluster-corrected
fprintf('\n--- Channel x time significance (cluster-corrected) ---\n');
if isfield(stats_results, 'ch_time_sig')
    n_sig_ch = sum(any(stats_results.ch_time_sig, 2));
    fprintf('%d channels with significant time clusters\n', n_sig_ch);

    % Top channels by number of significant time points
    [sorted_nsig, sorted_idx] = sort(stats_results.n_sig_timepoints, 'descend');
    n_show = min(20, sum(sorted_nsig > 0));
    if n_show > 0
        fprintf('\nTop %d channels by significant time points:\n', n_show);
        for i = 1:n_show
            ch = sorted_idx(i);
            onset_str = 'N/A';
            if ~isnan(stats_results.onset_per_channel(ch))
                onset_str = sprintf('%.0fms', stats_results.onset_per_channel(ch) * 1000);
            end
            fprintf('  %3d. %-15s  %4d sig pts  onset=%s  d=%.2f  p(FDR)=%.4f\n', ...
                i, channel_labels{ch}, sorted_nsig(i), onset_str, ...
                stats_results.effect_sizes(ch), stats_results.roi_p_fdr(ch));
        end
    end
else
    fprintf('Channel x time map not computed.\n');
end

% 3) Decoding channel importance
fprintf('\n--- Decoding channel importance ---\n');
if isfield(decoding, 'channel_importance')
    fprintf('Peak decoding accuracy: %.1f%%\n', max(decoding.accuracy_time) * 100);
    top_ch = decoding.channel_top;
    n_show = min(20, numel(top_ch));
    fprintf('\nTop %d channels by decoding weight:\n', n_show);
    for i = 1:n_show
        ch = top_ch(i);
        p_str = '';
        if isfield(decoding, 'channel_perm_importance')
            p_imp = decoding.channel_perm_importance(ch);
            p_str = sprintf('  perm_imp=%.3f', p_imp);
        end
        fprintf('  %3d. %-15s  weight=%.4f  rank=%d%s\n', ...
            i, channel_labels{ch}, decoding.channel_mean_weight(ch), ...
            decoding.channel_rank(ch), p_str);
    end
else
    fprintf('Channel importance not computed (PCA model unavailable).\n');
end

% 4) Combined evidence
fprintf('\n--- Combined evidence (stats + decoding) ---\n');
if isfield(stats_results, 'ch_time_sig') && isfield(decoding, 'channel_mean_weight')
    % Combine: channels significant in BOTH time-resolved stats AND top decoding
    has_sig_time = any(stats_results.ch_time_sig, 2);
    med_weight = median(decoding.channel_mean_weight);
    has_high_weight = decoding.channel_mean_weight > med_weight;
    combined = find(has_sig_time & has_high_weight);

    if isempty(combined)
        fprintf('No channels significant in both stats and decoding.\n');
        % Try relaxed: just significant time OR top weight
        fprintf('Relaxed: channels significant in stats OR top decoding weight:\n');
        relaxed = find(has_sig_time | has_high_weight);
        [~, ri] = sort(stats_results.n_sig_timepoints(relaxed) + ...
            decoding.channel_mean_weight(relaxed) / max(decoding.channel_mean_weight), 'descend');
        n_show = min(15, numel(relaxed));
        for i = 1:n_show
            ch = relaxed(ri(i));
            sig_str = '';
            if has_sig_time(ch); sig_str = ' [SIG]'; end
            dec_str = '';
            if has_high_weight(ch); dec_str = ' [DEC]'; end
            fprintf('  %-15s  d=%.2f  %d sig_pts  weight=%.4f%s%s\n', ...
                channel_labels{ch}, stats_results.effect_sizes(ch), ...
                stats_results.n_sig_timepoints(ch), decoding.channel_mean_weight(ch), ...
                sig_str, dec_str);
        end
    else
        fprintf('%d channels with convergent evidence:\n', numel(combined));
        % Sort by combined score
        scores = -log10(max(stats_results.roi_p_fdr(combined), 1e-10)) + ...
            decoding.channel_mean_weight(combined) / max(decoding.channel_mean_weight);
        [~, ci] = sort(scores, 'descend');
        for i = 1:numel(combined)
            ch = combined(ci(i));
            fprintf('  %3d. %-15s  d=%.2f  p(FDR)=%.4f  %d sig_pts  onset=%s  weight=%.4f\n', ...
                i, channel_labels{ch}, stats_results.effect_sizes(ch), ...
                stats_results.roi_p_fdr(ch), stats_results.n_sig_timepoints(ch), ...
                iff_str(stats_results.onset_per_channel(ch)), ...
                decoding.channel_mean_weight(ch));
        end
    end
end

%% Generate figure
fprintf('\n--- Generating channel significance figure ---\n');
s = nature_style();
fig = plot_channel_significance(stats_results, decoding, s4.time_vec, ...
    'channel_labels', channel_labels, 'top_n', 20, ...
    'title', 'Channel Significance - saliencepain', 'style', s);
fig_dir = fullfile(results_base, 'figures');
png_dir = fullfile(fig_dir, 'png');
pdf_dir = fullfile(fig_dir, 'pdf');
if ~isfolder(png_dir); mkdir(png_dir); end
if ~isfolder(pdf_dir); mkdir(pdf_dir); end
export_figure(fig, fullfile(png_dir, 'channel_significance'), s, 'width', 'double', 'formats', {'png'});
export_figure(fig, fullfile(pdf_dir, 'channel_significance'), s, 'width', 'double');
close(fig);
fprintf('Figure saved.\n');

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('Total time: %.1f minutes\n', (t11 + t9 + t14) / 60);
fprintf('Results saved to: %s\n', results_dir);
fprintf('%s\n', repmat('=', 1, 70));


function s = iff_str(onset)
    if isnan(onset)
        s = 'N/A';
    else
        s = sprintf('%.0fms', onset * 1000);
    end
end
