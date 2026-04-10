function save_results(results, output_path, subject_id, analysis_name)
% SAVE_RESULTS Save analysis results to .mat file with metadata.
%
%   save_results(results, output_path, subject_id, analysis_name)
%
%   Inputs:
%       results       - struct containing analysis results
%       output_path   - directory to save results in
%       subject_id    - subject identifier string
%       analysis_name - name of the analysis (e.g., 'preprocessing')

    if nargin < 4
        analysis_name = 'results';
    end

    if ~isfolder(output_path)
        mkdir(output_path);
    end

    save_info.subject_id = subject_id;
    save_info.analysis_name = analysis_name;
    save_info.timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    save_info.matlab_version = version;

    results.save_info = save_info;

    filename = sprintf('%s_%s_%s.mat', subject_id, analysis_name, save_info.timestamp);
    full_path = fullfile(output_path, filename);

    save(full_path, 'results', '-v7.3');
    fprintf('Results saved to: %s\n', full_path);
end
