function fig = plot_erp_conditions(erp_conds, time_vec, varargin)
% PLOT_ERP_CONDITIONS Focused condition comparison ERP with difference waveform.
%
%   fig = plot_erp_conditions(erp_conds, time_vec)
%
%   Inputs:
%       erp_conds - struct with condition fields, each 1 x time
%       time_vec  - time vector in seconds
%       Name-Value:
%           'sem'      - struct matching erp_conds (SEM per condition)
%           'p_values' - 1 x time p-values from condition comparison
%           'channel'  - channel name string for title
%           'title'    - figure title
%           'style'    - style struct

    s = nature_style();
    p = inputParser;
    addParameter(p, 'sem', []);
    addParameter(p, 'p_values', []);
    addParameter(p, 'channel', '');
    addParameter(p, 'title', 'Condition ERP Comparison');
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    cond_names = fieldnames(erp_conds);
    n_conds = numel(cond_names);
    colors = nature_colors(n_conds);

    fig = figure('Name', 'ERP_Conds', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.single_col, 3.0], ...
        'Color', s.figure.background);

    % --- Panel a: Overlaid ERPs (70% height) ---
    ax1 = subplot(7, 1, 1:5);
    hold(ax1, 'on');

    % Significance shading
    if ~isempty(p.Results.p_values)
        sig_mask = p.Results.p_values < s.sig.alpha;
        add_significance_shading(ax1, time_vec, sig_mask, s);
    end

    for c = 1:n_conds
        col = colors(c, :);
        erp_c = erp_conds.(cond_names{c});

        % SEM ribbon
        if ~isempty(p.Results.sem) && isfield(p.Results.sem, cond_names{c})
            sem_c = p.Results.sem.(cond_names{c});
            fill(ax1, [time_vec, fliplr(time_vec)], ...
                [erp_c + sem_c, fliplr(erp_c - sem_c)], ...
                col, 'EdgeColor', 'none', 'FaceAlpha', s.colors.sem_alpha);
        end

        plot(ax1, time_vec, erp_c, 'Color', col, 'LineWidth', s.line.mean);
    end

    xline(ax1, 0, '--', 'Color', s.colors.black, 'LineWidth', s.line.reference);
    yline(ax1, 0, ':', 'Color', s.colors.light_gray, 'LineWidth', s.line.reference);
    ylabel(ax1, 'Amplitude (\muV)');
    legend(ax1, cond_names, 'Location', 'northeast');
    set(ax1, 'XTickLabel', []);
    xlim(ax1, [time_vec(1), time_vec(end)]);

    ttl = p.Results.title;
    if ~isempty(p.Results.channel)
        ttl = sprintf('%s (%s)', ttl, p.Results.channel);
    end
    title(ax1, ttl);
    apply_nature_style(ax1, s);
    add_panel_label(ax1, 'a', s);

    % --- Panel b: Difference waveform (30% height) ---
    ax2 = subplot(7, 1, 6:7);
    hold(ax2, 'on');

    if n_conds >= 2
        diff_wave = erp_conds.(cond_names{1}) - erp_conds.(cond_names{2});

        % Significance shading on difference
        if ~isempty(p.Results.p_values)
            add_significance_shading(ax2, time_vec, p.Results.p_values < s.sig.alpha, s);
        end

        % Difference CI if SEMs available
        if ~isempty(p.Results.sem)
            sem1 = p.Results.sem.(cond_names{1});
            sem2 = p.Results.sem.(cond_names{2});
            diff_sem = sqrt(sem1.^2 + sem2.^2);
            ci_scale = 1.96;
            fill(ax2, [time_vec, fliplr(time_vec)], ...
                [diff_wave + ci_scale*diff_sem, fliplr(diff_wave - ci_scale*diff_sem)], ...
                s.colors.gray, 'EdgeColor', 'none', 'FaceAlpha', 0.15);
        end

        plot(ax2, time_vec, diff_wave, 'Color', s.colors.black, ...
            'LineWidth', s.line.data);
        yline(ax2, 0, ':', 'Color', s.colors.light_gray, 'LineWidth', s.line.reference);
        xline(ax2, 0, '--', 'Color', s.colors.black, 'LineWidth', s.line.reference);
    end

    xlabel(ax2, 'Time (s)');
    ylabel(ax2, '\Delta\muV');
    xlim(ax2, [time_vec(1), time_vec(end)]);
    apply_nature_style(ax2, s);
    add_panel_label(ax2, 'b', s);
end
