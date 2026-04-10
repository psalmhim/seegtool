function [data_clean, good_idx, bad_labels] = apply_bids_channel_status(raw)
% APPLY_BIDS_CHANNEL_STATUS Remove bad channels based on BIDS channels.tsv status.
%
%   [data_clean, good_idx, bad_labels] = apply_bids_channel_status(raw)
%
%   Inputs:
%       raw - struct with .data, .label, .channels.status, .channels.name
%
%   Outputs:
%       data_clean - channels x samples (bad channels removed)
%       good_idx   - logical mask of good channels
%       bad_labels - cell array of removed channel labels

    if ~isfield(raw, 'channels') || ~isfield(raw.channels, 'status')
        data_clean = raw.data;
        good_idx = true(size(raw.data, 1), 1);
        bad_labels = {};
        return;
    end

    n_ch = size(raw.data, 1);
    good_idx = true(n_ch, 1);

    for i = 1:numel(raw.channels.status)
        if i > n_ch
            break;
        end
        status = raw.channels.status{i};
        if strcmpi(status, 'bad')
            % Match by name if available, otherwise by index
            if isfield(raw.channels, 'name') && numel(raw.channels.name) >= i
                ch_name = raw.channels.name{i};
                match = find(strcmp(raw.label, ch_name));
                if ~isempty(match)
                    good_idx(match(1)) = false;
                else
                    good_idx(i) = false;
                end
            else
                good_idx(i) = false;
            end
        end
    end

    bad_labels = raw.label(~good_idx);
    data_clean = raw.data(good_idx, :);

    if any(~good_idx)
        fprintf('[BIDS] Removed %d bad channels: %s\n', ...
            sum(~good_idx), strjoin(bad_labels, ', '));
    end
end
