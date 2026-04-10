function latent_tensor = project_to_latent_space(pop_tensor, model)
% PROJECT_TO_LATENT_SPACE Project population data into latent space.
%
%   latent_tensor = project_to_latent_space(pop_tensor, model)
%
%   z(t) = W' * (x(t) - mean_vec)
%
%   Inputs:
%       pop_tensor - trials x channels x time
%       model      - fitted model struct with W and mean_vec
%
%   Outputs:
%       latent_tensor - trials x n_dims x time

    [n_trials, ~, n_time] = size(pop_tensor);
    n_dims = size(model.W, 2);

    latent_tensor = zeros(n_trials, n_dims, n_time);

    for k = 1:n_trials
        x = squeeze(pop_tensor(k, :, :));
        centered = x - model.mean_vec;
        latent_tensor(k, :, :) = model.W' * centered;
    end
end
