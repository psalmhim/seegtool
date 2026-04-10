function norm_tensor = normalize_population_tensor(pop_tensor, method)
% NORMALIZE_POPULATION_TENSOR Normalize population tensor per channel.
%
%   norm_tensor = normalize_population_tensor(pop_tensor, method)
%
%   Inputs:
%       pop_tensor - trials x channels x time
%       method     - 'zscore' (default), 'soft_normalize', 'range'
%
%   Outputs:
%       norm_tensor - normalized tensor, same size

    if nargin < 2, method = 'zscore'; end

    [n_trials, n_channels, n_time] = size(pop_tensor);
    norm_tensor = zeros(size(pop_tensor));

    for ch = 1:n_channels
        % Concatenate all trials for this channel
        ch_data = squeeze(pop_tensor(:, ch, :));
        all_vals = ch_data(:);

        switch lower(method)
            case 'zscore'
                mu = mean(all_vals, 'omitnan');
                sigma = std(all_vals, 'omitnan');
                if sigma == 0 || isnan(sigma), sigma = 1; end
                norm_tensor(:, ch, :) = (ch_data - mu) / sigma;

            case 'soft_normalize'
                range_val = max(abs(all_vals), [], 'omitnan');
                if range_val == 0 || isnan(range_val), range_val = 1; end
                norm_tensor(:, ch, :) = ch_data / (range_val + 5);

            case 'range'
                min_val = min(all_vals, [], 'omitnan');
                max_val = max(all_vals, [], 'omitnan');
                range_val = max_val - min_val;
                if range_val == 0 || isnan(range_val), range_val = 1; end
                norm_tensor(:, ch, :) = (ch_data - min_val) / range_val;

            otherwise
                error('normalize_population_tensor:invalidMethod', 'Unknown method: %s', method);
        end
    end
end
