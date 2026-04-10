function fig = plot_erp(erp, time_vec, channel_labels, varargin)
% PLOT_ERP Publication-quality ERP waveforms with condition overlays.
%
%   fig = plot_erp(erp, time_vec, channel_labels)
%   fig = plot_erp(erp, time_vec, channel_labels, 'sem', sem, ...)
%
%   Inputs:
%       erp            - channels x time (single condition) or
%                        struct with condition fields (multi-condition)
%       time_vec       - time vector in seconds
%       channel_labels - cell array of channel names
%       Name-Value:
%           'sem'      - SEM: channels x time or struct matching erp
%           'channels' - indices of channels to plot (default: first 6)
%           'title'    - figure title
%           'stats'    - struct with .p_values, .sig_mask for significance
%           'style'    - style struct (default: nature_style)
%           'width'    - 'single' or 'double' column

    s = get_style(varargin);
    p = inputParser;
    addParameter(p, 'sem', []);
    addParameter(p, 'channels', []);
    addParameter(p, 'title', '');
    addParameter(p, 'stats', []);
    addParameter(p, 'style', s);
    addParameter(p, 'width', 'double');
    parse(p, varargin{:});
    s = p.Results.style;

    % Determine if multi-condition
    if isstruct(erp) && ~isfield(erp, 'data')
        is_multi = true;
        cond_names = fieldnames(erp);
        n_conds = numel(cond_names);
        sample_erp = erp.(cond_names{1});
    else
        is_multi = false;
        sample_erp = erp;
        n_conds = 1;
    end

    n_ch_total = size(sample_erp, 1);
    if isempty(p.Results.channels)
        ch_idx = 1:min(6, n_ch_total);
    else
        ch_idx = p.Results.channels;
    end
    n_ch = numel(ch_idx);

    colors = nature_colors(n_conds);

    % Figure sizing
    if strcmp(p.Results.width, 'double')
        fw = s.figure.double_col;
    else
        fw = s.figure.single_col;
    end
    fh = min(0.8 * n_ch + 0.6, s.figure.max_height);

    fig = figure('Name', 'ERP', 'Units', 'inches', ...
        'Position', [1, 1, fw, fh], 'Color', s.figure.background);

    for i = 1:n_ch
        ax = subplot(n_ch, 1, i);
        hold(ax, 'on');
        ch = ch_idx(i);

        % Significance shading (condition difference)
        if ~isempty(p.Results.stats) && isfield(p.Results.stats, 'sig_mask')
            if size(p.Results.stats.sig_mask, 1) >= ch
                add_significance_shading(ax, time_vec, p.Results.stats.sig_mask(ch, :), s);
            elseif size(p.Results.stats.sig_mask, 1) == 1
                add_significance_shading(ax, time_vec, p.Results.stats.sig_mask, s);
            end
        end

        % Baseline shading
        bl_mask = time_vec < 0;
        if any(bl_mask)
            yl_tmp = [-1 1];
            fill(ax, [time_vec(1), 0, 0, time_vec(1)], ...
                [yl_tmp(1) yl_tmp(1) yl_tmp(2) yl_tmp(2)], ...
                s.colors.baseline_bg, 'EdgeColor', 'none', 'FaceAlpha', 0.5);
        end

        if is_multi
            for c = 1:n_conds
                erp_c = erp.(cond_names{c});
                col = colors(c, :);

                % SEM ribbon
                if ~isempty(p.Results.sem) && isstruct(p.Results.sem)
                    sem_c = p.Results.sem.(cond_names{c});
                    fill(ax, [time_vec, fliplr(time_vec)], ...
                        [erp_c(ch,:)+sem_c(ch,:), fliplr(erp_c(ch,:)-sem_c(ch,:))], ...
                        col, 'EdgeColor', 'none', 'FaceAlpha', s.colors.sem_alpha);
                end

                plot(ax, time_vec, erp_c(ch, :), 'Color', col, 'LineWidth', s.line.mean);
            end
        else
            col = colors(1, :);
            if ~isempty(p.Results.sem)
                sem_data = p.Results.sem;
                fill(ax, [time_vec, fliplr(time_vec)], ...
                    [erp(ch,:)+sem_data(ch,:), fliplr(erp(ch,:)-sem_data(ch,:))], ...
                    col, 'EdgeColor', 'none', 'FaceAlpha', s.colors.sem_alpha);
            end
            plot(ax, time_vec, erp(ch, :), 'Color', col, 'LineWidth', s.line.mean);
        end

        % Reference lines
        xline(ax, 0, '--', 'Color', s.colors.gray, 'LineWidth', s.line.reference);
        yline(ax, 0, ':', 'Color', s.colors.light_gray, 'LineWidth', s.line.reference);

        % Labels
        ylabel(ax, '\muV');
        if numel(channel_labels) >= ch
            text(ax, time_vec(end), 0, ['  ' channel_labels{ch}], ...
                'FontSize', s.font.annotation, 'FontName', s.font.family, ...
                'VerticalAlignment', 'middle');
        end

        if i == n_ch
            xlabel(ax, 'Time (s)');
        else
            set(ax, 'XTickLabel', []);
        end

        xlim(ax, [time_vec(1), time_vec(end)]);
        apply_nature_style(ax, s);
    end

    % Legend on first subplot
    if is_multi
        ax1 = subplot(n_ch, 1, 1);
        legend(ax1, cond_names, 'Location', 'northeast');
    end

    if ~isempty(p.Results.title)
        sgtitle(p.Results.title, 'FontSize', s.font.sgtitle, ...
            'FontName', s.font.family);
    end
end

function s = get_style(args)
    idx = find(strcmp(args, 'style'));
    if ~isempty(idx) && idx < numel(args)
        s = args{idx + 1};
    else
        s = nature_style();
    end
end
