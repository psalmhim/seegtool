function [matrix_2d, reshape_info] = reshape_trial_channel_time(tensor_3d, mode)
% RESHAPE_TRIAL_CHANNEL_TIME Reshape 3D tensor for different analyses.
%
%   [matrix_2d, reshape_info] = reshape_trial_channel_time(tensor_3d, mode)
%
%   Inputs:
%       tensor_3d - trials x channels x time
%       mode      - 'concat_trials', 'channel_time', or 'trial_features'
%
%   Outputs:
%       matrix_2d    - 2D matrix
%       reshape_info - struct for reversing the reshape

    [n_trials, n_channels, n_time] = size(tensor_3d);
    reshape_info.n_trials = n_trials;
    reshape_info.n_channels = n_channels;
    reshape_info.n_time = n_time;
    reshape_info.mode = mode;

    switch lower(mode)
        case 'concat_trials'
            % (trials*time) x channels
            matrix_2d = reshape(permute(tensor_3d, [1 3 2]), n_trials * n_time, n_channels);

        case 'channel_time'
            % channels x (trials*time)
            matrix_2d = reshape(permute(tensor_3d, [2 1 3]), n_channels, n_trials * n_time);

        case 'trial_features'
            % trials x (channels*time)
            matrix_2d = reshape(tensor_3d, n_trials, n_channels * n_time);

        otherwise
            error('reshape_trial_channel_time:invalidMode', 'Unknown mode: %s', mode);
    end
end
