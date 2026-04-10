function fig = plot_channel_significance(stats, decoding, time_vec, varargin)
% PLOT_CHANNEL_SIGNIFICANCE Comprehensive 4-panel channel significance figure.
%
%   fig = plot_channel_significance(stats, decoding, time_vec, ...)
%
%   Panel a: Channel x time heatmap of -log10(p) with cluster contours
%   Panel b: Per-channel effect size (sorted, FDR-highlighted)
%   Panel c: Top N channel decoding weight time courses
%   Panel d: Summary table of significant channels
%
%   Inputs:
%       stats    - struct from run_permutation_statistics (ch_time_p, ch_time_sig, etc.)
%       decoding - struct from run_neural_decoding (channel_importance, etc.), can be empty
%       time_vec - time vector (seconds)
%
%   Name-Value:
%       'channel_labels' - cell array of channel names
%       'top_n'          - number of top channels (default: 20)
%       'regions'        - cell array of region names per channel
%       'title'          - figure title
%       'style'          - style struct

    s = nature_style();
    p = inputParser;
    addParameter(p, 'channel_labels', {});
    addParameter(p, 'top_n', 20);
    addParameter(p, 'regions', {});
    addParameter(p, 'title', 'Channel Significance');
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;
    top_n = p.Results.top_n;

    n_channels = numel(stats.roi_p_values);
    ch_labels = p.Results.channel_labels;
    if isempty(ch_labels) || numel(ch_labels) ~= n_channels
        ch_labels = arrayfun(@(i) sprintf('Ch%d', i), 1:n_channels, 'UniformOutput', false);
    end
    regions = p.Results.regions;

    fig = figure('Name', 'ChannelSig', 'Units', 'inches', ...
        'Position', [0.5, 0.5, s.figure.double_col, 7.5], ...
        'Color', s.figure.background);

    has_ch_time = isfield(stats, 'ch_time_p') && ~isempty(stats.ch_time_p);
    has_decoding = ~isempty(decoding) && isfield(decoding, 'channel_importance');

    %% Sort channels by significance (for consistent ordering)
    if has_ch_time
        sort_score = stats.n_sig_timepoints;
    else
        sort_score = -log10(max(stats.roi_p_values, 1e-10));
    end
    [~, sort_idx] = sort(sort_score, 'descend');
    top_n = min(top_n, n_channels);
    top_ch = sort_idx(1:top_n);

    %% Panel a: Channel x time heatmap
    ax1 = subplot(2, 2, 1);
    if has_ch_time
        plot_heatmap_panel(ax1, stats, time_vec, ch_labels, top_ch, s);
    else
        text(ax1, 0.5, 0.5, 'Channel x time stats not computed', ...
            'HorizontalAlignment', 'center', 'FontSize', s.font.axis_label);
        axis(ax1, 'off');
    end
    add_panel_label(ax1, 'a', s);

    %% Panel b: Effect size bar chart
    ax2 = subplot(2, 2, 2);
    plot_effect_size_panel(ax2, stats, ch_labels, top_ch, s);
    add_panel_label(ax2, 'b', s);

    %% Panel c: Decoding weight time courses
    ax3 = subplot(2, 2, 3);
    if has_decoding
        plot_decoding_weights_panel(ax3, decoding, time_vec, ch_labels, top_ch, s);
    else
        text(ax3, 0.5, 0.5, 'Decoding weights not computed', ...
            'HorizontalAlignment', 'center', 'FontSize', s.font.axis_label);
        axis(ax3, 'off');
    end
    add_panel_label(ax3, 'c', s);

    %% Panel d: Summary table
    ax4 = subplot(2, 2, 4);
    plot_summary_table(ax4, stats, decoding, ch_labels, regions, top_ch, s);
    add_panel_label(ax4, 'd', s);

    sgtitle(p.Results.title, 'FontSize', s.font.sgtitle, 'FontName', s.font.family);
end


