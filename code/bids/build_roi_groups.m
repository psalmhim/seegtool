function roi_groups = build_roi_groups(electrodes, method, varargin)
% BUILD_ROI_GROUPS Group electrodes into ROIs by shaft name, atlas region, or custom.
%
%   roi_groups = build_roi_groups(electrodes, method)
%   roi_groups = build_roi_groups(electrodes, 'atlas', mapping)
%
%   Inputs:
%       electrodes - struct with .label (and optionally .group)
%       method     - 'shaft' (from label parsing), 'atlas' (from mapping),
%                    'group' (from electrodes.tsv group column)
%       mapping    - (for 'atlas') output of map_electrodes_to_atlas
%
%   Output:
%       roi_groups - struct array with:
%           .name       - ROI name
%           .indices    - channel indices belonging to this ROI
%           .labels     - channel labels in this ROI
%           .n_channels - number of channels

    n = numel(electrodes.label);

    switch lower(method)
        case 'shaft'
            roi_info = infer_electrode_roi_fields(electrodes);
            group_labels = roi_info.shaft_name;

        case 'atlas'
            if isempty(varargin)
                error('BIDS:MissingArg', 'Atlas method requires mapping argument');
            end
            mapping = varargin{1};
            group_labels = mapping.region_label;

        case 'group'
            if isfield(electrodes, 'group')
                group_labels = electrodes.group;
            else
                warning('BIDS:NoGroup', 'No group field; falling back to shaft method');
                roi_info = infer_electrode_roi_fields(electrodes);
                group_labels = roi_info.shaft_name;
            end

        otherwise
            error('BIDS:InvalidMethod', 'Unknown grouping method: %s', method);
    end

    unique_groups = unique(group_labels, 'stable');
    n_groups = numel(unique_groups);

    roi_groups = struct();
    for g = 1:n_groups
        mask = strcmp(group_labels, unique_groups{g});
        idx = find(mask);

        roi_groups(g).name = unique_groups{g};
        roi_groups(g).indices = idx(:)';
        roi_groups(g).labels = electrodes.label(idx);
        roi_groups(g).n_channels = numel(idx);
    end

    fprintf('[ROI] Built %d ROI groups from %d electrodes (%s method)\n', ...
        n_groups, n, method);
end
