#!/usr/bin/env python3
"""
Create BIDS sidecar files: channels.tsv, electrodes.tsv, coordsystem.json, ieeg.json
for all ieeg sessions.
"""

import json
import yaml
import pandas as pd
import mne
from pathlib import Path

import utils


def create_channels_tsv(vhdr_path, output_path):
    """Create channels.tsv from a BrainVision file header."""
    raw = mne.io.read_raw_brainvision(str(vhdr_path), preload=False, verbose=False)

    rows = []
    for ch_name in raw.ch_names:
        # Determine channel type
        if ch_name == 'TRIG':
            ch_type = 'TRIG'
            units = 'n/a'
            group = 'TRIG'
            status = 'good'
        elif ch_name.startswith('EKG') or ch_name.startswith('ECG'):
            ch_type = 'ECG'
            units = 'uV'
            group = 'ECG'
            status = 'good'
        else:
            ch_type = 'SEEG'
            units = 'V'
            # Extract group (electrode shaft) from name
            # e.g., OF1 → OF, la1 → la, H1 → H, OF_Rt1 → OF_Rt
            name = ch_name
            # Remove trailing digits
            i = len(name) - 1
            while i >= 0 and name[i].isdigit():
                i -= 1
            group = name[:i + 1].rstrip('_')
            if not group:
                group = ch_name
            status = 'good'

        rows.append({
            'name': ch_name,
            'type': ch_type,
            'units': units,
            'low_cutoff': 'n/a',
            'high_cutoff': 'n/a',
            'sampling_frequency': raw.info['sfreq'],
            'group': group,
            'status': status,
            'status_description': 'n/a',
        })

    df = pd.DataFrame(rows)
    df.to_csv(output_path, sep='\t', index=False)
    return len(df)


def create_electrodes_tsv(config, output_path):
    """Create electrodes.tsv from existing elec.tsv file."""
    raw_root = Path(config['raw_data_root'])
    elec_src = raw_root / config['seeg']['electrode_file']

    elec_df = pd.read_csv(elec_src, sep='\t')

    rows = []
    for _, row in elec_df.iterrows():
        name = row['name']
        # Extract group from name (e.g., OF_1 → OF)
        parts = name.rsplit('_', 1)
        if len(parts) == 2 and parts[1].isdigit():
            group = parts[0]
        else:
            group = name

        # Determine hemisphere from x coordinate
        x = float(row['x'])
        hemisphere = 'L' if x < 0 else 'R'

        rows.append({
            'name': name,
            'x': row['x'],
            'y': row['y'],
            'z': row['z'],
            'size': row.get('size', 'n/a'),
            'group': group,
            'hemisphere': hemisphere,
            'type': 'depth',
        })

    df = pd.DataFrame(rows)
    df.to_csv(output_path, sep='\t', index=False)
    return len(df)


def create_coordsystem_json(config, output_path):
    """Create coordsystem.json for electrode coordinates."""
    seeg_cfg = config['seeg']
    coordsystem = {
        "iEEGCoordinateSystem": seeg_cfg['coordinate_system'],
        "iEEGCoordinateSystemDescription": seeg_cfg['coordinate_system_description'],
        "iEEGCoordinateUnits": seeg_cfg['coordinate_units'],
        "iEEGCoordinateProcessingDescription": "Post-implant CT registered to pre-op T1w MRI, electrode contacts localized using custom pipeline",
        "iEEGCoordinateProcessingReference": "n/a",
    }
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(coordsystem, f, indent=2, ensure_ascii=False)


def _get_task_descriptions(config):
    """Get task descriptions from config, falling back to empty string."""
    return config.get('task_descriptions', {})


