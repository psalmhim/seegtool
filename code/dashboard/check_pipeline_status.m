function status = check_pipeline_status(results_dir, runs)
% CHECK_PIPELINE_STATUS Scan results directory and determine processing status.
%
%   status = check_pipeline_status(results_dir, runs)
%
%   Checks per-stage .mat files for each run to determine which stages
%   completed. Extracts key metrics from stage files without loading
%   large data tensors.

    n_runs = numel(runs);
    status = struct();

    % Stage file names and display names
    stage_files = {'stage01_bids', 'stage02_config', 'stage03_preproc', ...
        'stage04_epochs', 'stage05_qc', 'stage06_erp', 'stage07_timefreq', ...
        'stage08_phase', 'stage09_stats', 'stage11_latent', ...
        'stage12_geometry', 'stage13_dynamics', 'stage14_decoding', ...
        'stage14b_contrasts', 'stage15_bootstrap', 'stage16_roi'};

    stage_labels = {'bids_loaded', 'configured', 'preprocessed', ...
        'epoched', 'qc', 'erp', 'timefreq', 'phase', 'stats', 'latent', ...
        'geometry', 'dynamics', 'decoding', 'contrasts', 'uncertainty', 'roi'};

    for r = 1:n_runs
        ri = runs(r);
        run_id = sprintf('ses-%s_task-%s_run-%s', ri.session, ri.task, ri.run);
        run_dir = fullfile(results_dir, ri.session, ...
            sprintf('task-%s_run-%s', ri.task, ri.run));

        s = struct();
        s.run_id = run_id;
        s.task = ri.task;
        s.session = ri.session;
        s.run = ri.run;
        s.description = ri.description;
        s.run_dir = run_dir;

        % Check per-stage files
        st = struct();
        for j = 1:numel(stage_files)
            fpath = fullfile(run_dir, 'results', [stage_files{j} '.mat']);
            st.(stage_labels{j}) = isfile(fpath);
        end
        st.visualization = isfolder(fullfile(run_dir, 'figures'));
        s.stages = st;

        all_labels = [stage_labels, {'visualization'}];
        s.n_stages_complete = sum(cellfun(@(f) st.(f), all_labels));
        s.n_stages_total = numel(all_labels);

        % Check summary file for overall success
        summary_file = fullfile(run_dir, 'summary.mat');
        result_file = fullfile(run_dir, 'results.mat');
        s.has_results = isfile(summary_file) || isfile(result_file) || s.n_stages_complete > 0;

        if isfile(summary_file)
            sm = load(summary_file);
            s.success = isfield(sm, 'success') && sm.success;
            s.last_modified_str = sm.timestamp;
            info = dir(summary_file);
            s.last_modified = info.datenum;
        elseif isfile(result_file)
            info = dir(result_file);
            s.last_modified = info.datenum;
            s.last_modified_str = datestr(info.datenum, 'yyyy-mm-dd HH:MM:SS');
            try
                data = load(result_file, 'result');
                s.success = isfield(data.result, 'success') && data.result.success;
            catch
                s.success = false;
            end
        else
            s.success = false;
            s.last_modified = 0;
            s.last_modified_str = 'N/A';
        end

        % Compute total size of all stage files
        s.file_size_mb = 0;
        d = dir(fullfile(run_dir, 'results', 'stage*.mat'));
        for j = 1:numel(d)
            s.file_size_mb = s.file_size_mb + d(j).bytes / 1e6;
        end

        % Extract key metrics from stage files (lightweight loads)
        m = struct();
        m = load_metric(m, run_dir, 'stage01_bids', ...
            {'n_channels_good', 'conditions'}, {'n_channels', 'conditions'});
        m = load_metric(m, run_dir, 'stage04_epochs', ...
            {'n_trials'}, {'n_trials'});
        if isfield(m, 'conditions')
            m.n_conditions = numel(m.conditions);
        end

        % Separation metrics
        if isfile(fullfile(run_dir, 'results', 'stage12_geometry.mat'))
            try
                s12 = load(fullfile(run_dir, 'results', 'stage12_geometry.mat'), 'separation');
                sep = s12.separation;
                if isfield(sep, 'peak_value')
                    m.peak_separation = sep.peak_value;
                elseif isfield(sep, 'index') && ~isempty(sep.index)
                    m.peak_separation = max(sep.index);
                end
                if isfield(sep, 'p_value')
                    m.separation_p = sep.p_value;
                end
            catch
            end
        end

        % Decoding metrics
        if isfile(fullfile(run_dir, 'results', 'stage14_decoding.mat'))
            try
                s14 = load(fullfile(run_dir, 'results', 'stage14_decoding.mat'), 'decoding');
                dec = s14.decoding;
                if isfield(dec, 'accuracy_time') && ~isempty(dec.accuracy_time)
                    m.peak_decoding = max(dec.accuracy_time);
                end
                if isfield(dec, 'onset_time')
                    m.decoding_onset = dec.onset_time;
                end
            catch
            end
        end

        % Latent model
        if isfile(fullfile(run_dir, 'results', 'stage11_latent.mat'))
            try
                s11 = load(fullfile(run_dir, 'results', 'stage11_latent.mat'), 'latent_model');
                if isfield(s11.latent_model, 'explained_variance')
                    m.explained_var = sum(s11.latent_model.explained_variance);
                end
            catch
            end
        end

        % Dynamics
        if isfile(fullfile(run_dir, 'results', 'stage13_dynamics.mat'))
            try
                s13 = load(fullfile(run_dir, 'results', 'stage13_dynamics.mat'), 'dynamics');
                if isfield(s13.dynamics, 'jpca') && isfield(s13.dynamics.jpca, 'r_squared')
                    m.jpca_r2 = s13.dynamics.jpca.r_squared;
                end
            catch
            end
        end

        % Contrast results
        if isfile(fullfile(run_dir, 'results', 'stage14b_contrasts.mat'))
            try
                s14b = load(fullfile(run_dir, 'results', 'stage14b_contrasts.mat'), 'contrast_results');
                cr = s14b.contrast_results;
                if ~isempty(cr)
                    m.n_contrasts = numel(cr);
                    m.n_sig_contrasts = sum([cr.significant]);
                end
            catch
            end
        end

        s.metrics = m;
        s.figures = find_figures(run_dir);
        s.result_file = result_file;

        if r == 1
            status = s;
        else
            status(r) = s;
        end
    end
end


function m = load_metric(m, run_dir, stage_name, src_fields, dst_fields)
% Load specific fields from a stage file into metrics struct.
    fpath = fullfile(run_dir, 'results', [stage_name '.mat']);
    if ~isfile(fpath); return; end
    try
        s = load(fpath, src_fields{:});
        for i = 1:numel(src_fields)
            if isfield(s, src_fields{i})
                m.(dst_fields{i}) = s.(src_fields{i});
            end
        end
    catch
    end
end


function figs = find_figures(run_dir)
    figs = {};
    png_dir = fullfile(run_dir, 'figures', 'png');
    pdf_dir = fullfile(run_dir, 'figures', 'pdf');

    if isfolder(png_dir)
        d = dir(fullfile(png_dir, '*.png'));
        for i = 1:numel(d)
            figs{end+1} = fullfile(png_dir, d(i).name); %#ok<AGROW>
        end
    elseif isfolder(pdf_dir)
        d = dir(fullfile(pdf_dir, '*.pdf'));
        for i = 1:numel(d)
            figs{end+1} = fullfile(pdf_dir, d(i).name); %#ok<AGROW>
        end
    end
end
