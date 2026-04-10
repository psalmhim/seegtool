function paths = make_output_dirs(base_dir, subject_id)
% MAKE_OUTPUT_DIRS Create output directory structure for a subject.
%
%   paths = make_output_dirs(base_dir, subject_id)
%
%   Inputs:
%       base_dir   - base results directory
%       subject_id - subject identifier string
%
%   Outputs:
%       paths - struct with all created directory paths

    paths.subject = fullfile(base_dir, 'subject_level', subject_id);
    paths.figures = fullfile(base_dir, 'figures', subject_id);
    paths.tables = fullfile(base_dir, 'tables');
    paths.logs = fullfile(base_dir, 'logs');

    dir_list = {paths.subject, paths.figures, paths.tables, paths.logs};
    for i = 1:numel(dir_list)
        if ~isfolder(dir_list{i})
            mkdir(dir_list{i});
        end
    end
end
