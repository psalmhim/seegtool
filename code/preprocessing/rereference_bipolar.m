function [bipolar_data, bipolar_labels, bipolar_valid] = rereference_bipolar(data, channel_labels, valid_channels)
% REREFERENCE_BIPOLAR Compute bipolar derivations from adjacent contacts.
%
%   [bipolar_data, bipolar_labels] = rereference_bipolar(data, channel_labels)
%
%   Computes: x_i^bip(t) = x_i(t) - x_{i+1}(t) for adjacent contacts
%   on the same electrode shaft.
%
%   Inputs:
%       data           - channels x time matrix
%       channel_labels - cell array of channel name strings (e.g., {'A1','A2','B1','B2','B3'})
%
%   Outputs:
%       bipolar_data   - bipolar channels x time matrix
%       bipolar_labels - cell array of bipolar channel labels (e.g., 'A1-A2')

    n_channels = size(data, 1);
    if nargin < 2 || isempty(channel_labels)
        channel_labels = arrayfun(@(k) sprintf('Ch%d', k), 1:n_channels, 'UniformOutput', false);
    end
    if nargin < 3 || isempty(valid_channels)
        valid_channels = true(n_channels, 1);
    end

    % Parse electrode names and contact numbers
    electrode_names = cell(n_channels, 1);
    contact_numbers = zeros(n_channels, 1);
    for i = 1:n_channels
        label = channel_labels{i};
        tokens = regexp(label, '^([A-Za-z'']+)(\d+)$', 'tokens');
        if ~isempty(tokens)
            electrode_names{i} = tokens{1}{1};
            contact_numbers(i) = str2double(tokens{1}{2});
        else
            electrode_names{i} = label;
            contact_numbers(i) = i;
        end
    end

    % Find unique electrodes
    unique_electrodes = unique(electrode_names, 'stable');

    bipolar_data_cell = {};
    bipolar_labels = {};
    bipolar_valid = [];

    for e = 1:numel(unique_electrodes)
        elec_name = unique_electrodes{e};
        elec_idx = find(strcmp(electrode_names, elec_name));

        % Sort by contact number
        [~, sort_order] = sort(contact_numbers(elec_idx));
        elec_idx = elec_idx(sort_order);

        % Compute bipolar pairs
        for p = 1:numel(elec_idx) - 1
            idx1 = elec_idx(p);
            idx2 = elec_idx(p + 1);
            if ~(valid_channels(idx1) && valid_channels(idx2))
                continue;
            end
            bipolar_data_cell{end + 1} = data(idx1, :) - data(idx2, :); %#ok<AGROW>
            bipolar_labels{end + 1} = sprintf('%s-%s', channel_labels{idx1}, channel_labels{idx2}); %#ok<AGROW>
            bipolar_valid(end + 1, 1) = true; %#ok<AGROW>
        end
    end

    if isempty(bipolar_data_cell)
        bipolar_data = [];
        bipolar_labels = {};
        bipolar_valid = false(0, 1);
    else
        bipolar_data = cell2mat(bipolar_data_cell(:));
        bipolar_labels = bipolar_labels(:);
    end
end
