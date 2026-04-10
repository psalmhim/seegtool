function fig = plot_decoding_curve(accuracy_time, p_values, time_vec, chance_level, varargin)
% PLOT_DECODING_CURVE Publication-quality time-resolved decoding with significance.
%
%   fig = plot_decoding_curve(accuracy_time, p_values, time_vec, chance_level)
%
%   Name-Value:
%       'ci'            - [2 x T] CI bounds
%       'onset_marker'  - onset latency in seconds
%       'confusion'     - confusion matrix at peak time
%       'title'         - figure title
%       'style'         - style struct

    s = nature_style();
    p = inputParser;
    addParameter(p, 'ci', []);
    addParameter(p, 'onset_marker', NaN);
    addParameter(p, 'confusion', []);
    addParameter(p, 'title', 'Neural Decoding');
    addParameter(p, 'style', s);
    parse(p, varargin{:});
    s = p.Results.style;

    has_confusion = ~isempty(p.Results.confusion);
    if has_confusion
        fw = s.figure.double_col;
    else
        fw = s.figure.one_half_col;
    end

    fig = figure('Name', 'Decoding', 'Units', 'inches', ...
        'Position', [1, 1, fw, 2.5], 'Color', s.figure.background);

    % --- Panel a: Time-resolved accuracy ---
    if has_confusion
        ax1 = subplot(1, 4, 1:3);
    else
        ax1 = axes(fig);
    end
    hold(ax1, 'on');

    col = s.colors.palette(1, :);
    sig_mask = p_values < s.sig.alpha;

    % Significance shading
    add_significance_shading(ax1, time_vec, sig_mask, s);

    % CI ribbon
    if ~isempty(p.Results.ci)
        ci = p.Results.ci;
        fill(ax1, [time_vec, fliplr(time_vec)], [ci(1,:), fliplr(ci(2,:))], ...
            col, 'EdgeColor', 'none', 'FaceAlpha', s.colors.ci_alpha);
    end

    % Accuracy curve
    plot(ax1, time_vec, accuracy_time, 'Color', col, 'LineWidth', s.line.mean);

    % Chance level
    yline(ax1, chance_level, '--', 'Color', s.colors.gray, 'LineWidth', s.line.reference);
    text(ax1, time_vec(end), chance_level, ' chance', ...
        'FontSize', s.font.annotation, 'Color', s.colors.gray, ...
        'VerticalAlignment', 'bottom');

    % Stimulus onset
    xline(ax1, 0, '--', 'Color', s.colors.black, 'LineWidth', s.line.reference);

    % Onset marker
    if ~isnan(p.Results.onset_marker)
        onset_t = p.Results.onset_marker;
        xline(ax1, onset_t, '-', 'Color', s.colors.palette(3,:), ...
            'LineWidth', s.line.data);
        text(ax1, onset_t, max(accuracy_time)*0.95, ...
            sprintf(' onset: %.0fms', onset_t*1000), ...
            'FontSize', s.font.annotation, 'Color', s.colors.palette(3,:));
    end

    % Peak annotation
    [peak_acc, peak_idx] = max(accuracy_time);
    peak_t = time_vec(peak_idx);
    plot(ax1, peak_t, peak_acc, 'v', 'Color', s.colors.significance, ...
        'MarkerSize', s.marker.size, 'MarkerFaceColor', s.colors.significance);
    text(ax1, peak_t, peak_acc * 1.03, ...
        sprintf('%.1f%%', peak_acc*100), ...
        'FontSize', s.font.annotation, 'Color', s.colors.significance, ...
        'HorizontalAlignment', 'center');

    xlabel(ax1, 'Time (s)');
    ylabel(ax1, 'Accuracy');
    title(ax1, p.Results.title);
    ylim(ax1, [max(0, chance_level - 0.15), min(1, max(accuracy_time) * 1.15)]);
    xlim(ax1, [time_vec(1), time_vec(end)]);
    apply_nature_style(ax1, s);
    if has_confusion; add_panel_label(ax1, 'a', s); end

    % --- Panel b: Confusion matrix ---
    if has_confusion
        ax2 = subplot(1, 4, 4);
        cm = p.Results.confusion;
        cm_norm = cm ./ sum(cm, 2);
        imagesc(ax2, cm_norm);
        colormap(ax2, nature_colormap('sequential'));
        caxis(ax2, [0, 1]);
        colorbar(ax2, 'FontSize', s.font.colorbar);
        xlabel(ax2, 'Predicted');
        ylabel(ax2, 'True');
        title(ax2, sprintf('t = %.0fms', peak_t*1000));
        axis(ax2, 'square');
        apply_nature_style(ax2, s);
        add_panel_label(ax2, 'b', s);
    end
end
