function generate_publication_figures(result, output_dir, cfg)
% GENERATE_PUBLICATION_FIGURES Create all publication-quality figures for a run.
%
%   generate_publication_figures(result, output_dir, cfg)
%
%   Generates individual figures with Nature-journal-quality formatting.
%   All multi-condition figures emphasize condition-dependent significant
%   changes with pink shading, contour overlays, and significance annotations.
%
%   Outputs saved as PDF (vector) + PNG (600 DPI) in separate directories.

    s = nature_style();

    fig_dir = fullfile(output_dir, 'figures');
    pdf_dir = fullfile(fig_dir, 'pdf');
    png_dir = fullfile(fig_dir, 'png');
    if ~isfolder(pdf_dir); mkdir(pdf_dir); end
    if ~isfolder(png_dir); mkdir(png_dir); end

    task = '';
    if isfield(result, 'task'); task = result.task; end

    n_conds = 0;
    if isfield(result, 'conditions'); n_conds = numel(result.conditions); end

    fprintf('[Pub] Generating figures for %s (%d conditions)...\n', task, n_conds);

    %% ---- ERP (multi-condition with significance) ----
    if isfield(result, 'erp') && isfield(result, 'time_vec')
        try
            stats_erp = [];
            if isfield(result, 'stats') && isfield(result.stats, 'sig_mask')
                stats_erp = result.stats;
            end
            fig = plot_erp(result.erp, result.time_vec, result.channel_labels, ...
                'sem', result.erp_sem, ...
                'channels', 1:min(8, size_first(result.erp)), ...
                'stats', stats_erp, ...
                'title', sprintf('ERP - %s', task), 'style', s);
            export_both(fig, 'erp', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] ERP failed: %s\n', ME.message);
        end
    end

    %% ---- Condition-specific ERP comparison (NEW) ----
    if isfield(result, 'erp') && isstruct(result.erp) && n_conds > 1
        try
            % Build per-condition ERP for the best channel
            erp_conds = result.erp;
            sem_conds = [];
            if isfield(result, 'erp_sem') && isstruct(result.erp_sem)
                sem_conds = result.erp_sem;
            end
            p_vals = [];
            if isfield(result, 'stats') && isfield(result.stats, 'p_values')
                p_vals = result.stats.p_values;
                if size(p_vals, 1) > 1
                    % Use the channel with most significance
                    [~, best_ch] = min(min(p_vals, [], 2));
                    p_vals = p_vals(best_ch, :);
                end
            end
            fig = plot_erp_conditions(erp_conds, result.time_vec, ...
                'sem', sem_conds, 'p_values', p_vals, ...
                'title', sprintf('Condition Comparison - %s', task), 'style', s);
            export_both(fig, 'erp_conditions', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] ERP conditions failed: %s\n', ME.message);
        end
    end

    %% ---- Time-Frequency Power (with significance contours) ----
    if isfield(result, 'tf_power_norm') && isfield(result, 'freqs')
        try
            tf_data = result.tf_power_norm;
            if isstruct(tf_data)
                conds = fieldnames(tf_data);
                for c = 1:numel(conds)
                    tmp = tf_data.(conds{c});
                    while ndims(tmp) > 2
                        tmp = squeeze(mean(tmp, 1, 'omitnan'));
                    end
                    tf_data.(conds{c}) = tmp;
                end
            else
                while ndims(tf_data) > 2
                    tf_data = squeeze(mean(tf_data, 1, 'omitnan'));
                end
            end

            stats_tf = [];
            if isfield(result, 'stats') && isfield(result.stats, 'tf_sig_mask')
                sig_mask = result.stats.tf_sig_mask;
                while ndims(sig_mask) > 2
                    sig_mask = squeeze(any(sig_mask, 1));
                end
                stats_tf = struct('sig_mask', sig_mask);
            end
            fig = plot_time_frequency_map(tf_data, result.time_vec, result.freqs, ...
                'title', sprintf('TF Power - %s', task), 'stats', stats_tf, 'style', s);
            export_both(fig, 'tf_power', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] TF power failed: %s\n', ME.message);
        end
    end

    %% ---- ITPC ----
    if isfield(result, 'itpc') && isfield(result, 'freqs')
        try
            itpc_data = result.itpc;
            if isstruct(itpc_data)
                conds = fieldnames(itpc_data);
                for c = 1:numel(conds)
                    tmp = itpc_data.(conds{c});
                    while ndims(tmp) > 2
                        tmp = squeeze(mean(tmp, 1, 'omitnan'));
                    end
                    itpc_data.(conds{c}) = tmp;
                end
            else
                while ndims(itpc_data) > 2
                    itpc_data = squeeze(mean(itpc_data, 1, 'omitnan'));
                end
            end
            
            fig = plot_itpc(itpc_data, result.time_vec, result.freqs, ...
                'title', sprintf('ITPC - %s', task), 'style', s);
            export_both(fig, 'itpc', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] ITPC failed: %s\n', ME.message);
        end
    end

    %% ---- Latent Trajectory 2D ----
    if isfield(result, 'cond_trajectories')
        try
            ve = [];
            if isfield(result, 'latent_model') && isfield(result.latent_model, 'explained_variance')
                ve = result.latent_model.explained_variance;
            end
            fig = plot_latent_trajectory_2d(result.cond_trajectories, [1 2], ...
                'var_explained', ve, 'time_vec', result.time_vec, ...
                'title', sprintf('Latent Trajectory - %s', task), 'style', s);
            export_both(fig, 'latent_2d', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Latent 2D failed: %s\n', ME.message);
        end
    end

    %% ---- Latent Trajectory 3D ----
    if isfield(result, 'cond_trajectories')
        try
            ve = [];
            if isfield(result, 'latent_model') && isfield(result.latent_model, 'explained_variance')
                ve = result.latent_model.explained_variance;
            end
            fig = plot_latent_trajectory_3d(result.cond_trajectories, [1 2 3], ...
                'var_explained', ve, ...
                'title', sprintf('3D Trajectory - %s', task), 'style', s);
            export_both(fig, 'latent_3d', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Latent 3D failed: %s\n', ME.message);
        end
    end

    %% ---- Condition Separation (KEY: significance emphasis) ----
    if isfield(result, 'separation')
        try
            sep = result.separation;
            ci = [];
            if isfield(sep, 'ci'); ci = sep.ci; end
            fig = plot_condition_separation(sep.index, sep.p_values, sep.time_vec, ...
                'ci', ci, ...
                'title', sprintf('Condition Separation - %s', task), 'style', s);
            export_both(fig, 'separation', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Separation failed: %s\n', ME.message);
        end
    end

    %% ---- jPCA ----
    if isfield(result, 'dynamics') && isfield(result.dynamics, 'jpca')
        try
            fig = plot_jpca_plane(result.dynamics.jpca, ...
                'title', sprintf('jPCA - %s', task), 'style', s, ...
                'condition_names', result.conditions);
            export_both(fig, 'jpca', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] jPCA failed: %s\n', ME.message);
        end
    end

    %% ---- Neural Decoding (significance emphasis) ----
    if isfield(result, 'decoding') && isfield(result.decoding, 'accuracy_time')
        try
            d = result.decoding;
            onset = NaN;
            if isfield(d, 'onset_time'); onset = d.onset_time; end
            ci = [];
            if isfield(d, 'ci'); ci = d.ci; end
            confusion = [];
            if isfield(d, 'confusion_matrix'); confusion = d.confusion_matrix; end
            fig = plot_decoding_curve(d.accuracy_time, d.p_values, d.time_vec, ...
                d.chance_level, 'onset_marker', onset, 'ci', ci, ...
                'confusion', confusion, ...
                'title', sprintf('Decoding - %s', task), 'style', s);
            export_both(fig, 'decoding', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Decoding failed: %s\n', ME.message);
        end
    end

    %% ---- Permutation Statistics Summary ----
    if isfield(result, 'stats') && ~isempty(fieldnames(result.stats))
        try
            ch_labels = {};
            if isfield(result, 'channel_labels')
                ch_labels = result.channel_labels;
            end
            fig = plot_permutation_summary(result.stats, result.time_vec, ...
                'channel_labels', ch_labels, ...
                'title', sprintf('Statistics - %s', task), 'style', s);
            export_both(fig, 'statistics', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Statistics failed: %s\n', ME.message);
        end
    end

    %% ---- Channel Significance Map ----
    if isfield(result, 'stats') && isfield(result.stats, 'ch_time_p')
        try
            dec_for_ch = struct();
            if isfield(result, 'decoding')
                dec_for_ch = result.decoding;
            end
            top_n = 20;
            if isfield(cfg, 'channel_sig_top_n')
                top_n = cfg.channel_sig_top_n;
            end
            regions = {};
            if isfield(result, 'roi_groups') && ~isempty(result.roi_groups)
                regions = build_channel_region_map(result.channel_labels, result.roi_groups);
            end
            fig = plot_channel_significance(result.stats, dec_for_ch, result.time_vec, ...
                'channel_labels', result.channel_labels, ...
                'top_n', top_n, ...
                'regions', regions, ...
                'title', sprintf('Channel Significance - %s', task), 'style', s);
            export_both(fig, 'channel_significance', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Channel significance failed: %s\n', ME.message);
        end
    end

    %% ---- ROI Trajectories ----
    if isfield(result, 'roi_results') && ~isempty(result.roi_results)
        try
            fig = plot_roi_trajectory_summary(result.roi_results, result.time_vec, ...
                'title', sprintf('ROI Trajectories - %s', task), 'style', s);
            export_both(fig, 'roi_trajectories', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] ROI failed: %s\n', ME.message);
        end
    end

    %% ---- Bootstrap Confidence Tubes ----
    if isfield(result, 'bootstrap') && isfield(result.bootstrap, 'mean_traj')
        try
            b = result.bootstrap;
            fig = plot_confidence_tubes(b.mean_traj, b.ci_lower, b.ci_upper, [1 2], ...
                result.time_vec, ...
                'title', sprintf('Confidence Tubes - %s', task), 'style', s);
            export_both(fig, 'confidence_tubes', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Confidence tubes failed: %s\n', ME.message);
        end
    end

    %% ---- Tangent Angles ----
    if isfield(result, 'geometry') && isfield(result.geometry, 'tangent_angles')
        try
            fig = plot_tangent_angles(result.geometry.tangent_angles, result.time_vec, ...
                'title', sprintf('Tangent Angles - %s', task), 'style', s);
            export_both(fig, 'tangent_angles', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Tangent angles failed: %s\n', ME.message);
        end
    end

    %% ---- Manifold Occupancy ----
    if isfield(result, 'dynamics') && isfield(result.dynamics, 'occupancy')
        try
            fig = plot_manifold_occupancy(result.dynamics.occupancy, ...
                'title', sprintf('Manifold Occupancy - %s', task), 'style', s);
            export_both(fig, 'manifold_occupancy', pdf_dir, png_dir, s);
        catch ME
            fprintf('[Pub] Occupancy failed: %s\n', ME.message);
        end
    end

    fprintf('[Pub] Figures saved to %s\n', fig_dir);
end


function export_both(fig, name, pdf_dir, png_dir, s)
% Export figure in both PDF and PNG formats.
    export_figure(fig, fullfile(pdf_dir, name), s, 'width', 'double');
    export_figure(fig, fullfile(png_dir, name), s, 'width', 'double', 'formats', {'png'});
    close(fig);
end


function n = size_first(x)
% Get first dimension size, handling struct or matrix.
    if isstruct(x)
        f = fieldnames(x);
        n = size(x.(f{1}), 1);
    else
        n = size(x, 1);
    end
end


function regions = build_channel_region_map(channel_labels, roi_groups)
% Map channel labels to region names from roi_groups struct array.
    regions = repmat({''}, numel(channel_labels), 1);
    if isempty(roi_groups); return; end
    for g = 1:numel(roi_groups)
        if ~isfield(roi_groups(g), 'channel_idx'); continue; end
        for ch = 1:numel(roi_groups(g).channel_idx)
            idx = roi_groups(g).channel_idx(ch);
            if idx <= numel(regions)
                regions{idx} = roi_groups(g).name;
            end
        end
    end
end
