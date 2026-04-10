function artifact_mask = detect_artifact_segments(data, threshold, fs)
% DETECT_ARTIFACT_SEGMENTS Detect artifact segments by amplitude threshold.
%
%   artifact_mask = detect_artifact_segments(data, threshold, fs)
%
%   Samples where |x(t)| > threshold are flagged, plus a 50ms margin.
%
%   Inputs:
%       data      - channels x time matrix
%       threshold - amplitude threshold (microvolts)
%       fs        - sampling rate (Hz)
%
%   Outputs:
%       artifact_mask - logical matrix (channels x time), true = artifact

    if nargin < 2 || isempty(threshold)
        threshold = 500;
    end

    artifact_mask = abs(data) > threshold;

    % Extend detected segments by 50ms margin on each side
    margin_samples = round(0.05 * fs);
    for ch = 1:size(data, 1)
        artifact_idx = find(artifact_mask(ch, :));
        for idx = artifact_idx
            start_idx = max(1, idx - margin_samples);
            end_idx = min(size(data, 2), idx + margin_samples);
            artifact_mask(ch, start_idx:end_idx) = true;
        end
    end
end
