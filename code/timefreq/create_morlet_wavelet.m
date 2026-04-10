function wavelet = create_morlet_wavelet(freq, n_cycles, fs)
% CREATE_MORLET_WAVELET Create complex Morlet wavelet.
%
%   wavelet = create_morlet_wavelet(freq, n_cycles, fs)
%
%   psi(t) = exp(2*pi*i*f*t) * exp(-t^2 / (2*sigma^2))
%   where sigma = n_cycles / (2*pi*f)
%
%   Inputs:
%       freq     - center frequency (Hz)
%       n_cycles - number of wavelet cycles
%       fs       - sampling rate (Hz)
%
%   Outputs:
%       wavelet - 1 x N complex wavelet (energy-normalized)

    sigma = n_cycles / (2 * pi * freq);
    wavelet_dur = 2 * 4 * sigma;
    t = -wavelet_dur : 1/fs : wavelet_dur;

    sine_wave = exp(2i * pi * freq * t);
    gaussian = exp(-t.^2 / (2 * sigma^2));

    wavelet = sine_wave .* gaussian;

    % Normalize to unit energy
    wavelet = wavelet / sqrt(sum(abs(wavelet).^2));
end
