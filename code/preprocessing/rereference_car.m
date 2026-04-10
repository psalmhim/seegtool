function reref_data = rereference_car(data, valid_channels)
% REREFERENCE_CAR Apply common average reference.
%
%   reref_data = rereference_car(data, valid_channels)
%
%   Computes: x_i^CAR(t) = x_i(t) - (1/N) * sum(x_j(t)) for valid channels
%
%   Inputs:
%       data           - channels x time matrix
%       valid_channels - logical or index vector of valid channels (default: all)
%
%   Outputs:
%       reref_data - re-referenced data, same size as input

    if nargin < 2 || isempty(valid_channels)
        valid_channels = true(size(data, 1), 1);
    end

    if islogical(valid_channels)
        valid_idx = find(valid_channels);
    else
        valid_idx = valid_channels;
    end

    common_avg = mean(data(valid_idx, :), 1);

    reref_data = data - common_avg;
end
