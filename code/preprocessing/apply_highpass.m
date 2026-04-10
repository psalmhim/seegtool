function filtered = apply_highpass(data, fs, cutoff_freq, filter_order)
% APPLY_HIGHPASS Apply zero-phase Butterworth high-pass filter.
%
%   filtered = apply_highpass(data, fs, cutoff_freq, filter_order)
%
%   Inputs:
%       data         - channels x time matrix
%       fs           - sampling rate (Hz)
%       cutoff_freq  - high-pass cutoff frequency (Hz)
%       filter_order - Butterworth filter order (default: 4)
%
%   Outputs:
%       filtered - filtered data, same size as input

    if nargin < 4 || isempty(filter_order)
        filter_order = 4;
    end

    if ~isnumeric(data) || ~ismatrix(data)
        error('apply_highpass:invalidInput', 'data must be a 2D numeric matrix.');
    end
    if cutoff_freq <= 0 || cutoff_freq >= fs / 2
        error('apply_highpass:invalidFreq', 'cutoff_freq must be between 0 and Nyquist (%g Hz).', fs / 2);
    end

    Wn = cutoff_freq / (fs / 2);
    [b, a] = butter(filter_order, Wn, 'high');

    filtered = zeros(size(data));
    for ch = 1:size(data, 1)
        filtered(ch, :) = filtfilt(b, a, double(data(ch, :)));
    end
end
