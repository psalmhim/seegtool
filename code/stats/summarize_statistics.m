function summary = summarize_statistics(stats_results, channel_labels, roi_names)
% SUMMARIZE_STATISTICS Create summary table of statistical results.
%
%   summary = summarize_statistics(stats_results, channel_labels, roi_names)
%
%   Inputs:
%       stats_results  - struct with statistical test results
%       channel_labels - cell array of channel names
%       roi_names      - cell array of ROI names
%
%   Outputs:
%       summary - struct with formatted summary

    summary = struct();
    summary.channel_labels = channel_labels;
    summary.roi_names = roi_names;

    if isfield(stats_results, 'p_values')
        summary.p_values = stats_results.p_values;
    end
    if isfield(stats_results, 'effect_sizes')
        summary.effect_sizes = stats_results.effect_sizes;
    end
    if isfield(stats_results, 'onset_times')
        summary.onset_times = stats_results.onset_times;
    end
    if isfield(stats_results, 'sig_clusters')
        summary.n_sig_clusters = sum(stats_results.sig_clusters(:));
    end

    summary.timestamp = datestr(now);
end
