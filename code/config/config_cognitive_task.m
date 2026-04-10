function cfg = config_cognitive_task()
% CONFIG_COGNITIVE_TASK Configuration for cognitive task experiments.
%
%   cfg = config_cognitive_task() returns configuration with
%   parameters optimized for cognitive task SEEG paradigms.

    cfg = default_config();

    cfg.epoch_pre = 1.0;
    cfg.epoch_post = 2.0;
    cfg.stim_mask_duration = 0;
    cfg.artifact_threshold = 500;
    cfg.paradigm = 'cognitive_task';
end
