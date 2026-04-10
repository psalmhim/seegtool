function generate_stage_report(run_output, format)
% GENERATE_STAGE_REPORT Create per-stage result report with figures.
%
%   generate_stage_report(run_output)
%   generate_stage_report(run_output, 'md')    % markdown (default)
%   generate_stage_report(run_output, 'tex')   % LaTeX
%
%   Reads each stage's .mat file and generates a report summarizing
%   key metrics and referencing generated figures.

    if nargin < 2, format = 'md'; end

    results_dir = fullfile(run_output, 'results');
    fig_dir = fullfile(run_output, 'figures', 'png');

    % Load summary info
    if isfile(fullfile(run_output, 'summary.mat'))
        summary = load(fullfile(run_output, 'summary.mat'));
    else
        summary = struct('task', 'unknown', 'timestamp', datestr(now));
    end

    switch lower(format)
        case 'md'
            report_file = fullfile(run_output, 'report.md');
            write_markdown_report(report_file, results_dir, fig_dir, summary);
        case {'tex', 'latex'}
            report_file = fullfile(run_output, 'report.tex');
            write_latex_report(report_file, results_dir, fig_dir, summary);
    end

    fprintf('[Report] Generated: %s\n', report_file);
end


function write_markdown_report(outfile, results_dir, fig_dir, summary)
    fid = fopen(outfile, 'w');
    sf = @(name) fullfile(results_dir, [name '.mat']);

    task_name = 'unknown';
    if isfield(summary, 'task'), task_name = summary.task; end
    ts = datestr(now);
    if isfield(summary, 'timestamp'), ts = summary.timestamp; end

    fprintf(fid, '# SEEGRING Pipeline Report\n\n');
    fprintf(fid, '**Task**: %s | **Generated**: %s\n\n', task_name, ts);
    fprintf(fid, '---\n\n');

    %% Stage 1: BIDS
    if isfile(sf('stage01_bids'))
        s = load(sf('stage01_bids'));
        fprintf(fid, '## Stage 1: BIDS Data Loading\n\n');
        fprintf(fid, '| Metric | Value |\n|--------|-------|\n');
        fprintf(fid, '| Sampling rate | %d Hz |\n', s.fs);
        fprintf(fid, '| Total channels (raw) | %d |\n', s.n_channels_raw);
        fprintf(fid, '| Good channels | %d |\n', s.n_channels_good);
        fprintf(fid, '| Bad channels | %d |\n', numel(s.bad_channels));
        fprintf(fid, '| Stimulus events | %d |\n', s.n_events_stim);
        fprintf(fid, '| Conditions | %s |\n', strjoin(s.conditions, ', '));
        if ~isempty(s.bad_channels)
            fprintf(fid, '| Bad channel labels | %s |\n', strjoin(s.bad_channels, ', '));
        end
        fprintf(fid, '\n');
    end

    %% Stage 2: Config
    if isfile(sf('stage02_config'))
        s = load(sf('stage02_config'));
        c = s.cfg;
        fprintf(fid, '## Stage 2: Configuration\n\n');
        fprintf(fid, '| Parameter | Value |\n|-----------|-------|\n');
        fprintf(fid, '| Epoch window | -%.1f to +%.1f s |\n', c.epoch_pre, c.epoch_post);
        fprintf(fid, '| Baseline | %.1f to %.1f s |\n', c.baseline_start, c.baseline_end);
        fprintf(fid, '| Highpass | %.1f Hz |\n', c.highpass_freq);
        fprintf(fid, '| Lowpass | %.0f Hz |\n', c.lowpass_freq);
        fprintf(fid, '| Re-reference | %s |\n', c.reref_method);
        fprintf(fid, '| Freq range | %.0f–%.0f Hz (%d freqs) |\n', c.freq_range(1), c.freq_range(2), c.num_freqs);
        fprintf(fid, '| Latent dims | %d (%s) |\n', c.n_latent_dims, c.latent_method);
        fprintf(fid, '| Permutations | %d |\n', c.n_permutations);
        fprintf(fid, '| Decode method | %s (%d folds) |\n', c.decode_method, c.n_cv_folds);
        fprintf(fid, '\n');
    end

    %% Stage 3: Preprocessing
    if isfile(sf('stage03_preproc'))
        s = load(sf('stage03_preproc'));
        fprintf(fid, '## Stage 3: Preprocessing\n\n');
        if isfield(s.preproc_info, 'artifact_fraction')
            fprintf(fid, '- Artifact fraction: %.2f%%\n', s.preproc_info.artifact_fraction * 100);
        end
        if isfield(s, 'channel_labels')
            fprintf(fid, '- Channels after preprocessing: %d\n', numel(s.channel_labels));
        end
        fprintf(fid, '\n');
    end

    %% Stage 4: Epochs
    if isfile(sf('stage04_epochs'))
        s = load(sf('stage04_epochs'), 'n_trials', 'n_channels', 'n_timepoints');
        fprintf(fid, '## Stage 4: Epoch Extraction\n\n');
        fprintf(fid, '| Metric | Value |\n|--------|-------|\n');
        fprintf(fid, '| Trials | %d |\n', s.n_trials);
        fprintf(fid, '| Channels | %d |\n', s.n_channels);
        fprintf(fid, '| Time points | %d |\n', s.n_timepoints);
        fprintf(fid, '\n');
    end

    %% Stage 5: QC
    if isfile(sf('stage05_qc'))
        s = load(sf('stage05_qc'));
        n_green = sum(strcmp(s.trial_labels, 'green'));
        n_yellow = sum(strcmp(s.trial_labels, 'yellow'));
        n_red = sum(strcmp(s.trial_labels, 'red'));
        fprintf(fid, '## Stage 5: Quality Control\n\n');
        fprintf(fid, '| Quality | Count | Percentage |\n|---------|-------|------------|\n');
        n_total = numel(s.trial_labels);
        fprintf(fid, '| Green (good) | %d | %.0f%% |\n', n_green, 100*n_green/n_total);
        fprintf(fid, '| Yellow (warn) | %d | %.0f%% |\n', n_yellow, 100*n_yellow/n_total);
        fprintf(fid, '| Red (bad) | %d | %.0f%% |\n', n_red, 100*n_red/n_total);
        fprintf(fid, '\n');
        % Condition distribution
        conds = unique(s.condition_labels, 'stable');
        fprintf(fid, '**Condition distribution**:\n\n');
        for i = 1:numel(conds)
            nc = sum(strcmp(s.condition_labels, conds{i}));
            fprintf(fid, '- %s: %d trials\n', conds{i}, nc);
        end
        fprintf(fid, '\n');
    end

    %% Stage 6: ERP
    if isfile(sf('stage06_erp'))
        fprintf(fid, '## Stage 6: ERP Analysis\n\n');
        insert_figure(fid, fig_dir, '*erp*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 7: Time-Frequency
    if isfile(sf('stage07_timefreq'))
        s = load(sf('stage07_timefreq'), 'freqs');
        fprintf(fid, '## Stage 7: Time-Frequency Analysis\n\n');
        fprintf(fid, '- Frequency range: %.1f – %.1f Hz (%d frequencies)\n', ...
            s.freqs(1), s.freqs(end), numel(s.freqs));
        fprintf(fid, '- Method: continuous CWT → epoch\n\n');
        insert_figure(fid, fig_dir, '*timefreq*', 'md');
        insert_figure(fid, fig_dir, '*tf_*', 'md');
        insert_figure(fid, fig_dir, '*hfa*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 8: Phase
    if isfile(sf('stage08_phase'))
        fprintf(fid, '## Stage 8: Phase Coherence (ITPC)\n\n');
        insert_figure(fid, fig_dir, '*itpc*', 'md');
        insert_figure(fid, fig_dir, '*phase*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 9: Statistics
    if isfile(sf('stage09_stats'))
        fprintf(fid, '## Stage 9: Statistical Inference\n\n');
        
        s9 = load(sf('stage09_stats'));
        if isfield(s9, 'stats')
            if isfile(sf('stage03_preproc'))
                s3 = load(sf('stage03_preproc'), 'channel_labels');
                ch_labels = s3.channel_labels;
            else
                ch_labels = arrayfun(@(x) sprintf('Ch%d', x), 1:numel(s9.stats.roi_p_values), 'UniformOutput', false);
            end

            sig_idx = find(s9.stats.roi_significant);
            if isempty(sig_idx)
                fprintf(fid, 'No statistically significant channels found (FDR corrected).\n\n');
            else
                fprintf(fid, '### Significant Channels (FDR corrected)\n\n');
                fprintf(fid, '| Channel | p-value (FDR) | Effect Size (d) | Onset Time (s) |\n');
                fprintf(fid, '|---------|---------------|-----------------|----------------|\n');
                
                % Sort by p-value
                [~, sort_idx] = sort(s9.stats.roi_p_fdr(sig_idx));
                sorted_sig_idx = sig_idx(sort_idx);
                
                for idx = sorted_sig_idx(:)'
                    fprintf(fid, '| %s | %.4f | %.2f | %.3f |\n', ...
                        ch_labels{idx}, s9.stats.roi_p_fdr(idx), ...
                        s9.stats.effect_sizes(idx), s9.stats.onset_times(idx));
                end
                fprintf(fid, '\n');
            end
        end

        insert_figure(fid, fig_dir, '*stats*', 'md');
        insert_figure(fid, fig_dir, '*perm*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 11: Latent
    if isfile(sf('stage11_latent'))
        s = load(sf('stage11_latent'), 'latent_model');
        fprintf(fid, '## Stage 10-11: Latent Dynamics (PCA)\n\n');
        ev = s.latent_model.explained_variance;
        fprintf(fid, '| PC | Explained Variance |\n|----|-------------------|\n');
        for i = 1:numel(ev)
            fprintf(fid, '| PC%d | %.1f%% |\n', i, ev(i)*100);
        end
        fprintf(fid, '| **Total** | **%.1f%%** |\n\n', sum(ev)*100);
        insert_figure(fid, fig_dir, '*latent*', 'md');
        insert_figure(fid, fig_dir, '*pca*', 'md');
        insert_figure(fid, fig_dir, '*trajectory*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 12: Geometry
    if isfile(sf('stage12_geometry'))
        s = load(sf('stage12_geometry'));
        fprintf(fid, '## Stage 12: Trajectory Geometry\n\n');
        if isfield(s, 'separation') && isfield(s.separation, 'peak_value')
            fprintf(fid, '- Peak separation index: %.3f\n', s.separation.peak_value);
        end
        if isfield(s, 'separation') && isfield(s.separation, 'p_value')
            fprintf(fid, '- Separation p-value: %.4f\n', s.separation.p_value);
        end
        insert_figure(fid, fig_dir, '*geom*', 'md');
        insert_figure(fid, fig_dir, '*separation*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 13: Dynamics
    if isfile(sf('stage13_dynamics'))
        s = load(sf('stage13_dynamics'));
        fprintf(fid, '## Stage 13: Dynamical Systems\n\n');
        if isfield(s.dynamics, 'jpca') && isfield(s.dynamics.jpca, 'r_squared')
            fprintf(fid, '- jPCA R²: %.3f\n', s.dynamics.jpca.r_squared);
        end
        if isfield(s.dynamics, 'tangent') && isfield(s.dynamics.tangent, 'mean_curvature')
            fprintf(fid, '- Mean curvature: %.4f\n', s.dynamics.tangent.mean_curvature);
        end
        insert_figure(fid, fig_dir, '*jpca*', 'md');
        insert_figure(fid, fig_dir, '*dynamics*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 14: Decoding
    if isfile(sf('stage14_decoding'))
        s = load(sf('stage14_decoding'));
        fprintf(fid, '## Stage 14: Neural Decoding\n\n');
        if isfield(s.decoding, 'accuracy_time')
            fprintf(fid, '- Peak accuracy: %.1f%%\n', max(s.decoding.accuracy_time)*100);
        end
        if isfield(s.decoding, 'onset_time') && ~isnan(s.decoding.onset_time)
            fprintf(fid, '- Decoding onset: %.0f ms\n', s.decoding.onset_time*1000);
        end
        insert_figure(fid, fig_dir, '*decoding*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 14b: Contrasts
    if isfile(sf('stage14b_contrasts'))
        s = load(sf('stage14b_contrasts'));
        fprintf(fid, '## Stage 14b: Contrast Analysis\n\n');
        if ~isempty(s.contrast_results)
            fprintf(fid, '| Contrast | Significant | p_min |\n|----------|-------------|-------|\n');
            for i = 1:numel(s.contrast_results)
                cr = s.contrast_results(i);
                sig_str = 'No';
                if cr.significant, sig_str = '**Yes**'; end
                fprintf(fid, '| %s | %s | %.4f |\n', cr.contrast.name, sig_str, cr.p_min);
            end
        end
        insert_figure(fid, fig_dir, '*contrast*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 15: Bootstrap
    if isfile(sf('stage15_bootstrap'))
        fprintf(fid, '## Stage 15: Bootstrap Uncertainty\n\n');
        insert_figure(fid, fig_dir, '*bootstrap*', 'md');
        insert_figure(fid, fig_dir, '*confidence*', 'md');
        fprintf(fid, '\n');
    end

    %% Stage 16: ROI
    if isfile(sf('stage16_roi'))
        s = load(sf('stage16_roi'));
        fprintf(fid, '## Stage 16: ROI Analysis\n\n');
        if ~isempty(s.roi_groups)
            fprintf(fid, '| ROI | Channels |\n|-----|----------|\n');
            for i = 1:numel(s.roi_groups)
                fprintf(fid, '| %s | %d |\n', s.roi_groups(i).name, s.roi_groups(i).n_channels);
            end
        end
        insert_figure(fid, fig_dir, '*roi*', 'md');
        fprintf(fid, '\n');
    end

    %% All figures
    fprintf(fid, '---\n\n## All Generated Figures\n\n');
    if isfolder(fig_dir)
        d = dir(fullfile(fig_dir, '*.png'));
        for i = 1:numel(d)
            rel_path = fullfile('figures', 'png', d(i).name);
            fprintf(fid, '### %s\n\n![%s](%s)\n\n', d(i).name, d(i).name, rel_path);
        end
    end

    fclose(fid);
end


function write_latex_report(outfile, results_dir, fig_dir, summary)
    fid = fopen(outfile, 'w');
    sf = @(name) fullfile(results_dir, [name '.mat']);

    task_name = 'unknown';
    if isfield(summary, 'task'), task_name = summary.task; end

    fprintf(fid, '\\documentclass[11pt]{article}\n');
    fprintf(fid, '\\usepackage[margin=1in]{geometry}\n');
    fprintf(fid, '\\usepackage{graphicx}\n');
    fprintf(fid, '\\usepackage{booktabs}\n');
    fprintf(fid, '\\usepackage{hyperref}\n');
    fprintf(fid, '\\usepackage{float}\n');
    fprintf(fid, '\\title{SEEGRING Pipeline Report: %s}\n', strrep(task_name, '_', '\\_'));
    fprintf(fid, '\\date{%s}\n', datestr(now, 'yyyy-mm-dd'));
    fprintf(fid, '\\begin{document}\n\\maketitle\n\n');

    %% Stage 1
    if isfile(sf('stage01_bids'))
        s = load(sf('stage01_bids'));
        fprintf(fid, '\\section{Stage 1: BIDS Data Loading}\n');
        fprintf(fid, '\\begin{tabular}{ll}\\toprule\n');
        fprintf(fid, 'Sampling rate & %d Hz \\\\\n', s.fs);
        fprintf(fid, 'Good channels & %d / %d \\\\\n', s.n_channels_good, s.n_channels_raw);
        fprintf(fid, 'Stimulus events & %d \\\\\n', s.n_events_stim);
        fprintf(fid, 'Conditions & %s \\\\\n', strjoin(s.conditions, ', '));
        fprintf(fid, '\\bottomrule\\end{tabular}\n\n');
    end

    %% Stage 4
    if isfile(sf('stage04_epochs'))
        s = load(sf('stage04_epochs'), 'n_trials', 'n_channels', 'n_timepoints');
        fprintf(fid, '\\section{Stage 4: Epoch Extraction}\n');
        fprintf(fid, '%d trials $\\times$ %d channels $\\times$ %d time points.\n\n', ...
            s.n_trials, s.n_channels, s.n_timepoints);
    end

    %% Stage 9
    if isfile(sf('stage09_stats'))
        fprintf(fid, '\\section{Stage 9: Statistical Inference}\n');
        
        s9 = load(sf('stage09_stats'));
        if isfield(s9, 'stats')
            if isfile(sf('stage03_preproc'))
                s3 = load(sf('stage03_preproc'), 'channel_labels');
                ch_labels = s3.channel_labels;
            else
                ch_labels = arrayfun(@(x) sprintf('Ch%d', x), 1:numel(s9.stats.roi_p_values), 'UniformOutput', false);
            end

            sig_idx = find(s9.stats.roi_significant);
            if isempty(sig_idx)
                fprintf(fid, 'No statistically significant channels found (FDR corrected).\\\\\n\n');
            else
                fprintf(fid, '\\subsection*{Significant Channels (FDR corrected)}\n');
                fprintf(fid, '\\begin{tabular}{lccc}\\toprule\n');
                fprintf(fid, 'Channel & $p$-value (FDR) & Effect Size ($d$) & Onset Time (s) \\\\ \\midrule\n');
                
                % Sort by p-value
                [~, sort_idx] = sort(s9.stats.roi_p_fdr(sig_idx));
                sorted_sig_idx = sig_idx(sort_idx);
                
                for idx = sorted_sig_idx(:)'
                    fprintf(fid, '%s & %.4f & %.2f & %.3f \\\\\n', ...
                        strrep(ch_labels{idx}, '_', '\\_'), s9.stats.roi_p_fdr(idx), ...
                        s9.stats.effect_sizes(idx), s9.stats.onset_times(idx));
                end
                fprintf(fid, '\\bottomrule\\end{tabular}\n\n');
            end
        end
    end

    %% Stage 11
    if isfile(sf('stage11_latent'))
        s = load(sf('stage11_latent'), 'latent_model');
        fprintf(fid, '\\section{Stage 11: Latent Dynamics}\n');
        ev = s.latent_model.explained_variance;
        fprintf(fid, '\\begin{tabular}{cc}\\toprule\nPC & Variance \\\\ \\midrule\n');
        for i = 1:numel(ev)
            fprintf(fid, 'PC%d & %.1f\\%% \\\\\n', i, ev(i)*100);
        end
        fprintf(fid, '\\midrule Total & %.1f\\%% \\\\\n', sum(ev)*100);
        fprintf(fid, '\\bottomrule\\end{tabular}\n\n');
    end

    %% Stage 14
    if isfile(sf('stage14_decoding'))
        s = load(sf('stage14_decoding'));
        fprintf(fid, '\\section{Stage 14: Neural Decoding}\n');
        if isfield(s.decoding, 'accuracy_time')
            fprintf(fid, 'Peak accuracy: %.1f\\%%\n\n', max(s.decoding.accuracy_time)*100);
        end
        if isfield(s.decoding, 'onset_time') && ~isnan(s.decoding.onset_time)
            fprintf(fid, 'Decoding onset: %.0f ms\n\n', s.decoding.onset_time*1000);
        end
    end

    %% Figures
    if isfolder(fig_dir)
        d = dir(fullfile(fig_dir, '*.png'));
        if ~isempty(d)
            fprintf(fid, '\\section{Figures}\n\n');
            for i = 1:numel(d)
                fig_path = fullfile(fig_dir, d(i).name);
                fprintf(fid, '\\begin{figure}[H]\n\\centering\n');
                fprintf(fid, '\\includegraphics[width=0.9\\textwidth]{%s}\n', strrep(fig_path, '\', '/'));
                fprintf(fid, '\\caption{%s}\n', strrep(d(i).name, '_', '\\_'));
                fprintf(fid, '\\end{figure}\n\n');
            end
        end
    end

    fprintf(fid, '\\end{document}\n');
    fclose(fid);
end


function insert_figure(fid, fig_dir, pattern, format)
% Insert matching figures into the report
    if ~isfolder(fig_dir), return; end
    d = dir(fullfile(fig_dir, [pattern '.png']));
    for i = 1:numel(d)
        rel_path = fullfile('figures', 'png', d(i).name);
        switch format
            case 'md'
                fprintf(fid, '![%s](%s)\n\n', strrep(d(i).name, '.png', ''), rel_path);
            case 'tex'
                fprintf(fid, '\\includegraphics[width=0.8\\textwidth]{%s}\n', rel_path);
        end
    end
end
