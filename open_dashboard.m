%% OPEN_DASHBOARD - Launch the SEEG pipeline status dashboard
%
% Quick launcher to view processing status, results, and figures
% for subject EP01AN96M1047 across all 11 runs.
%
% Usage:
%   >> open_dashboard
%
% The dashboard opens in your default web browser as an HTML file.

% Setup paths
code_root = fileparts(mfilename('fullpath'));
addpath(fullfile(code_root, 'code'));
add_paths();

% Configuration (same as run_EP01AN96M1047_all_tasks.m)
bids_root   = '/Volumes/OHDD/DATA/epilepsy';
subject     = 'EP01AN96M1047';
results_dir = fullfile(bids_root, 'derivatives', 'seegring', ['sub-' subject]);

% Get run definitions
runs = define_all_runs();

% Generate and open dashboard
generate_dashboard(results_dir, runs, 'subject', subject, 'open', true);


%% ========================================================================
%  Helper: define_all_runs (same as in run_EP01AN96M1047_all_tasks.m)
%  ========================================================================
function runs = define_all_runs()
    runs = struct();
    idx = 0;

    idx = idx + 1;
    runs(idx).session = 'task01';
    runs(idx).task = 'lexicaldecision';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual word/nonword discrimination';

    idx = idx + 1;
    runs(idx).session = 'task02';
    runs(idx).task = 'shapecontrol';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Shape control task';

    idx = idx + 1;
    runs(idx).session = 'task03';
    runs(idx).task = 'sentencenoun';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Sentence noun comprehension';

    idx = idx + 1;
    runs(idx).session = 'task04';
    runs(idx).task = 'sentencegrammar';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Sentence grammar judgment';

    idx = idx + 1;
    runs(idx).session = 'task05';
    runs(idx).task = 'saliencepain';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Salience/pain processing';

    idx = idx + 1;
    runs(idx).session = 'task06';
    runs(idx).task = 'balloonwatching';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Balloon watching (anticipation)';

    idx = idx + 1;
    runs(idx).session = 'task08';
    runs(idx).task = 'viseme';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual speech perception run 1';

    idx = idx + 1;
    runs(idx).session = 'task08';
    runs(idx).task = 'viseme';
    runs(idx).run = '02';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual speech perception run 2';

    idx = idx + 1;
    runs(idx).session = 'task08';
    runs(idx).task = 'viseme';
    runs(idx).run = '03';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual speech perception run 3';

    idx = idx + 1;
    runs(idx).session = 'task08';
    runs(idx).task = 'visemegen';
    runs(idx).run = '01';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual speech generation';

    idx = idx + 1;
    runs(idx).session = 'task10';
    runs(idx).task = 'visualrhythm';
    runs(idx).run = '02';
    runs(idx).epoch_event = 'stimulus';
    runs(idx).description = 'Visual rhythm processing';
end
