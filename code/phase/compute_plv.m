function plv = compute_plv(tf_phase, chan_i, chan_j)
% COMPUTE_PLV Compute phase locking value between two channels.
%
%   plv = compute_plv(tf_phase, chan_i, chan_j)
%
%   PLV(t,f) = |1/N * sum_k(exp(i*(phi_i_k - phi_j_k)))|
%
%   Inputs:
%       tf_phase - trials x channels x freqs x time (phase in radians)
%       chan_i    - index of first channel
%       chan_j    - index of second channel
%
%   Outputs:
%       plv - freqs x time matrix (values 0 to 1)

    phase_diff = tf_phase(:, chan_i, :, :) - tf_phase(:, chan_j, :, :);
    plv = squeeze(abs(mean(exp(1i * phase_diff), 1)));
end
