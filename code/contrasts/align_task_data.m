function [data_A, data_B, common_time] = align_task_data(data_A, time_A, data_B, time_B)
% ALIGN_TASK_DATA Align two trial tensors to a common time window.
%
%   [data_A, data_B, common_time] = align_task_data(data_A, time_A, data_B, time_B)
%
%   Finds the overlapping time range and crops both tensors.
%   Assumes same sampling rate (same hardware).
%
%   Inputs:
%       data_A  - trials_A x channels x time_A
%       time_A  - 1 x time_A vector (seconds)
%       data_B  - trials_B x channels x time_B
%       time_B  - 1 x time_B vector (seconds)
%
%   Outputs:
%       data_A      - trials_A x channels x common_time
%       data_B      - trials_B x channels x common_time
%       common_time - 1 x T vector (seconds)

    t_start = max(time_A(1), time_B(1));
    t_end   = min(time_A(end), time_B(end));

    if t_start >= t_end
        error('align_task_data:noOverlap', ...
            'No time overlap: A=[%.2f, %.2f], B=[%.2f, %.2f]', ...
            time_A(1), time_A(end), time_B(1), time_B(end));
    end

    % Find indices in each time vector
    idx_A = find(time_A >= t_start - 1e-6 & time_A <= t_end + 1e-6);
    idx_B = find(time_B >= t_start - 1e-6 & time_B <= t_end + 1e-6);

    % Match lengths (take minimum)
    n_common = min(numel(idx_A), numel(idx_B));
    idx_A = idx_A(1:n_common);
    idx_B = idx_B(1:n_common);

    data_A = data_A(:, :, idx_A);
    data_B = data_B(:, :, idx_B);
    common_time = time_A(idx_A);

    fprintf('[Align] Common window: [%.3f, %.3f]s (%d samples)\n', ...
        common_time(1), common_time(end), n_common);
end
