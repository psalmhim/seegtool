function itpc = compute_itpc(tf_phase)
% COMPUTE_ITPC Compute inter-trial phase coherence.
%
%   itpc = compute_itpc(tf_phase)
%
%   ITPC(t,f) = |1/N * sum_k(exp(i*phi_k(t,f)))|
%
%   Inputs:
%       tf_phase - trials x channels x freqs x time (phase in radians)
%
%   Outputs:
%       itpc - channels x freqs x time (values 0 to 1)

    n_trials = size(tf_phase, 1);
    itpc = squeeze(abs(mean(exp(1i * tf_phase), 1)));
end
