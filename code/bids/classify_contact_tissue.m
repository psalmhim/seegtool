function tissue_info = classify_contact_tissue(electrodes, varargin)
% CLASSIFY_CONTACT_TISSUE Classify SEEG contacts as gray/white matter.
%
%   tissue_info = classify_contact_tissue(electrodes)
%   tissue_info = classify_contact_tissue(electrodes, 'atlas_nii', path)
%   tissue_info = classify_contact_tissue(electrodes, 'method', 'atlas')
%
%   Methods:
%     'atlas'    - Use NIfTI atlas in MNI space (AAL, Destrieux, etc.)
%                  Contacts with a non-zero atlas label = gray matter.
%     'neighbor' - Compare each contact to its shaft neighbors.
%                  Contacts with low variance relative to neighbors = WM.
%     'manual'   - Load from a TSV file with tissue labels.
%
%   Inputs:
%       electrodes - struct with .label, .x, .y, .z (MNI coords)
%
%   Name-Value:
%       'atlas_nii'   - path to NIfTI atlas file (MNI space)
%       'method'      - 'atlas' (default), 'neighbor', 'manual'
%       'manual_file' - path to TSV with columns: name, tissue
%       'radius_mm'   - search radius for atlas lookup (default: 3)
%
%   Output:
%       tissue_info - struct with:
%           .label       - cell array of contact names
%           .tissue      - cell array: 'GM', 'WM', or 'unknown'
%           .region      - cell array: atlas region name (if atlas method)
%           .is_gm       - logical array: true if gray matter
%           .gm_indices  - indices of gray matter contacts

    p = inputParser;
    addParameter(p, 'atlas_nii', '', @ischar);
    addParameter(p, 'method', 'atlas', @ischar);
    addParameter(p, 'manual_file', '', @ischar);
    addParameter(p, 'radius_mm', 3, @isnumeric);
    parse(p, varargin{:});

    n_contacts = numel(electrodes.label);
    tissue_info = struct();
    tissue_info.label = electrodes.label;
    tissue_info.tissue = repmat({'unknown'}, n_contacts, 1);
    tissue_info.region = repmat({''}, n_contacts, 1);
    tissue_info.is_gm = true(n_contacts, 1);  % default: include all

    switch lower(p.Results.method)
        case 'atlas'
            atlas_path = p.Results.atlas_nii;
            if isempty(atlas_path)
                fprintf('[Tissue] No atlas provided, all contacts included.\n');
                tissue_info.gm_indices = (1:n_contacts)';
                return;
            end
            tissue_info = classify_by_atlas(tissue_info, electrodes, ...
                atlas_path, p.Results.radius_mm);

        case 'neighbor'
            tissue_info = classify_by_neighbor(tissue_info, electrodes);

        case 'manual'
            tissue_info = classify_from_file(tissue_info, p.Results.manual_file);
    end

    tissue_info.gm_indices = find(tissue_info.is_gm);
    n_gm = sum(tissue_info.is_gm);
    n_wm = sum(~tissue_info.is_gm);
    fprintf('[Tissue] %d GM, %d WM/unknown out of %d contacts\n', n_gm, n_wm, n_contacts);
end


