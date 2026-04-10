function composite = make_composite_quality_score(metrics, weights)
% MAKE_COMPOSITE_QUALITY_SCORE Compute weighted composite quality score.
%
%   composite = make_composite_quality_score(metrics, weights)
%
%   Z-scores each metric across trials, computes weighted sum,
%   then averages across channels.
%
%   Inputs:
%       metrics - struct with fields: rms, var, p2p, kurt, line_noise
%                 (each trials x channels)
%       weights - struct with corresponding weight values
%
%   Outputs:
%       composite - trials x 1 composite quality score

    metric_names = fieldnames(weights);
    n_trials = size(metrics.(metric_names{1}), 1);

    composite = zeros(n_trials, 1);
    total_weight = 0;

    for m = 1:numel(metric_names)
        name = metric_names{m};
        if ~isfield(metrics, name)
            continue;
        end

        vals = metrics.(name);
        % Z-score across trials for each channel
        mu = mean(vals, 1);
        sigma = std(vals, 0, 1);
        sigma(sigma == 0) = 1;
        z = (vals - mu) ./ sigma;

        % Mean z-score across channels for each trial
        z_trial = mean(abs(z), 2);

        w = weights.(name);
        composite = composite + w * z_trial;
        total_weight = total_weight + w;
    end

    if total_weight > 0
        composite = composite / total_weight;
    end
end