function plot_heatmap_panel(ax, stats, time_vec, ch_labels, top_ch, s)
% Panel a: Channel x time -log10(p) heatmap with cluster contours.
    log_p = -log10(max(stats.ch_time_p(top_ch, :), 1e-10));

    imagesc(ax, time_vec, 1:numel(top_ch), log_p);
    set(ax, 'YDir', 'normal');
    colormap(ax, make_blue_colormap());
    cb = colorbar(ax);
    cb.Label.String = '-log_{10}(p)';
    cb.Label.FontSize = s.font.colorbar;
    cb.FontSize = s.font.tick_label;
    clim(ax, [0 max(4, max(log_p(:)))]);

    % Cluster contours
    if isfield(stats, 'ch_time_sig')
        hold(ax, 'on');
        sig_mask = stats.ch_time_sig(top_ch, :);
        if any(sig_mask(:))
            contour(ax, time_vec, 1:numel(top_ch), double(sig_mask), [0.5 0.5], ...
                'Color', s.colors.black, 'LineWidth', s.line.data);
        end
    end

    % Stimulus onset line
    hold(ax, 'on');
    xline(ax, 0, '--', 'Color', s.colors.gray, 'LineWidth', s.line.reference);

    % Labels
    n_show = min(numel(top_ch), 20);
    tick_idx = round(linspace(1, numel(top_ch), n_show));
    set(ax, 'YTick', tick_idx, 'YTickLabel', ch_labels(top_ch(tick_idx)));
    xlabel(ax, 'Time (s)', 'FontSize', s.font.axis_label);
    ylabel(ax, 'Channel', 'FontSize', s.font.axis_label);
    title(ax, 'Significance Map', 'FontSize', s.font.title);
    apply_nature_style(ax, s);
end


function plot_effect_size_panel(ax, stats, ch_labels, top_ch, s)
% Panel b: Horizontal bar chart of effect sizes for top channels.
    es = stats.effect_sizes(top_ch);
    p_fdr = stats.roi_p_fdr(top_ch);
    n = numel(top_ch);

    barh(ax, 1:n, es, 'EdgeColor', 'none');

    % Color bars by significance
    hold(ax, 'on');
    for i = 1:n
        if p_fdr(i) < 0.05
            barh(ax, i, es(i), 'FaceColor', s.colors.significance, 'EdgeColor', 'none');
        else
            barh(ax, i, es(i), 'FaceColor', s.colors.nonsig, 'EdgeColor', 'none');
        end
    end

    % Annotate with p-values
    for i = 1:n
        if p_fdr(i) < 0.001
            txt = 'p<.001';
        elseif p_fdr(i) < 0.01
            txt = sprintf('p=%.3f', p_fdr(i));
        elseif p_fdr(i) < 0.05
            txt = sprintf('p=%.3f', p_fdr(i));
        else
            txt = '';
        end
        if ~isempty(txt)
            text(ax, es(i) + 0.02 * max(es), i, txt, ...
                'FontSize', s.font.annotation, 'VerticalAlignment', 'middle');
        end
    end

    set(ax, 'YTick', 1:n, 'YTickLabel', ch_labels(top_ch));
    xlabel(ax, 'Effect Size (Cohen''s d)', 'FontSize', s.font.axis_label);
    ylabel(ax, 'Channel', 'FontSize', s.font.axis_label);
    title(ax, 'Condition Effect', 'FontSize', s.font.title);
    apply_nature_style(ax, s);
end


function plot_decoding_weights_panel(ax, decoding, time_vec, ch_labels, top_ch, s)
% Panel c: Time courses of decoding weights for top channels.
    weights = decoding.channel_importance;
    n_show = min(8, numel(top_ch));
    show_ch = top_ch(1:n_show);

    hold(ax, 'on');
    leg_labels = cell(1, n_show);
    for i = 1:n_show
        ch = show_ch(i);
        ci = mod(i - 1, size(s.colors.palette, 1)) + 1;
        plot(ax, time_vec, weights(ch, :), 'Color', s.colors.palette(ci, :), ...
            'LineWidth', s.line.data);
        leg_labels{i} = ch_labels{ch};
    end

    xline(ax, 0, '--', 'Color', s.colors.gray, 'LineWidth', s.line.reference);
    xlabel(ax, 'Time (s)', 'FontSize', s.font.axis_label);
    ylabel(ax, 'Decoding Weight (a.u.)', 'FontSize', s.font.axis_label);
    title(ax, 'Channel Decoding Contribution', 'FontSize', s.font.title);
    legend(ax, leg_labels, 'FontSize', s.font.legend, 'Location', 'best', 'Box', 'off');
    apply_nature_style(ax, s);
