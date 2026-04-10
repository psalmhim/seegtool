function fig = plot_permutation_summary(stats, time_vec, varargin)
% PLOT_PERMUTATION_SUMMARY Publication-quality permutation test visualization.
%
%   fig = plot_permutation_summary(stats, time_vec)
%
%   Inputs:
%       stats    - struct from run_permutation_statistics
%       time_vec - time vector
%       Name-Value:
%           'channel_labels' - cell array for channel-time map
%           'title'          - figure title
%           'style'          - style struct

    s = nature_style();
    p = inputParser;
    addParameter(p, 'channel_labels', {});
    addParameter(p, 'title', 'Statistical Evidence');
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    fig = figure('Name', 'Stats', 'Units', 'inches', ...
        'Position', [1, 1, s.figure.double_col, 3.5], ...
        'Color', s.figure.background);

    if ~isfield(stats, 'roi_p_values')
        % If stats doesn't have expected fields, plot empty
        text(0.5, 0.5, 'No ROI stats available', 'HorizontalAlignment', 'center', ...
            'FontSize', s.font.title);
        return;
    end

    channels = 1:numel(stats.roi_p_values);
    ch_labels = p.Results.channel_labels;
    if isempty(ch_labels) || numel(ch_labels) ~= numel(channels)
        ch_labels = cell(1, numel(channels));
        for i = 1:numel(channels)
            ch_labels{i} = sprintf('Ch%d', i);
        end
    end

    % --- Panel a: Effect Sizes ---
    ax1 = subplot(1, 3, 1);
    bar(ax1, channels, stats.effect_sizes, 'FaceColor', s.colors.palette(2,:), 'EdgeColor', 'none');
    set(ax1, 'XTick', channels, 'XTickLabel', ch_labels);
    xtickangle(ax1, 45);
    ylabel(ax1, 'Effect Size (Cohen''s d)', 'FontSize', s.font.axis_label);
    title(ax1, 'Condition Difference', 'FontSize', s.font.title);
    apply_nature_style(ax1, s);
    add_panel_label(ax1, 'a', s);

    % --- Panel b: P-values ---
    ax2 = subplot(1, 3, 2);
    log_p = -log10(max(stats.roi_p_values, 1e-10));
    bar(ax2, channels, log_p, 'FaceColor', s.colors.palette(1,:), 'EdgeColor', 'none');
    hold(ax2, 'on');
    yline(ax2, -log10(s.sig.alpha), '--', 'Color', s.colors.significance, 'LineWidth', s.line.reference);
    set(ax2, 'XTick', channels, 'XTickLabel', ch_labels);
    xtickangle(ax2, 45);
    ylabel(ax2, '-log_{10}(p)', 'FontSize', s.font.axis_label);
    title(ax2, 'Significance', 'FontSize', s.font.title);
    apply_nature_style(ax2, s);
    add_panel_label(ax2, 'b', s);

    % --- Panel c: Onset Times ---
    ax3 = subplot(1, 3, 3);
    scatter(ax3, channels, stats.onset_times, 30, s.colors.palette(3,:), 'filled');
    set(ax3, 'XTick', channels, 'XTickLabel', ch_labels);
    xtickangle(ax3, 45);
    ylabel(ax3, 'Onset Time (s)', 'FontSize', s.font.axis_label);
    title(ax3, 'Response Onset', 'FontSize', s.font.title);
    apply_nature_style(ax3, s);
    add_panel_label(ax3, 'c', s);

    sgtitle(p.Results.title, 'FontSize', s.font.sgtitle, 'FontName', s.font.family);
end

