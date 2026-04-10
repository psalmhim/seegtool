function atlas = load_simple_atlas_mat(atlas_file)
% LOAD_SIMPLE_ATLAS_MAT Load atlas from a .mat file for electrode mapping.
%
%   atlas = load_simple_atlas_mat(atlas_file)
%
%   Expected .mat fields:
%       coords - N x 3 matrix of region centroids (MNI coordinates)
%       labels - N x 1 cell array of region names
%       name   - atlas name string (optional)
%
%   Output:
%       atlas.coords - N x 3
%       atlas.labels - cell array
%       atlas.name   - string

    if ~isfile(atlas_file)
        error('BIDS:AtlasNotFound', 'Atlas file not found: %s', atlas_file);
    end

    S = load(atlas_file);

    if isfield(S, 'coords')
        atlas.coords = S.coords;
    elseif isfield(S, 'centroids')
        atlas.coords = S.centroids;
    elseif isfield(S, 'mni')
        atlas.coords = S.mni;
    else
        error('BIDS:AtlasFormat', 'Atlas .mat must contain coords, centroids, or mni field');
    end

    if isfield(S, 'labels')
        atlas.labels = S.labels;
    elseif isfield(S, 'region_names')
        atlas.labels = S.region_names;
    elseif isfield(S, 'names')
        atlas.labels = S.names;
    else
        error('BIDS:AtlasFormat', 'Atlas .mat must contain labels, region_names, or names field');
    end

    if isstring(atlas.labels)
        atlas.labels = cellstr(atlas.labels);
    end

    if isfield(S, 'name')
        atlas.name = S.name;
    elseif isfield(S, 'atlas_name')
        atlas.name = S.atlas_name;
    else
        [~, fname, ~] = fileparts(atlas_file);
        atlas.name = fname;
    end

    fprintf('[Atlas] Loaded %s: %d regions\n', atlas.name, numel(atlas.labels));
end