end


function plot_summary_table(ax, stats, decoding, ch_labels, regions, top_ch, s)
% Panel d: Text-based summary table of top significant channels.
    axis(ax, 'off');
    title(ax, 'Significant Channels', 'FontSize', s.font.title);

    has_regions = ~isempty(regions) && numel(regions) >= max(top_ch);
    has_decode = ~isempty(decoding) && isfield(decoding, 'channel_mean_weight');
    has_onset = isfield(stats, 'onset_per_channel') && ~isempty(stats.onset_per_channel);

    % Header
    header = sprintf('%-4s %-10s', 'Rank', 'Channel');
    if has_regions
        header = [header, sprintf(' %-10s', 'Region')];
    end
    header = [header, sprintf(' %8s %8s', 'Effect', 'p(FDR)')];
    if has_onset
        header = [header, sprintf(' %8s', 'Onset')];
    end
    if has_decode
        header = [header, sprintf(' %8s', 'DecW')];
    end

    n_show = min(15, numel(top_ch));
    y_start = 0.92;
    dy = 0.055;

    text(ax, 0.02, y_start, header, 'FontSize', s.font.annotation, ...
        'FontName', 'Courier', 'FontWeight', 'bold', ...
        'Units', 'normalized', 'VerticalAlignment', 'top');

    for i = 1:n_show
        ch = top_ch(i);
        row = sprintf('%-4d %-10s', i, truncate_label(ch_labels{ch}, 10));

        if has_regions
            reg = '';
            if ch <= numel(regions)
                reg = truncate_label(regions{ch}, 10);
            end
            row = [row, sprintf(' %-10s', reg)];
        end

        row = [row, sprintf(' %8.2f %8.4f', stats.effect_sizes(ch), stats.roi_p_fdr(ch))];

        if has_onset
            onset_ms = stats.onset_per_channel(ch) * 1000;
            if isnan(onset_ms)
                row = [row, sprintf(' %8s', 'N/A')];
            else
                row = [row, sprintf(' %7.0fms', onset_ms)];
            end
        end

        if has_decode
            row = [row, sprintf(' %8.3f', decoding.channel_mean_weight(ch))];
        end

        is_sig = stats.roi_p_fdr(ch) < 0.05;
        fw = 'normal';
        if is_sig
            fw = 'bold';
        end

        text(ax, 0.02, y_start - i * dy, row, 'FontSize', s.font.annotation, ...
            'FontName', 'Courier', 'FontWeight', fw, ...
            'Units', 'normalized', 'VerticalAlignment', 'top');
    end
end


function cmap = make_blue_colormap()
% White-to-blue colormap for significance heatmaps.
    n = 256;
    r = linspace(1, 0.05, n)';
    g = linspace(1, 0.20, n)';
    b = linspace(1, 0.60, n)';
    cmap = [r, g, b];
end


function s = truncate_label(label, maxlen)
% Truncate label string to maxlen characters.
    if numel(label) > maxlen
        s = label(1:maxlen);
    else
        s = label;
    end
end


function regions = build_channel_region_map(channel_labels, roi_groups)
% Map channel labels to region names from roi_groups.
    regions = repmat({''}, numel(channel_labels), 1);
    if isempty(roi_groups); return; end
    for g = 1:numel(roi_groups)
        for ch = 1:numel(roi_groups(g).channel_idx)
            idx = roi_groups(g).channel_idx(ch);
            if idx <= numel(regions)
                regions{idx} = roi_groups(g).name;
            end
        end
    end
end
