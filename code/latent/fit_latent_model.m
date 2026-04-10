function model = fit_latent_model(pop_tensor, cfg)
% FIT_LATENT_MODEL Fit latent model (PCA, FA, or GPFA).
%
%   model = fit_latent_model(pop_tensor, cfg)
%
%   Inputs:
%       pop_tensor - trials x channels x time
%       cfg        - config struct with latent_method, n_latent_dims
%
%   Outputs:
%       model - fitted model struct

    [n_trials, n_channels, n_time] = size(pop_tensor);

    switch lower(cfg.latent_method)
        case 'pca'
            data_2d = reshape(permute(pop_tensor, [2 1 3]), n_channels, n_trials * n_time);
            model = fit_pca_model(data_2d, cfg.n_latent_dims);

        case 'fa'
            data_2d = reshape(permute(pop_tensor, [2 1 3]), n_channels, n_trials * n_time);
            model = fit_factor_analysis_model(data_2d, cfg.n_latent_dims);

        case 'gpfa'
            trial_data = cell(n_trials, 1);
            for k = 1:n_trials
                trial_data{k} = squeeze(pop_tensor(k, :, :));
            end
            model = fit_gpfa_model(trial_data, cfg.n_latent_dims);

        otherwise
            error('fit_latent_model:invalidMethod', 'Unknown method: %s', cfg.latent_method);
    end
end
