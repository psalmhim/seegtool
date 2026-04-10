function tensor = build_trial_tensor(epochs_cell)
% BUILD_TRIAL_TENSOR Build 3D tensor from cell array of epoch matrices.
%
%   tensor = build_trial_tensor(epochs_cell)
%
%   Inputs:
%       epochs_cell - cell array where each cell is a channels x time matrix
%
%   Outputs:
%       tensor - trials x channels x time 3D array

    if ~iscell(epochs_cell) || isempty(epochs_cell)
        error('build_trial_tensor:invalidInput', 'Input must be a non-empty cell array.');
    end

    n_trials = numel(epochs_cell);
    [n_channels, n_time] = size(epochs_cell{1});

    tensor = zeros(n_trials, n_channels, n_time);
    for k = 1:n_trials
        if ~isequal(size(epochs_cell{k}), [n_channels, n_time])
            error('build_trial_tensor:sizeMismatch', ...
                'Epoch %d has different dimensions than epoch 1.', k);
        end
        tensor(k, :, :) = epochs_cell{k};
    end
end
