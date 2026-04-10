function components = extract_erp_components(erp, time_vec, roi_windows)
% EXTRACT_ERP_COMPONENTS Extract ERP component features within ROI windows.
%
%   components = extract_erp_components(erp, time_vec, roi_windows)
%
%   Inputs:
%       erp         - channels x time ERP matrix
%       time_vec    - time vector in seconds
%       roi_windows - struct array with fields: name, t_start, t_end
%
%   Outputs:
%       components - struct array with fields: name, peak_amp, peak_latency,
%                    mean_amp (each n_channels x 1)

    n_channels = size(erp, 1);
    n_rois = numel(roi_windows);

    components = struct('name', {}, 'peak_amp', {}, 'peak_latency', {}, 'mean_amp', {});

    for r = 1:n_rois
        roi = roi_windows(r);
        idx = time_vec >= roi.t_start & time_vec <= roi.t_end;
        roi_time = time_vec(idx);

        comp.name = roi.name;
        comp.peak_amp = zeros(n_channels, 1);
        comp.peak_latency = zeros(n_channels, 1);
        comp.mean_amp = zeros(n_channels, 1);

        for ch = 1:n_channels
            erp_roi = erp(ch, idx);
            [max_val, max_idx] = max(abs(erp_roi));
            comp.peak_amp(ch) = erp_roi(max_idx);
            comp.peak_latency(ch) = roi_time(max_idx);
            comp.mean_amp(ch) = mean(erp_roi);
        end

        components = [components; comp]; %#ok<AGROW>
    end
end
