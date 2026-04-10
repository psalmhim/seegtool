function caption = write_figure_caption(fig_type, result, task_name)
% WRITE_FIGURE_CAPTION Auto-generate descriptive figure captions emphasizing
% condition-dependent significance.
%
%   caption = write_figure_caption('erp', result, 'lexicaldecision')

    n_conds = 0;
    cond_str = '';
    if isfield(result, 'conditions')
        n_conds = numel(result.conditions);
        cond_str = strjoin(result.conditions, ', ');
    end

    has_sig = false;
    min_p = NaN;
    if isfield(result, 'separation') && isfield(result.separation, 'p_values')
        min_p = min(result.separation.p_values);
        has_sig = min_p < 0.05;
    end

    switch lower(fig_type)
        case 'erp'
            caption = sprintf(['Event-related potentials during %s task ', ...
                '(n = %d trials). '], task_name, result.n_trials);
            if n_conds > 1
                caption = [caption, sprintf('Condition-averaged waveforms (%s) ', cond_str)];
                caption = [caption, 'with SEM shading (ribbons). '];
                caption = [caption, 'Pink background marks time windows where ', ...
                    'condition-dependent ERP differences reach statistical significance ', ...
                    '(p < 0.05, cluster-based permutation test). '];
                if has_sig
                    caption = [caption, sprintf('Significant condition separation detected (p = %.4f).', min_p)];
                end
            else
                caption = [caption, 'Waveforms with SEM shading.'];
            end

        case 'tf_power'
            bl_method = 'dB';
            if isfield(result, 'config') && isfield(result.config, 'baseline_norm_method')
                bl_method = result.config.baseline_norm_method;
            end
            caption = sprintf(['Time-frequency power during %s task. ', ...
                'Morlet wavelet decomposition with %s baseline normalization. '], ...
                task_name, bl_method);
            if n_conds > 1
                caption = [caption, 'Black contours delineate time-frequency clusters with ', ...
                    'significant condition-dependent power differences ', ...
                    '(p < 0.05, cluster-based permutation test). '];
                caption = [caption, 'Horizontal dashed lines indicate canonical frequency band boundaries.'];
            else
                caption = [caption, 'Black contours: significant clusters (p < 0.05).'];
            end

        case 'itpc'
            caption = sprintf(['Inter-trial phase coherence during %s task. ', ...
                'Values range from 0 (random phase) to 1 (perfect phase-locking). '], ...
                task_name);
            if n_conds > 1
                caption = [caption, sprintf(['Computed separately for each condition (%s). ', ...
                    'Condition-dependent phase coherence differences reflect ', ...
                    'temporal precision of neural processing.'], cond_str)];
            end

        case 'latent_2d'
            ve_str = '';
            if isfield(result, 'latent_model') && isfield(result.latent_model, 'explained_variance')
                ve = result.latent_model.explained_variance;
                ve_str = sprintf(' Total variance: %.1f%%.', sum(ve)*100);
            end
            caption = sprintf(['Condition-averaged latent trajectories (PC1 vs PC2) ', ...
                'during %s task.%s '], task_name, ve_str);
            if n_conds > 1
                caption = [caption, sprintf(['Trajectories for %d conditions (%s) ', ...
                    'reveal condition-dependent population dynamics. '], n_conds, cond_str)];
                caption = [caption, 'Circles: stimulus onset; squares: epoch end. ', ...
                    'Color gradient indicates temporal progression. '];
                caption = [caption, 'Trajectory divergence between conditions reflects ', ...
                    'distinct neural state evolution.'];
            end

        case 'latent_3d'
            caption = sprintf(['Three-dimensional latent trajectories (PC1-3) ', ...
                'during %s task. '], task_name);
            if n_conds > 1
                caption = [caption, sprintf('Condition-dependent trajectories (%s) ', cond_str)];
                caption = [caption, 'with shadow projections on the XY plane. ', ...
                    'Spatial separation between trajectories indicates distinct neural state dynamics.'];
            end

        case 'separation'
            caption = sprintf(['Time-resolved condition separation during %s task. '], task_name);
            caption = [caption, '(a) Separation index quantifying distance between ', ...
                'condition centroids in latent space, with 95%% bootstrap CI. '];
            caption = [caption, 'Pink shading: statistically significant condition separation ', ...
                '(p < 0.05, permutation test). '];
            if isfield(result, 'separation') && isfield(result.separation, 'index')
                [pv, pi] = max(result.separation.index);
                pt = result.separation.time_vec(pi);
                caption = [caption, sprintf('Peak: %.2f at %.0f ms. ', pv, pt*1000)];
            end
            if has_sig
                caption = [caption, sprintf('Minimum p-value: %.4f. ', min_p)];
            end
            caption = [caption, '(b) Significance heatmap (-log10 p); ', ...
                'warmer colors indicate stronger evidence for condition differences.'];

        case 'decoding'
            caption = sprintf(['Time-resolved neural decoding during %s task. '], task_name);
            if n_conds > 1
                caption = [caption, sprintf('LDA classifier discriminating %d conditions (%s). ', ...
                    n_conds, cond_str)];
            end
            caption = [caption, 'Classification accuracy with bootstrap CI. ', ...
                'Dashed line: chance level. ', ...
                'Pink shading: above-chance decoding (p < 0.05, permutation-corrected). '];
            if isfield(result, 'decoding') && isfield(result.decoding, 'accuracy_time')
                pa = max(result.decoding.accuracy_time);
                caption = [caption, sprintf('Peak accuracy: %.1f%%. ', pa*100)];
                if isfield(result.decoding, 'onset_time') && ~isnan(result.decoding.onset_time)
                    caption = [caption, sprintf('Decoding onset: %.0f ms, ', ...
                        result.decoding.onset_time*1000)];
                    caption = [caption, 'indicating the earliest time at which ', ...
                        'condition-dependent information is reliably encoded.'];
                end
            end

        case 'jpca'
            caption = sprintf(['jPCA rotational dynamics during %s task. '], task_name);
            caption = [caption, 'Trajectories projected onto the first jPCA plane ', ...
                '(maximally rotational subspace). Arrows: temporal direction. '];
            if n_conds > 1
                caption = [caption, sprintf('Condition-specific trajectories (%s) ', cond_str)];
                caption = [caption, 'reveal condition-dependent rotational dynamics. '];
            end
            if isfield(result, 'dynamics') && isfield(result.dynamics, 'jpca')
                caption = [caption, sprintf('R^2 = %.3f.', result.dynamics.jpca.R2)];
            end

        case 'statistics'
            caption = sprintf(['Statistical evidence for condition-dependent effects ', ...
                'during %s task. '], task_name);
            caption = [caption, '(a) Null distribution from permutation test; red line: observed statistic. '];
            caption = [caption, '(b) Effect size (Cohen''s d) time course; ', ...
                'dashed lines: small (0.2), medium (0.5), large (0.8) effect benchmarks. '];
            caption = [caption, '(c) Channel-by-time significance map (-log10 p); ', ...
                'black contour: alpha = 0.05 threshold. '];
            if has_sig
                caption = [caption, sprintf('Significant condition effects confirmed (p = %.4f).', min_p)];
            end

        case 'roi_trajectories'
            caption = sprintf(['Region-of-interest latent trajectories during %s task. '], ...
                task_name);
            caption = [caption, 'Each panel shows condition-averaged trajectories ', ...
                'in the first two principal components of electrode shaft-grouped channels. '];
            if n_conds > 1
                caption = [caption, sprintf('Conditions: %s. ', cond_str)];
                caption = [caption, 'Trajectory divergence across ROIs indicates ', ...
                    'region-specific condition-dependent neural processing. '];
                caption = [caption, 'ROIs with greater trajectory separation encode ', ...
                    'condition-discriminative population activity.'];
            end

        case 'confidence_tubes'
            caption = sprintf(['Bootstrap confidence tubes for latent trajectories ', ...
                'during %s task. '], task_name);
            if n_conds >= 2
                caption = [caption, sprintf('95%% CI tubes for conditions (%s). ', cond_str)];
                caption = [caption, 'Non-overlapping tubes indicate statistically reliable ', ...
                    'condition-dependent trajectory divergence.'];
            end

        otherwise
            caption = sprintf('Analysis results for %s task.', task_name);
    end
end
