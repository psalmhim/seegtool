function summary = find_significant_contact_channels(result_file, varargin)
% FIND_SIGNIFICANT_CONTACT_CHANNELS Extract significant contact names from contrast results.
%
%   summary = find_significant_contact_channels(result_file)
%   summary = find_significant_contact_channels(..., 'alpha', 0.05)
%   summary = find_significant_contact_channels(..., 'mode', 'auto')
%
%   Supports two result types:
%     1. Within-task contrast results: stage14b_contrasts.mat
%     2. Cross-task contrast results:  cross_task_results.mat
%
%   For within-task results, significance is derived from
%   contrast_results(ci).permutation.p_values, using any(channel,time)
%   p < alpha to flag a contact.
%
%   For cross-task results, significance is derived from
%   cross_results(ci).p_channel, using any(channel,time) p < alpha.
%
%   Output:
%       summary - struct array with fields:
%         .contrast_name
%         .result_type
%         .global_significant
%         .global_p
%         .n_sig_contacts
%         .sig_contacts

    p = inputParser;
    addParameter(p, 'alpha', 0.05);
    addParameter(p, 'mode', 'auto'); % auto | within_task | cross_task
    parse(p, varargin{:});

    alpha = p.Results.alpha;
    mode = lower(string(p.Results.mode));

    if ~isfile(result_file)
        error('find_significant_contact_channels:notFound', ...
            'Result file not found: %s', result_file);
    end

    s = load(result_file);

    if mode == "auto"
        if isfield(s, 'contrast_results')
            mode = "within_task";
        elseif isfield(s, 'cross_results')
            mode = "cross_task";
        else
            error('find_significant_contact_channels:unknownFormat', ...
                'Could not infer result type from %s', result_file);
        end
    end

    switch mode
        case "within_task"
            summary = extract_within_task(s, alpha);
        case "cross_task"
            summary = extract_cross_task(s, alpha);
        otherwise
            error('find_significant_contact_channels:badMode', ...
                'Unsupported mode: %s', mode);
    end
end


function summary = extract_within_task(s, alpha)
    cr_list = s.contrast_results;
    if isempty(cr_list)
        summary = struct([]);
        return;
    end

    ch_labels = {};
    if isfield(s, 'channel_labels')
        ch_labels = s.channel_labels;
    end

    summary = repmat(empty_row(), 1, numel(cr_list));
    for i = 1:numel(cr_list)
        cr = cr_list(i);

        sig_contacts = {};
        if isfield(cr, 'permutation') && isfield(cr.permutation, 'p_values') ...
                && ~isempty(cr.permutation.p_values)
            p_ch = cr.permutation.p_values;
            sig_mask = any(p_ch < alpha, 2);
            sig_contacts = resolve_names(sig_mask, ch_labels);
        end

        summary(i).contrast_name = get_contrast_name(cr);
        summary(i).result_type = 'within_task';
        summary(i).global_significant = get_field_default(cr, 'significant', false);
        summary(i).global_p = get_field_default(cr, 'p_min', NaN);
        summary(i).n_sig_contacts = numel(sig_contacts);
        summary(i).sig_contacts = sig_contacts;
    end
end


function summary = extract_cross_task(s, alpha)
    cr_list = s.cross_results;
    if isempty(cr_list)
        summary = struct([]);
        return;
    end

    summary = repmat(empty_row(), 1, numel(cr_list));
    for i = 1:numel(cr_list)
        cr = cr_list(i);

        sig_contacts = {};
        if isfield(cr, 'p_channel') && ~isempty(cr.p_channel)
            sig_mask = any(cr.p_channel < alpha, 2);
            ch_labels = {};
            if isfield(cr, 'channel_labels')
                ch_labels = cr.channel_labels;
            end
            sig_contacts = resolve_names(sig_mask, ch_labels);
        elseif isfield(cr, 'sig_channel_names') && ~isempty(cr.sig_channel_names)
            sig_contacts = cr.sig_channel_names;
            if ischar(sig_contacts)
                sig_contacts = {sig_contacts};
            end
        end

        summary(i).contrast_name = get_field_default(cr, 'name', sprintf('contrast_%d', i));
        summary(i).result_type = 'cross_task';
        summary(i).global_significant = get_field_default(cr, 'significant', false);
        summary(i).global_p = get_field_default(cr, 'p_global', NaN);
        summary(i).n_sig_contacts = numel(sig_contacts);
        summary(i).sig_contacts = sig_contacts;
    end
end


function row = empty_row()
    row = struct( ...
        'contrast_name', '', ...
        'result_type', '', ...
        'global_significant', false, ...
        'global_p', NaN, ...
        'n_sig_contacts', 0, ...
        'sig_contacts', {{}});
end


function name = get_contrast_name(cr)
    name = '';
    if isfield(cr, 'contrast') && isstruct(cr.contrast) && isfield(cr.contrast, 'name')
        name = cr.contrast.name;
    end
    if isempty(name)
        name = get_field_default(cr, 'name', 'unnamed_contrast');
    end
end


function val = get_field_default(s, field_name, default_val)
    if isfield(s, field_name)
        val = s.(field_name);
    else
        val = default_val;
    end
end


function names = resolve_names(sig_mask, ch_labels)
    idx = find(sig_mask(:));
    if isempty(idx)
        names = {};
        return;
    end

    if ~isempty(ch_labels) && numel(ch_labels) >= max(idx)
        names = ch_labels(idx);
        if ischar(names)
            names = {names};
        end
    else
        names = arrayfun(@(k) sprintf('ch%d', k), idx, 'UniformOutput', false);
    end
end
