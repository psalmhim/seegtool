function summary = summarize_uncertainty(boot_results)
% SUMMARIZE_UNCERTAINTY Summarize bootstrap uncertainty results.
%
%   summary = summarize_uncertainty(boot_results)
%
%   Inputs:
%       boot_results - struct from bootstrap_trajectory_uncertainty
%
%   Outputs:
%       summary - struct with formatted summary statistics

    summary = struct();

    cond_names = fieldnames(boot_results.trajectories);
    for c = 1:numel(cond_names)
        name = cond_names{c};
        bt = boot_results.trajectories.(name);
        summary.trajectory_se.(name) = squeeze(std(bt, 0, 1));
    end

    if isfield(boot_results, 'geometry')
        geo_fields = fieldnames(boot_results.geometry);
        for g = 1:numel(geo_fields)
            gname = geo_fields{g};
            summary.geometry.(gname) = boot_results.geometry.(gname);
        end
    end
end
