function masked_tensor = apply_poststim_mask(trial_tensor, time_vec, mask_duration)
% APPLY_POSTSTIM_MASK Mask post-stimulus artifact window with NaN.
%
%   masked_tensor = apply_poststim_mask(trial_tensor, time_vec, mask_duration)
%
%   Sets samples within [0, mask_duration] to NaN in each trial.
%
%   Inputs:
%       trial_tensor  - trials x channels x time
%       time_vec      - time vector in seconds (relative to event)
%       mask_duration - duration to mask in seconds
%
%   Outputs:
%       masked_tensor - trial tensor with masked samples set to NaN

    if mask_duration <= 0
        masked_tensor = trial_tensor;
        return;
    end

    mask_idx = time_vec >= 0 & time_vec <= mask_duration;

    masked_tensor = trial_tensor;
    masked_tensor(:, :, mask_idx) = NaN;
end
