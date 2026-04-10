function table_out = build_feature_table(features, trial_labels, condition_labels)
% BUILD_FEATURE_TABLE Build structured feature table with metadata.
%
%   table_out = build_feature_table(features, trial_labels, condition_labels)
%
%   Inputs:
%       features         - struct with feature arrays
%       trial_labels     - cell array of trial quality labels
%       condition_labels - cell array of condition names per trial
%
%   Outputs:
%       table_out - struct with data matrix, feature_names, trial_ids, conditions

    table_out = struct();
    table_out.trial_labels = trial_labels;
    table_out.condition_labels = condition_labels;
    table_out.trial_ids = (1:numel(trial_labels))';

    data_cols = {};
    feat_names = {};

    band_names = fieldnames(features.band_features);
    for b = 1:numel(band_names)
        band_data = features.band_features.(band_names{b});
        n_trials = size(band_data, 1);
        n_channels = size(band_data, 2);
        n_time = size(band_data, 3);
        flat = reshape(band_data, n_trials, []);
        data_cols{end + 1} = flat; %#ok<AGROW>
        for ch = 1:n_channels
            for t = 1:n_time
                feat_names{end + 1} = sprintf('%s_ch%d_t%d', band_names{b}, ch, t); %#ok<AGROW>
            end
        end
    end

    table_out.data = horzcat(data_cols{:});
    table_out.feature_names = feat_names;
end
