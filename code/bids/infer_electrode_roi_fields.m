function roi_info = infer_electrode_roi_fields(electrodes)
% INFER_ELECTRODE_ROI_FIELDS Extract electrode shaft and contact info from labels.
%
%   roi_info = infer_electrode_roi_fields(electrodes)
%
%   Parses SEEG electrode labels (e.g., 'LA1', 'RH3', 'LPH12') to extract:
%       roi_info.label       - original labels
%       roi_info.shaft_name  - electrode shaft prefix (e.g., 'LA', 'RH')
%       roi_info.contact_num - contact number along the shaft
%       roi_info.hemisphere  - 'L', 'R', or 'U' (unknown)
%       roi_info.unique_shafts - unique shaft names
%       roi_info.shaft_idx   - shaft index per contact

    labels = electrodes.label;
    n = numel(labels);

    shaft_name = cell(n, 1);
    contact_num = zeros(n, 1);
    hemisphere = cell(n, 1);

    for i = 1:n
        lbl = strtrim(labels{i});

        % Parse: letters followed by digits
        tok = regexp(lbl, '^([A-Za-z]+)(\d+)$', 'tokens');
        if ~isempty(tok)
            shaft_name{i} = upper(tok{1}{1});
            contact_num(i) = str2double(tok{1}{2});
        else
            shaft_name{i} = upper(lbl);
            contact_num(i) = 0;
        end

        % Infer hemisphere from first character
        if ~isempty(shaft_name{i})
            first_char = shaft_name{i}(1);
            if first_char == 'L'
                hemisphere{i} = 'L';
            elseif first_char == 'R'
                hemisphere{i} = 'R';
            else
                hemisphere{i} = 'U';
            end
        else
            hemisphere{i} = 'U';
        end
    end

    unique_shafts = unique(shaft_name, 'stable');
    shaft_idx = zeros(n, 1);
    for i = 1:numel(unique_shafts)
        mask = strcmp(shaft_name, unique_shafts{i});
        shaft_idx(mask) = i;
    end

    roi_info.label = labels;
    roi_info.shaft_name = shaft_name;
    roi_info.contact_num = contact_num;
    roi_info.hemisphere = hemisphere;
    roi_info.unique_shafts = unique_shafts;
    roi_info.shaft_idx = shaft_idx;
end
