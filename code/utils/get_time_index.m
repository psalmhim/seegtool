function [idx_start, idx_end] = get_time_index(time_vec, t_start, t_end)
% GET_TIME_INDEX Convert time values to sample indices.
%
%   [idx_start, idx_end] = get_time_index(time_vec, t_start, t_end)
%
%   Inputs:
%       time_vec - time vector in seconds
%       t_start  - start time in seconds
%       t_end    - end time in seconds
%
%   Outputs:
%       idx_start - start sample index
%       idx_end   - end sample index

    if t_start > t_end
        error('get_time_index:invalidRange', 't_start must be <= t_end.');
    end

    [~, idx_start] = min(abs(time_vec - t_start));
    [~, idx_end] = min(abs(time_vec - t_end));
end
