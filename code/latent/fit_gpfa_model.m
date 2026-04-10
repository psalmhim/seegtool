function model = fit_gpfa_model(trial_data, n_dims)
% FIT_GPFA_MODEL Fit Gaussian Process Factor Analysis model.
%
%   model = fit_gpfa_model(trial_data, n_dims)
%
%   Simplified GPFA: PCA + GP smoothing of latent trajectories.
%
%   Inputs:
%       trial_data - cell array, each cell is channels x time for one trial
%       n_dims     - number of latent dimensions
%
%   Outputs:
%       model - struct with W, timescales, noise_var, mean_vec

    % Concatenate all trials for PCA
    all_data = horzcat(trial_data{:});
    pca_model = fit_pca_model(all_data, n_dims);

    model.W = pca_model.W;
    model.mean_vec = pca_model.mean_vec;
    model.eigenvalues = pca_model.eigenvalues;
    model.explained_variance = pca_model.explained_variance;

    % Estimate GP timescales from latent trajectories
    model.timescales = zeros(n_dims, 1);
    for d = 1:n_dims
        autocorr_vals = [];
        for k = 1:numel(trial_data)
            centered = trial_data{k} - model.mean_vec;
            z_d = model.W(:, d)' * centered;
            ac = xcorr(z_d - mean(z_d), 'normalized');
            ac = ac(ceil(end/2):end);
            autocorr_vals = [autocorr_vals; ac(:)']; %#ok<AGROW>
        end
        mean_ac = mean(autocorr_vals, 1);
        decay_idx = find(mean_ac < exp(-1), 1);
        if isempty(decay_idx)
            decay_idx = length(mean_ac);
        end
        model.timescales(d) = decay_idx;
    end

    % Estimate noise variance
    model.noise_var = mean(pca_model.eigenvalues(n_dims+1:end));
    model.n_dims = n_dims;
    model.method = 'gpfa';
end
