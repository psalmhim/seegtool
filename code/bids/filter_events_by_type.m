function stim_events = filter_events_by_type(events, event_type)
% FILTER_EVENTS_BY_TYPE Filter events to keep only the specified trial_type.
%
%   stim_events = filter_events_by_type(events, event_type)

    if isempty(events)
        stim_events = struct([]);
        return;
    end
    if isfield(events, 'trial_type')
        mask = strcmp({events.trial_type}, event_type);
    else
        mask = strcmp({events.condition}, event_type);
    end
    stim_events = events(mask);
end
