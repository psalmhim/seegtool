function m = load_task_metrics(run_output)
% LOAD_TASK_METRICS Load discrimination metrics from stage files.
%
%   m = load_task_metrics(run_output)
%
%   Loads separation, decoding, dynamics, and contrast results from
%   the stage MAT files on disk (not the in-memory summary struct).

    m = struct();
    m.peak_sep = NaN;
    m.min_p = NaN;
    m.is_sig = false;
    m.peak_acc = NaN;
    m.onset_ms = NaN;
    m.eff_dim = NaN;
    m.jpca_r2 = NaN;
    m.n_sig_contrasts = 0;
    m.n_total_contrasts = 0;
    m.n_tf_clusters = 0;
    m.tf_mvpa_acc = NaN;
    m.separation = [];
    m.decoding = [];

    results_dir = fullfile(run_output, 'results');
    if ~isfolder(results_dir); return; end

    % Stage 12: geometry (condition separation)
    f = fullfile(results_dir, 'stage12_geometry.mat');
    if isfile(f)
        s = load(f);
        % Stage 12 saves: separation.index, separation.p_values, separation.time_vec
        if isfield(s, 'separation') && isstruct(s.separation)
            sep = s.separation;
            if isfield(sep, 'index')
                m.peak_sep = max(sep.index);
            end
            if isfield(sep, 'p_values')
                m.min_p = min(sep.p_values);
                m.is_sig = m.min_p < 0.05;
            end
            if isfield(sep, 'index') && isfield(sep, 'p_values')
                m.separation = struct('index', sep.index, 'p_values', sep.p_values);
                if isfield(sep, 'time_vec')
                    m.separation.time_vec = sep.time_vec;
                end
            end
        end
    end

    % Stage 14: decoding
    % Stage 14 saves: decoding.accuracy_time, decoding.onset_time, etc.
    f = fullfile(results_dir, 'stage14_decoding.mat');
    if isfile(f)
        s = load(f);
        dec = struct();
        if isfield(s, 'decoding') && isstruct(s.decoding)
            dec = s.decoding;
        else
            dec = s;  % fallback: fields at top level
        end
        if isfield(dec, 'accuracy_time')
            m.peak_acc = max(dec.accuracy_time);
            m.decoding = struct('accuracy_time', dec.accuracy_time);
        end
        if isfield(dec, 'onset_time') && ~isnan(dec.onset_time)
            m.onset_ms = dec.onset_time * 1000;
            if ~isempty(m.decoding)
                m.decoding.onset_time = dec.onset_time;
            end
        end
    end

    % Stage 13: dynamics
    % Stage 13 saves: dynamics.state_space.effective_dimensionality, dynamics.jpca.R2
    f = fullfile(results_dir, 'stage13_dynamics.mat');
    if isfile(f)
        s = load(f);
        dyn = struct();
        if isfield(s, 'dynamics') && isstruct(s.dynamics)
            dyn = s.dynamics;
        else
            dyn = s;  % fallback
        end
        if isfield(dyn, 'state_space') && isfield(dyn.state_space, 'effective_dimensionality')
            m.eff_dim = dyn.state_space.effective_dimensionality;
        elseif isfield(dyn, 'occupancy') && isfield(dyn.occupancy, 'effective_dim')
            m.eff_dim = dyn.occupancy.effective_dim;  % legacy fallback
        end
        if isfield(dyn, 'jpca') && isfield(dyn.jpca, 'R2')
            m.jpca_r2 = dyn.jpca.R2;
        end
    end

    % Stage 14b: contrasts
    f = fullfile(results_dir, 'stage14b_contrasts.mat');
    if isfile(f)
        s = load(f);
        if isfield(s, 'contrast_results') && ~isempty(s.contrast_results)
            m.n_total_contrasts = numel(s.contrast_results);
            for ci = 1:m.n_total_contrasts
                if isfield(s.contrast_results(ci), 'significant') && s.contrast_results(ci).significant
                    m.n_sig_contrasts = m.n_sig_contrasts + 1;
                end
            end
        end
    end

    % Stage 9b: TF multivariate stats
    f = fullfile(results_dir, 'stage09b_tf_stats.mat');
    if isfile(f)
        s = load(f, 'tf_stats');
        if isfield(s, 'tf_stats')
            if isfield(s.tf_stats, 'n_sig_clusters_total')
                m.n_tf_clusters = s.tf_stats.n_sig_clusters_total;
            end
            if isfield(s.tf_stats, 'mvpa') && isfield(s.tf_stats.mvpa, 'peak_accuracy')
                m.tf_mvpa_acc = s.tf_stats.mvpa.peak_accuracy;
            end
        end
    end
end
