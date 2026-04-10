function roi_feats = extract_roi_features(tf_power, freqs, time_vec, roi_def)
% EXTRACT_ROI_FEATURES Extract features within a time-frequency ROI.
%
%   roi_feats = extract_roi_features(tf_power, freqs, time_vec, roi_def)
%
%   Inputs:
%       tf_power - trials x channels x freqs x time
%       freqs    - frequency vector
%       time_vec - time vector
%       roi_def  - struct with t_start, t_end, f_start, f_end
%
%   Outputs:
%       roi_feats - trials x channels mean power within ROI

    t_idx = time_vec >= roi_def.t_start & time_vec <= roi_def.t_end;
    f_idx = freqs >= roi_def.f_start & freqs <= roi_def.f_end;

    roi_data = tf_power(:, :, f_idx, t_idx);
    roi_feats = squeeze(mean(mean(roi_data, 4), 3));
end
