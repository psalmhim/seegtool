function [elec_matched, match_idx] = harmonize_electrode_names(electrodes, channel_labels)
% HARMONIZE_ELECTRODE_NAMES Match electrode labels to channel labels.
%
%   Handles common BIDS naming mismatches:
%       electrodes.tsv: OF_1, B_Rt1, H_Rt1
%       channels.tsv:   OF1,  B_Rt1, H_Rt1  (or variations with/without underscore)
%
%   [elec_matched, match_idx] = harmonize_electrode_names(electrodes, channel_labels)
%
%   Inputs:
%       electrodes     - struct with .label (from electrodes.tsv)
%       channel_labels - cell array of channel names (from recording/channels.tsv)
%
%   Outputs:
%       elec_matched - electrode struct reordered/filtered to match channel_labels
%       match_idx    - index into original electrodes for each channel
%                      (0 = no match found)

    n_ch = numel(channel_labels);
    n_elec = numel(electrodes.label);

    match_idx = zeros(n_ch, 1);

    % Normalize function: strip underscores before digits for matching
    normalize = @(s) regexprep(strtrim(s), '_(?=\d)', '');

    elec_norm = cellfun(normalize, electrodes.label, 'UniformOutput', false);
    ch_norm = cellfun(normalize, channel_labels(:), 'UniformOutput', false);

    % Try exact match first
    for i = 1:n_ch
        idx = find(strcmp(electrodes.label, channel_labels{i}));
        if ~isempty(idx)
            match_idx(i) = idx(1);
            continue;
        end

        % Try normalized match
        idx = find(strcmpi(elec_norm, ch_norm{i}));
        if ~isempty(idx)
            match_idx(i) = idx(1);
            continue;
        end

        % Try case-insensitive original
        idx = find(strcmpi(electrodes.label, channel_labels{i}));
        if ~isempty(idx)
            match_idx(i) = idx(1);
        end
    end

    % Build matched electrode struct
    matched = match_idx > 0;
    n_matched = sum(matched);
    n_unmatched = sum(~matched);

    elec_matched = struct();
    elec_matched.label = channel_labels(:);

    % Initialize coordinate arrays
    elec_matched.x = nan(n_ch, 1);
    elec_matched.y = nan(n_ch, 1);
    elec_matched.z = nan(n_ch, 1);

    for i = 1:n_ch
        if match_idx(i) > 0
            j = match_idx(i);
            if ~isempty(electrodes.x); elec_matched.x(i) = electrodes.x(j); end
            if ~isempty(electrodes.y); elec_matched.y(i) = electrodes.y(j); end
            if ~isempty(electrodes.z); elec_matched.z(i) = electrodes.z(j); end
        end
    end

    % Copy optional fields
    if isfield(electrodes, 'group')
        elec_matched.group = cell(n_ch, 1);
        for i = 1:n_ch
            if match_idx(i) > 0
                elec_matched.group{i} = electrodes.group{match_idx(i)};
            else
                elec_matched.group{i} = '';
            end
        end
    end

    if isfield(electrodes, 'hemisphere')
        elec_matched.hemisphere = cell(n_ch, 1);
        for i = 1:n_ch
            if match_idx(i) > 0
                elec_matched.hemisphere{i} = electrodes.hemisphere{match_idx(i)};
            else
                elec_matched.hemisphere{i} = '';
            end
        end
    end

    fprintf('[BIDS] Electrode matching: %d/%d matched, %d unmatched\n', ...
        n_matched, n_ch, n_unmatched);

    if n_unmatched > 0
        unmatched_labels = channel_labels(~matched);
        if numel(unmatched_labels) <= 10
            fprintf('[BIDS] Unmatched channels: %s\n', strjoin(unmatched_labels, ', '));
        else
            fprintf('[BIDS] Unmatched channels: %s ... (%d more)\n', ...
                strjoin(unmatched_labels(1:5), ', '), numel(unmatched_labels)-5);
        end
    end
end
