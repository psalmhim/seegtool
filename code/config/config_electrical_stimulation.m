function cfg = config_electrical_stimulation()
% CONFIG_ELECTRICAL_STIMULATION Configuration for electrical stimulation experiments.
%
%   cfg = config_electrical_stimulation() returns configuration with
%   parameters optimized for SEEG electrical stimulation paradigms.

    cfg = default_config();

    cfg.epoch_pre = 0.5;
    cfg.epoch_post = 1.5;
    cfg.stim_mask_duration = 0.01;
    cfg.artifact_threshold = 300;
    cfg.paradigm = 'electrical_stimulation';
end
