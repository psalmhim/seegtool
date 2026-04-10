function cfg = config_latent_dynamics()
% CONFIG_LATENT_DYNAMICS Configuration for latent dynamics analysis.
%
%   cfg = config_latent_dynamics() returns configuration with
%   parameters optimized for latent neural trajectory analysis.

    cfg = default_config();

    cfg.n_latent_dims = 10;
    cfg.smooth_kernel_ms = 30;
    cfg.n_bootstrap = 1000;
    cfg.latent_method = 'gpfa';
end
