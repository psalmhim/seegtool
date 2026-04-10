Since your SEEG data are in **Brain Imaging Data Structure (BIDS) format**, the correct approach is to build a **BIDS-aware loader layer** before the analysis pipeline.
This layer will read:

- `participants.tsv`
- `electrodes.tsv`
- `events.tsv`
- `channels.tsv`
- `*_ieeg.(edf|vhdr|set|fif|mat)`
- optional `coordsystem.json`

and convert them into the **internal MATLAB structures** used by the pipeline.

Below is the **recommended architecture and working MATLAB code**.

------

# 1. New Folder in the Toolbox

Add a new module:

```
code/bids/
code/bids/
    load_bids_dataset.m
    load_bids_ieeg_file.m
    load_bids_events.m
    load_bids_electrodes.m
    load_bids_channels.m
    build_seeg_raw_struct.m
```

This layer converts BIDS → pipeline format.

------

# 2. BIDS Loader Entry Function

```
code/bids/load_bids_dataset.m
function [raw, events, electrodes, channels] = load_bids_dataset(bids_root, subject, session)

sub_dir = fullfile(bids_root, sprintf('sub-%s', subject));

if nargin > 2 && ~isempty(session)
    sub_dir = fullfile(sub_dir, sprintf('ses-%s', session));
end

ieeg_dir = fullfile(sub_dir, 'ieeg');

%% find recording file

files = dir(fullfile(ieeg_dir, '*ieeg.*'));

if isempty(files)
    error('No ieeg file found in BIDS dataset');
end

datafile = fullfile(files(1).folder, files(1).name);

%% load signal

raw = load_bids_ieeg_file(datafile);

%% load events

events_file = dir(fullfile(ieeg_dir, '*events.tsv'));
events = load_bids_events(fullfile(events_file.folder, events_file.name));

%% electrodes

elec_file = dir(fullfile(ieeg_dir, '*electrodes.tsv'));
electrodes = load_bids_electrodes(fullfile(elec_file.folder, elec_file.name));

%% channels

chan_file = dir(fullfile(ieeg_dir, '*channels.tsv'));
channels = load_bids_channels(fullfile(chan_file.folder, chan_file.name));

%% attach metadata

raw.electrodes = electrodes;
raw.channels = channels;

end
```

------

# 3. Load SEEG Signal File

```
load_bids_ieeg_file.m
```

Supports **EDF / BrainVision / EEGLAB**.

```matlab
function raw = load_bids_ieeg_file(filename)

[~,~,ext] = fileparts(filename);

switch lower(ext)

    case '.edf'

        hdr = edfinfo(filename);
        data = edfread(filename);

        raw.data = table2array(data)';
        raw.fs = hdr.NumSamples(1) / seconds(hdr.DataRecordDuration);
        raw.label = hdr.SignalLabels;

    case '.vhdr'

        EEG = pop_loadbv(fileparts(filename), filename);

        raw.data = EEG.data;
        raw.fs = EEG.srate;
        raw.label = {EEG.chanlocs.labels};

    case '.set'

        EEG = pop_loadset(filename);

        raw.data = EEG.data;
        raw.fs = EEG.srate;
        raw.label = {EEG.chanlocs.labels};

    otherwise
        error('Unsupported file format')

end

end
```

------

# 4. Load Events.tsv

```
load_bids_events.m
function events = load_bids_events(file)

T = readtable(file,'FileType','text','Delimiter','\t');

n = height(T);

for k = 1:n

    events(k).sample = round(T.onset(k) * T.sample_rate(k));
    events(k).onset = T.onset(k);
    events(k).duration = T.duration(k);

    if ismember('trial_type', T.Properties.VariableNames)
        events(k).condition = T.trial_type{k};
    else
        events(k).condition = 'event';
    end

    events(k).type = 'stim';

end

end
```

------

# 5. Load Electrodes.tsv

This is **important for SEEG anatomical analysis**.

```
load_bids_electrodes.m
function electrodes = load_bids_electrodes(file)

T = readtable(file,'FileType','text','Delimiter','\t');

electrodes.label = T.name;
electrodes.x = T.x;
electrodes.y = T.y;
electrodes.z = T.z;

if ismember('size',T.Properties.VariableNames)
    electrodes.size = T.size;
end

end
```

------

# 6. Load Channels.tsv

```
load_bids_channels.m
function channels = load_bids_channels(file)

T = readtable(file,'FileType','text','Delimiter','\t');

channels.name = T.name;
channels.type = T.type;
channels.status = T.status;

end
```

------

# 7. Convert to Internal Pipeline Structure

```
build_seeg_raw_struct.m
function raw = build_seeg_raw_struct(data, electrodes, channels)

raw.data = data.data;
raw.fs = data.fs;
raw.label = data.label;

raw.electrodes = electrodes;
raw.channels = channels;

end
```

------

# 8. Example Usage

```matlab
bids_root = '/data/seeg_bids';

[raw, events, electrodes, channels] = ...
    load_bids_dataset(bids_root, '01', '01');

cfg = default_config();

R = run_seeg_pipeline(raw, events, cfg);
```

------

# 9. Why This Matters for Your Analysis

Because **SEEG trajectory analysis requires anatomical mapping**.

Using BIDS metadata allows:

### electrode anatomy

```
electrodes.tsv
```

→ ROI grouping

```
Hippocampus
Amygdala
OFC
Insula
```

### event condition separation

```
events.tsv
trial_type
response_time
stim_type
```

→ condition trajectories

### channel filtering

```
channels.tsv
status = bad
```

→ automatic removal

------

# 10. Recommended Additional Features

You will likely want:

### ROI-based latent trajectories

```
HPC latent dynamics
PFC latent dynamics
```

### anatomical trajectory mapping

```
trajectory per brain region
```

### stimulation artifact masking

```
events.tsv
stim_onset
```

------

# generate

1️⃣ **Complete MATLAB BIDS loader module**
2️⃣ **Automatic ROI grouping using electrodes.tsv**
3️⃣ **SEEG atlas mapping (AAL / Destrieux / FreeSurfer)**
4️⃣ **trajectory analysis per brain region**



Add

- `code/bids/`
  - `load_bids_dataset.m`
  - `load_bids_ieeg_file.m`
  - `load_bids_events.m`
  - `load_bids_electrodes.m`
  - `load_bids_channels.m`
  - `build_seeg_raw_struct.m`
  - `apply_bids_channel_status.m`
  - `infer_electrode_roi_fields.m`
  - `map_electrodes_to_atlas.m`
  - `load_simple_atlas_mat.m`
- ROI grouping:
  - `build_roi_groups.m`
- ROI latent analysis:
  - `run_roi_latent_analysis.m`
  - `plot_roi_trajectory_summary.m`
- BIDS demo:
  - `demo_bids_loader_example.m`
- BIDS test:
  - `tests/test_bids_struct_parsing.m`

Two practical notes:

- BrainVision `.vhdr` and EEGLAB `.set` loading still require EEGLAB on the MATLAB path.
- Atlas mapping is included as a scaffold using nearest-neighbor coordinate matching; it is ready to adapt to your actual atlas workflow.