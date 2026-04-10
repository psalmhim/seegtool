function fig = plot_time_frequency_map(tf_power, time_vec, freqs, varargin)
% PLOT_TIME_FREQUENCY_MAP Publication-quality TF map with significance contours.
%
%   fig = plot_time_frequency_map(tf_power, time_vec, freqs)
%   fig = plot_time_frequency_map(tf_power, time_vec, freqs, 'stats', stats, ...)
%
%   Inputs:
%       tf_power - freqs x time (single) or struct with condition fields
%       time_vec - time vector in seconds
%       freqs    - frequency vector in Hz
%       Name-Value:
%           'clim'      - color limits [lo hi] (default: symmetric auto)
%           'title'     - figure title
%           'stats'     - struct with .sig_mask (freqs x time logical)
%           'diff_data' - condition difference map (freqs x time)
%           'diff_mask' - significance mask for difference
%           'style'     - style struct

    s = nature_style();
    p = inputParser;
    addParameter(p, 'clim', []);
    addParameter(p, 'title', 'Time-Frequency Power');
    addParameter(p, 'stats', []);
    addParameter(p, 'diff_data', []);
    addParameter(p, 'diff_mask', []);
    addParameter(p, 'style', s);
    addParameter(p, 'width', 'double');
    parse(p, varargin{:});
    s = p.Results.style;

    has_diff = ~isempty(p.Results.diff_data);
    if isstruct(tf_power)
        cond_names = fieldnames(tf_power);
        n_panels = numel(cond_names) + has_diff;
    else
        cond_names = {};
        n_panels = 1 + has_diff;
    end

    fw = s.figure.double_col;
    fh = 2.0;

    fig = figure('Name', 'TF', 'Units', 'inches', ...
        'Position', [1, 1, fw, fh * n_panels / 2 + 0.5], ...
        'Color', s.figure.background);

    panel = 0;

    % Frequency band annotations
    bands = struct('theta', [4 8], 'alpha', [8 13], 'beta', [13 30], ...
        'gamma', [30 70], 'hfa', [70 150]);

    if isstruct(tf_power)
        for c = 1:numel(cond_names)
            panel = panel + 1;
            ax = subplot(1, n_panels, panel);
            data = tf_power.(cond_names{c});
            draw_tf_panel(ax, data, time_vec, freqs, p.Results.clim, ...
                cond_names{c}, bands, [], s);
        end
    else
        panel = panel + 1;
        ax = subplot(1, n_panels, panel);
        stats_mask = [];
        if ~isempty(p.Results.stats) && isfield(p.Results.stats, 'sig_mask')
            stats_mask = p.Results.stats.sig_mask;
        end
        draw_tf_panel(ax, tf_power, time_vec, freqs, p.Results.clim, ...
            '', bands, stats_mask, s);
    end

    % Difference panel
    if has_diff
        panel = panel + 1;
        ax = subplot(1, n_panels, panel);
        draw_tf_panel(ax, p.Results.diff_data, time_vec, freqs, [], ...
            'Difference', bands, p.Results.diff_mask, s);
    end

    sgtitle(p.Results.title, 'FontSize', s.font.sgtitle, 'FontName', s.font.family);
    apply_nature_style(fig, s);
end


function draw_tf_panel(ax, data, time_vec, freqs, clim, panel_title, bands, sig_mask, s)
    imagesc(ax, time_vec, freqs, data);
    set(ax, 'YDir', 'normal');
    colormap(ax, nature_colormap('diverging'));

    if isempty(clim)
        mx = max(abs(data(:)));
        if mx > 0
            caxis(ax, [-mx mx]);
        end
    else
        caxis(ax, clim);
    end

    cb = colorbar(ax);
    ylabel(cb, 'Power (dB)', 'FontSize', s.font.colorbar);
    set(cb, 'FontSize', s.font.colorbar);

    hold(ax, 'on');
    xline(ax, 0, '--', 'Color', [1 1 1 0.7], 'LineWidth', s.line.reference);

    % Significance contour
    if ~isempty(sig_mask) && any(sig_mask(:))
        contour(ax, time_vec, freqs, double(sig_mask), [0.5 0.5], ...
            'Color', s.colors.black, 'LineWidth', 0.8);
    end

    % Frequency band lines
    band_names = fieldnames(bands);
    for b = 1:numel(band_names)
        bnd = bands.(band_names{b});
        if bnd(1) >= freqs(1) && bnd(1) <= freqs(end)
            yline(ax, bnd(1), ':', 'Color', [1 1 1 0.3], 'LineWidth', 0.3);
        end
    end

    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Frequency (Hz)');
    if ~isempty(panel_title)
        title(ax, panel_title, 'FontSize', s.font.title);
    end
    apply_nature_style(ax, s);
end