function ti = classify_by_atlas(ti, electrodes, atlas_path, radius_mm)
% Look up each contact's MNI coordinate in a NIfTI atlas.
    if ~isfile(atlas_path)
        warning('classify_contact_tissue:noAtlas', 'Atlas not found: %s', atlas_path);
        return;
    end

    % Load NIfTI atlas
    try
        V = niftiread(atlas_path);
        info = niftiinfo(atlas_path);
    catch ME
        warning('classify_contact_tissue:loadFail', 'Cannot load atlas: %s', ME.message);
        return;
    end

    % MNI → voxel transform (inverse of affine)
    T = info.Transform.T';  % 4x4 affine (NIfTI stores transposed)
    T_inv = inv(T);

    n = numel(ti.label);
    for i = 1:n
        mni = [electrodes.x(i), electrodes.y(i), electrodes.z(i), 1];
        vox = round(T_inv * mni');
        vx = vox(1); vy = vox(2); vz = vox(3);

        label_val = 0;
        % Check exact voxel first
        if vx >= 1 && vx <= size(V,1) && vy >= 1 && vy <= size(V,2) && vz >= 1 && vz <= size(V,3)
            label_val = V(vx, vy, vz);
        end

        % If no label, search within radius
        if label_val == 0 && radius_mm > 0
            vox_size = abs(diag(T(1:3,1:3)));
            r_vox = ceil(radius_mm ./ vox_size');
            best_dist = Inf;
            for dx = -r_vox(1):r_vox(1)
                for dy = -r_vox(2):r_vox(2)
                    for dz = -r_vox(3):r_vox(3)
                        cx = vx+dx; cy = vy+dy; cz = vz+dz;
                        if cx < 1 || cx > size(V,1) || cy < 1 || cy > size(V,2) || cz < 1 || cz > size(V,3)
                            continue;
                        end
                        if V(cx, cy, cz) > 0
                            dist = norm([dx dy dz] .* vox_size');
                            if dist < best_dist
                                best_dist = dist;
                                label_val = V(cx, cy, cz);
                            end
                        end
                    end
                end
            end
        end

        if label_val > 0
            ti.tissue{i} = 'GM';
            ti.region{i} = sprintf('region_%d', label_val);
            ti.is_gm(i) = true;
        else
            ti.tissue{i} = 'WM';
            ti.region{i} = '';
            ti.is_gm(i) = false;
        end
    end
end


function ti = classify_by_neighbor(ti, electrodes)
% Heuristic: contacts far from shaft extremes and with similar coords
% to neighbors are likely in white matter tracts.
% Uses shaft grouping: tip contacts (high number) = deep = more likely GM,
% proximal contacts (low number) near skull = more likely WM.
    roi = infer_electrode_roi_fields(electrodes.label);
    shafts = unique(roi.shaft_name, 'stable');

    for s = 1:numel(shafts)
        shaft_mask = strcmp(roi.shaft_name, shafts{s});
        shaft_idx = find(shaft_mask);
        n_shaft = numel(shaft_idx);
        if n_shaft < 3; continue; end

        % Contact numbers along shaft
        nums = roi.contact_num(shaft_idx);
        [~, order] = sort(nums);
        shaft_idx = shaft_idx(order);

        % Compute inter-contact distances
        coords = [electrodes.x(shaft_idx), electrodes.y(shaft_idx), electrodes.z(shaft_idx)];
        dists = zeros(n_shaft - 1, 1);
        for j = 1:(n_shaft-1)
            dists(j) = norm(coords(j+1,:) - coords(j,:));
        end

        % Contacts with very uniform spacing (no bends) near entry are
        % likely in white matter. This is a rough heuristic.
        % Mark first 1-2 contacts as potential WM if spacing is uniform
        if n_shaft >= 6
            mean_dist = mean(dists);
            for j = 1:min(2, n_shaft)
                % Entry contacts (low contact number, near skull)
                ti.tissue{shaft_idx(j)} = 'WM_candidate';
                ti.is_gm(shaft_idx(j)) = false;
            end
        end
    end
end


function ti = classify_from_file(ti, manual_file)
% Load tissue labels from a TSV file: name\ttissue
    if isempty(manual_file) || ~isfile(manual_file)
        warning('classify_contact_tissue:noFile', 'Manual file not found.');
        return;
    end
    T = readtable(manual_file, 'FileType', 'text', 'Delimiter', '\t');
    for i = 1:height(T)
        idx = find(strcmp(ti.label, T.name{i}), 1);
        if ~isempty(idx)
            ti.tissue{idx} = upper(T.tissue{i});
            ti.is_gm(idx) = strcmpi(T.tissue{i}, 'GM') || strcmpi(T.tissue{i}, 'gray');
        end
    end
end
