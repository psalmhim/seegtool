function cleaned = remove_line_noise(data, fs, line_freq, n_harmonics)
% REMOVE_LINE_NOISE Remove line noise and harmonics using notch filters.
%
%   cleaned = remove_line_noise(data, fs, line_freq, n_harmonics)
%
%   Inputs:
%       data        - channels x time matrix
%       fs          - sampling rate (Hz)
%       line_freq   - fundamental line noise frequency (Hz), e.g. 50 or 60
%       n_harmonics - number of harmonics to remove (default: 3)
%
%   Outputs:
%       cleaned - filtered data with line noise removed

    if nargin < 3 || isempty(line_freq)
        line_freq = 60;
    end
    if nargin < 4 || isempty(n_harmonics)
        n_harmonics = 3;
    end

    cleaned = double(data);
    notch_bw = 2;

    for h = 1:n_harmonics
        freq = line_freq * h;
        if freq >= fs / 2
            break;
        end

        Wn = [(freq - notch_bw / 2), (freq + notch_bw / 2)] / (fs / 2);
        Wn = max(Wn, 1e-6);
        Wn = min(Wn, 1 - 1e-6);

        [b, a] = butter(2, Wn, 'stop');

        for ch = 1:size(cleaned, 1)
            cleaned(ch, :) = filtfilt(b, a, cleaned(ch, :));
        end
    end
end
