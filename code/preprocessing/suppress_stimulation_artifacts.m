function [masked_data, stim_mask] = suppress_stimulation_artifacts(data, stim_times, fs, mask_duration)
% SUPPRESS_STIMULATION_ARTIFACTS Mask stimulation artifacts with interpolation.
%
%   [masked_data, stim_mask] = suppress_stimulation_artifacts(data, stim_times, fs, mask_duration)
%
%   Replaces signal within [t_stim, t_stim + mask_duration] with linear
%   interpolation between boundary values.
%
%   Inputs:
%       data          - channels x time matrix
%       stim_times    - vector of stimulation timestamps in seconds
%       fs            - sampling rate (Hz)
%       mask_duration - mask duration in seconds (default: 0.01)
%
%   Outputs:
%       masked_data - data with stimulation artifacts suppressed
%       stim_mask   - logical vector (1 x time), true = masked

    if nargin < 4 || isempty(mask_duration)
        mask_duration = 0.01;
    end

    masked_data = data;
    n_samples = size(data, 2);
    stim_mask = false(1, n_samples);
    mask_len = round(mask_duration * fs);

    for s = 1:numel(stim_times)
        start_sample = round(stim_times(s) * fs) + 1;
        end_sample = start_sample + mask_len - 1;

        if start_sample < 1 || start_sample > n_samples
            continue;
        end
        end_sample = min(end_sample, n_samples);
        stim_mask(start_sample:end_sample) = true;

        % Linear interpolation across masked segment
        pre_idx = max(1, start_sample - 1);
        post_idx = min(n_samples, end_sample + 1);
        n_interp = end_sample - start_sample + 1;

        for ch = 1:size(data, 1)
            val_pre = data(ch, pre_idx);
            val_post = data(ch, post_idx);
            masked_data(ch, start_sample:end_sample) = linspace(val_pre, val_post, n_interp);
        end
    end
end
