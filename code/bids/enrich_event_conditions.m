function events = enrich_event_conditions(stim_events, all_events, task_name)
% ENRICH_EVENT_CONDITIONS Enrich stimulus event conditions using behavioral data.
%
%   events = enrich_event_conditions(stim_events, all_events, task_name)
%
%   For each stimulus event, finds the matching trial in all_events and
%   extracts meaningful condition labels based on the task.

    events = stim_events;
    all_onsets = [all_events.onset];

    for i = 1:numel(events)
        onset = events(i).onset;
        [~, match_idx] = min(abs(all_onsets - onset));

        switch lower(task_name)
            case 'lexicaldecision'
                acc_val = extract_field_safe(all_events(match_idx), 'accuracy', '');
                if strcmp(acc_val, '1')
                    events(i).condition = 'correct';
                elseif strcmp(acc_val, '0')
                    events(i).condition = 'incorrect';
                else
                    events(i).condition = extract_field_safe(all_events(match_idx), 'direction', 'stimulus');
                end

            case 'shapecontrol'
                acc_val = extract_field_safe(all_events(match_idx), 'accuracy', '');
                if strcmp(acc_val, '1')
                    events(i).condition = 'correct';
                elseif strcmp(acc_val, '0')
                    events(i).condition = 'incorrect';
                else
                    events(i).condition = 'stimulus';
                end

            case {'sentencenoun', 'sentencegrammar'}
                acc_val = extract_field_safe(all_events(match_idx), 'accuracy', '');
                if strcmp(acc_val, '1')
                    events(i).condition = 'correct';
                elseif strcmp(acc_val, '0')
                    events(i).condition = 'incorrect';
                else
                    events(i).condition = 'stimulus';
                end

            case 'saliencepain'
                events(i).condition = extract_field_safe(all_events(match_idx), 'Pain', 'stimulus');

            case 'balloonwatching'
                events(i).condition = extract_field_safe(all_events(match_idx), 'condition', 'stimulus');

            case 'viseme'
                events(i).condition = extract_field_safe(all_events(match_idx), 'viseme_category', 'stimulus');

            case 'visemegen'
                events(i).condition = extract_field_safe(all_events(match_idx), 'stimulus_type', 'stimulus');

            case 'visualrhythm'
                events(i).condition = extract_field_safe(all_events(match_idx), 'condition_name', 'stimulus');

            otherwise
                events(i).condition = 'stimulus';
        end
    end
end


function val = extract_field_safe(event_struct, field_name, default_val)
% Safely extract a field value from an event struct.
    if isfield(event_struct, field_name)
        val = event_struct.(field_name);
        if iscell(val)
            val = val{1};
        elseif isnumeric(val)
            val = sprintf('%g', val);
        end
        if isempty(val) || strcmp(val, 'n/a')
            val = default_val;
        end
    else
        val = default_val;
    end
end
