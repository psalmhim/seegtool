function roi_groups = build_roi_groups_from_channels(channels, good_idx)
% BUILD_ROI_GROUPS_FROM_CHANNELS Build ROI groups from channels.tsv group column.
%
%   roi_groups = build_roi_groups_from_channels(channels, good_idx)

    if ~isfield(channels, 'group')
        elec.label = channels.name(good_idx);
        roi_groups = build_roi_groups(elec, 'shaft');
        return;
    end

    groups = channels.group(good_idx);
    names = channels.name(good_idx);
    unique_groups = unique(groups, 'stable');

    roi_groups = struct();
    for g = 1:numel(unique_groups)
        mask = strcmp(groups, unique_groups{g});
        roi_groups(g).name = unique_groups{g};
        roi_groups(g).indices = find(mask)';
        roi_groups(g).labels = names(mask);
        roi_groups(g).n_channels = sum(mask);
    end

    fprintf('[ROI] %d groups from channels.tsv group column\n', numel(roi_groups));
end