def create_ieeg_json(config, ses_key, task_cfg, output_path,
                     recording_duration=None, channels_tsv_path=None):
    """Create ieeg.json sidecar for a specific task run."""
    seeg_cfg = config['seeg']
    bids_task = task_cfg['bids_task']
    task_descs = _get_task_descriptions(config)

    # Dynamically count channels from channels.tsv if available
    ch_counts = {"SEEG": 0, "ECG": 0, "TRIG": 0, "ECOG": 0, "EEG": 0, "EOG": 0, "EMG": 0}
    if channels_tsv_path and Path(channels_tsv_path).exists():
        ch_df = pd.read_csv(channels_tsv_path, sep='\t')
        if 'type' in ch_df.columns:
            for ch_type in ch_df['type']:
                ch_type_upper = str(ch_type).upper()
                if ch_type_upper in ch_counts:
                    ch_counts[ch_type_upper] += 1
                elif ch_type_upper == 'MISC':
                    ch_counts['TRIG'] += 1

    sidecar = {
        "TaskName": bids_task,
        "TaskDescription": task_descs.get(bids_task, ""),
        "InstitutionName": "Yonsei University Health System (Severance Hospital)",
        "InstitutionAddress": "Seoul, South Korea",
        "Manufacturer": seeg_cfg['manufacturer'],
        "ManufacturersModelName": seeg_cfg['manufacturer_model'],
        "SamplingFrequency": seeg_cfg['sampling_rate'],
        "PowerLineFrequency": seeg_cfg['power_line_frequency'],
        "SoftwareFilters": "n/a",
        "RecordingType": "continuous",
        "iEEGReference": seeg_cfg['reference'],
        "iEEGPlacementScheme": "Clinical indication for epilepsy monitoring",
        "SEEGChannelCount": ch_counts["SEEG"],
        "ECGChannelCount": ch_counts["ECG"],
        "TriggerChannelCount": ch_counts["TRIG"],
        "ECOGChannelCount": ch_counts["ECOG"],
        "EEGChannelCount": ch_counts["EEG"],
        "EOGChannelCount": ch_counts["EOG"],
        "EMGChannelCount": ch_counts["EMG"],
        "ElectricalStimulationParameters": "n/a",
    }

    if recording_duration is not None:
        sidecar["RecordingDuration"] = round(recording_duration, 1)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(sidecar, f, indent=2, ensure_ascii=False)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=str, default=None)
    args = parser.parse_args()

    config_path = args.config or utils.get_config_path()
    config = utils.load_config(config_path)
    bids_root = utils.get_bids_root()

    sub = config['participant_id']

    # Load segment info for recording durations
    segment_info_path = bids_root / 'code' / 'segment_info.json'
    with open(segment_info_path) as f:
        segment_info = json.load(f)

    print(f"Creating sidecar files for {sub}")

    # Process each ieeg session
    for ses_key, ses_cfg in config['sessions'].items():
        if 'ieeg' not in ses_cfg.get('modalities', []):
            continue

        ses_dir = bids_root / sub / ses_key / 'ieeg'
        if not ses_dir.exists():
            continue

        print(f"\n--- {ses_key} ---")

        # Find existing .vhdr files in this session
        vhdr_files = sorted(ses_dir.glob('*.vhdr'))
        if not vhdr_files:
            print(f"  No .vhdr files found, skipping")
            continue

        # Create channels.tsv for each run (same for all runs in a session)
        for vhdr_path in vhdr_files:
            channels_path = vhdr_path.with_name(
                vhdr_path.name.replace('_ieeg.vhdr', '_channels.tsv'))
            n_ch = create_channels_tsv(vhdr_path, channels_path)
            print(f"  {channels_path.name}: {n_ch} channels")

        # Create electrodes.tsv (session-level, shared across runs)
        elec_path = ses_dir / f'{sub}_{ses_key}_electrodes.tsv'
        n_elec = create_electrodes_tsv(config, elec_path)
        print(f"  {elec_path.name}: {n_elec} electrodes")

        # Create coordsystem.json
        coord_path = ses_dir / f'{sub}_{ses_key}_coordsystem.json'
        create_coordsystem_json(config, coord_path)
        print(f"  {coord_path.name}")

        # Create ieeg.json for each task run
        for task_cfg in ses_cfg.get('tasks', []):
            if task_cfg.get('exclude'):
                continue
            bids_task = task_cfg['bids_task']
            run = task_cfg['run']
            prefix = f'{sub}_{ses_key}_task-{bids_task}_run-{run:02d}'
            json_path = ses_dir / f'{prefix}_ieeg.json'
            channels_path = ses_dir / f'{prefix}_channels.tsv'

            # Get recording duration from segment info
            seg_key = f'{ses_key}/{bids_task}/run-{run:02d}'
            seg = segment_info.get(seg_key, {})
            duration = None
            if 'segment_start_sec' in seg and 'segment_end_sec' in seg:
                duration = seg['segment_end_sec'] - seg['segment_start_sec']

            create_ieeg_json(config, ses_key, task_cfg, json_path, duration,
                             channels_tsv_path=channels_path)
            print(f"  {json_path.name}")

    print("\nSidecar generation complete!")


if __name__ == '__main__':
    main()
