function fig_handles = generate_figures(results, cfg)
% GENERATE_FIGURES Main figure generation using Nature-quality style.
%
%   fig_handles = generate_figures(results, cfg)
%
%   Wrapper that calls generate_publication_figures for backward compatibility.

    fig_handles = {};
    s = nature_style();

    % ERP
    if isfield(results, 'erp') && isfield(results, 'time_vec')
        channel_labels = {};
        if isfield(results, 'channel_labels')
            channel_labels = results.channel_labels;
        end
        sem = [];
        if isfield(results, 'erp_sem')
            sem = results.erp_sem;
        end
        stats = [];
        if isfield(results, 'stats')
            stats = results.stats;
        end
        fig = plot_erp(results.erp, results.time_vec, channel_labels, ...
            'sem', sem, 'stats', stats, 'style', s);
        fig_handles{end+1} = fig;
    end

    % Time-frequency map
    if isfield(results, 'tf_power_norm') && isfield(results, 'freqs')
        tf_avg = squeeze(mean(mean(results.tf_power_norm, 1), 2));
        stats_tf = [];
        if isfield(results, 'stats') && isfield(results.stats, 'tf_sig_mask')
            stats_tf = struct('sig_mask', results.stats.tf_sig_mask);
        end
        fig = plot_time_frequency_map(tf_avg, results.time_vec, results.freqs, ...
            'stats', stats_tf, 'style', s);
        fig_handles{end+1} = fig;
    end

    % ITPC
    if isfield(results, 'itpc') && isfield(results, 'freqs')
        fig = plot_itpc(results.itpc, results.time_vec, results.freqs, 'style', s);
        fig_handles{end+1} = fig;
    end

    % Latent trajectories 2D
    if isfield(results, 'cond_trajectories')
        ve = [];
        if isfield(results, 'latent_model') && isfield(results.latent_model, 'explained_variance')
            ve = results.latent_model.explained_variance;
        end
        fig = plot_latent_trajectory_2d(results.cond_trajectories, [1, 2], ...
            'var_explained', ve, 'time_vec', results.time_vec, 'style', s);
        fig_handles{end+1} = fig;

        fig = plot_latent_trajectory_3d(results.cond_trajectories, [1, 2, 3], ...
            'var_explained', ve, 'style', s);
        fig_handles{end+1} = fig;
    end

    % Condition separation
    if isfield(results, 'separation')
        ci = [];
        if isfield(results.separation, 'ci'); ci = results.separation.ci; end
        fig = plot_condition_separation(results.separation.index, ...
            results.separation.p_values, results.separation.time_vec, ...
            'ci', ci, 'style', s);
        fig_handles{end+1} = fig;
    end

    % jPCA
    if isfield(results, 'jpca') || (isfield(results, 'dynamics') && isfield(results.dynamics, 'jpca'))
        jpca_data = results.jpca;
        if isfield(results, 'dynamics') && isfield(results.dynamics, 'jpca')
            jpca_data = results.dynamics.jpca;
        end
        fig = plot_jpca_plane(jpca_data, 'style', s);
        fig_handles{end+1} = fig;
    end

    % Decoding
    if isfield(results, 'decoding') && isfield(results.decoding, 'accuracy_time')
        d = results.decoding;
        onset = NaN;
        if isfield(d, 'onset_time'); onset = d.onset_time; end
        ci = [];
        if isfield(d, 'ci'); ci = d.ci; end
        fig = plot_decoding_curve(d.accuracy_time, d.p_values, d.time_vec, ...
            d.chance_level, 'onset_marker', onset, 'ci', ci, 'style', s);
        fig_handles{end+1} = fig;
    end

    % Manifold occupancy
    if isfield(results, 'occupancy') || (isfield(results, 'dynamics') && isfield(results.dynamics, 'occupancy'))
        occ = [];
        if isfield(results, 'occupancy'); occ = results.occupancy; end
        if isfield(results, 'dynamics') && isfield(results.dynamics, 'occupancy')
            occ = results.dynamics.occupancy;
        end
        if ~isempty(occ)
            fig = plot_manifold_occupancy(occ, 'style', s);
            fig_handles{end+1} = fig;
        end
    end

    fprintf('[Figures] Generated %d figures.\n', numel(fig_handles));
end
