function add_paths()
% ADD_PATHS Add all project subdirectories to the MATLAB path.
%
%   add_paths() adds the code directory and all its subdirectories
%   to the MATLAB path for the SEEG population dynamics pipeline.

    project_root = fileparts(fileparts(mfilename('fullpath')));
    code_dir = fullfile(project_root, 'code');

    subdirs = {
        'config', 'io', 'preprocessing', 'epoching', 'qc', ...
        'erp', 'timefreq', 'phase', 'features', 'stats', ...
        'population', 'latent', 'geometry', 'dynamics', ...
        'decoding', 'uncertainty', 'visualization', 'utils', ...
        'bids', 'reporting', 'contrasts', 'dashboard'
    };

    % Add nested subdirectories
    nested = {
        fullfile('visualization', 'style'), ...
        fullfile('reporting', 'templates')
    };

    addpath(code_dir);
    for i = 1:numel(subdirs)
        subdir_path = fullfile(code_dir, subdirs{i});
        if isfolder(subdir_path)
            addpath(subdir_path);
        end
    end

    for i = 1:numel(nested)
        nested_path = fullfile(code_dir, nested{i});
        if isfolder(nested_path)
            addpath(nested_path);
        end
    end

    % Add external toolboxes if present
    ft_path = fullfile(code_dir, 'external', 'fieldtrip');
    if isfolder(ft_path)
        addpath(ft_path);
    end

    % Add fCWT (fast Continuous Wavelet Transform)
    fcwt_path = fullfile(project_root, 'tools', 'fCWT', 'MATLAB');
    if isfolder(fcwt_path)
        addpath(fcwt_path);
    end
end
