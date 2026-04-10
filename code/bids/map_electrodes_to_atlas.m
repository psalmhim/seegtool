function mapping = map_electrodes_to_atlas(electrodes, atlas)
% MAP_ELECTRODES_TO_ATLAS Map electrode coordinates to atlas regions via nearest neighbor.
%
%   mapping = map_electrodes_to_atlas(electrodes, atlas)
%
%   Inputs:
%       electrodes - struct with .x, .y, .z, .label
%       atlas      - struct with .coords (N x 3), .labels (cell), .name
%
%   Outputs:
%       mapping.electrode_label - electrode labels
%       mapping.region_label    - matched atlas region per electrode
%       mapping.region_index    - atlas region index per electrode
%       mapping.distance_mm     - distance to nearest atlas coordinate
%       mapping.atlas_name      - name of atlas used

    n_elec = numel(electrodes.label);

    elec_coords = [electrodes.x(:), electrodes.y(:), electrodes.z(:)];
    atlas_coords = atlas.coords;

    mapping.electrode_label = electrodes.label;
    mapping.region_label = cell(n_elec, 1);
    mapping.region_index = zeros(n_elec, 1);
    mapping.distance_mm = zeros(n_elec, 1);

    if isfield(atlas, 'name')
        mapping.atlas_name = atlas.name;
    else
        mapping.atlas_name = 'unknown';
    end

    for i = 1:n_elec
        if any(isnan(elec_coords(i, :)))
            mapping.region_label{i} = 'unknown';
            mapping.region_index(i) = 0;
            mapping.distance_mm(i) = NaN;
            continue;
        end

        dists = sqrt(sum((atlas_coords - elec_coords(i, :)).^2, 2));
        [min_dist, min_idx] = min(dists);

        mapping.region_label{i} = atlas.labels{min_idx};
        mapping.region_index(i) = min_idx;
        mapping.distance_mm(i) = min_dist;
    end

    fprintf('[Atlas] Mapped %d electrodes to %s atlas (mean dist: %.1f mm)\n', ...
        n_elec, mapping.atlas_name, nanmean(mapping.distance_mm));
end
