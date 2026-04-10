function pop_tensor = build_population_tensor(trial_tensor, feature_type)
% BUILD_POPULATION_TENSOR Build population activity tensor from trial data.
%
%   pop_tensor = build_population_tensor(trial_tensor, feature_type)
%
%   Inputs:
%       trial_tensor - trials x channels x time
%       feature_type - 'voltage' (default), 'hfa', or 'band_power'
%
%   Outputs:
%       pop_tensor - trials x channels x time

    if nargin < 2, feature_type = 'voltage'; end

    switch lower(feature_type)
        case 'voltage'
            pop_tensor = trial_tensor;
        case 'hfa'
            pop_tensor = trial_tensor;
        case 'band_power'
            pop_tensor = trial_tensor;
        otherwise
            error('build_population_tensor:invalidType', 'Unknown feature type: %s', feature_type);
    end
end
