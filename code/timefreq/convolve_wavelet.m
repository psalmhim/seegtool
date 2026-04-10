function analytic_signal = convolve_wavelet(signal, wavelet)
% CONVOLVE_WAVELET FFT-based convolution of signal with wavelet.
%
%   analytic_signal = convolve_wavelet(signal, wavelet)
%
%   Inputs:
%       signal  - 1 x T signal vector
%       wavelet - 1 x W complex wavelet
%
%   Outputs:
%       analytic_signal - 1 x T complex analytic signal

    n_signal = length(signal);
    n_wavelet = length(wavelet);
    n_conv = n_signal + n_wavelet - 1;
    nfft = 2^nextpow2(n_conv);

    signal_fft = fft(signal, nfft);
    wavelet_fft = fft(wavelet, nfft);

    conv_result = ifft(signal_fft .* wavelet_fft, nfft);

    half_wav = floor(n_wavelet / 2);
    analytic_signal = conv_result(half_wav + 1 : half_wav + n_signal);
end
