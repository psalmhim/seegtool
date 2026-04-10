#!/usr/bin/env python3
"""
Create BIDS events.tsv files by extracting annotations from split BrainVision files
and merging with PsychoPy behavioral data.

Approach:
- Read annotations from each split .vhdr file (fixation, stimuli/stim_on, response)
- Group annotations into trials
- Merge with behavioral CSV data (trial-by-trial matching)
- Output one-row-per-event BIDS events.tsv
"""

import json
import yaml
import pandas as pd
import numpy as np
import mne
from pathlib import Path

import utils

SAMPLING_RATE = 2048


def extract_annotations_from_edf(edf_path, task_start_sec, task_end_sec, segment_start_sec):
    """Extract task-relevant annotations from original EDF within task boundaries.

    Args:
        edf_path: Path to original EDF file
        task_start_sec: Task start time in original EDF
        task_end_sec: Task end time in original EDF
        segment_start_sec: Segment start time (includes buffer before task_start)

    Returns:
        DataFrame with onset relative to segment start, and sfreq
    """
    raw = mne.io.read_raw_edf(str(edf_path), preload=False, verbose=False)

    events = []
    for ann in raw.annotations:
        onset = ann['onset']
        desc = ann['description'].strip()

        # Only include events within task boundaries (with small margin)
        if onset < task_start_sec - 1 or onset > task_end_sec + 1:
            continue

        # Normalize event types across days
        event_type = None
        if desc == 'fixation':
            event_type = 'fixation'
        elif desc in ('stimuli', 'stim_on'):
            event_type = 'stimulus'
        elif desc == 'stim_off':
            event_type = 'stimulus_offset'
        elif desc == 'response':
            event_type = 'response'
        elif desc == 'isi':
            event_type = 'isi'
        elif desc == 'probe':
            event_type = 'probe'
        elif desc == 'inter_ses_break':
            event_type = 'break'
        elif desc.startswith('task_start') or desc.startswith('task_rhy'):
            event_type = 'task_start'
        elif desc == 'task_end':
            event_type = 'task_end'

        if event_type:
            # Onset relative to segment start (for BIDS events.tsv)
            rel_onset = onset - segment_start_sec
            events.append({
                'onset': rel_onset,
                'onset_original': onset,
                'sample': int(round(rel_onset * SAMPLING_RATE)),
                'description': desc,
                'event_type': event_type,
            })

    return pd.DataFrame(events), raw.info['sfreq']


def group_trials_day1(events_df, trial_pattern):
    """Group events into trials for Day 1 tasks (fix-stim or stim-fix pattern)."""
    trials = []
    current_trial = {}

    task_events = events_df[events_df['event_type'].isin(
        ['fixation', 'stimulus', 'response'])].reset_index(drop=True)

    if trial_pattern == 'fix-stim':
        for _, row in task_events.iterrows():
            if row['event_type'] == 'fixation':
                if current_trial and 'stimulus' in current_trial:
                    trials.append(current_trial)
                current_trial = {'fixation': row}
            elif row['event_type'] == 'stimulus':
                current_trial['stimulus'] = row
            elif row['event_type'] == 'response':
                current_trial['response'] = row
        if current_trial and 'stimulus' in current_trial:
            trials.append(current_trial)

    elif trial_pattern == 'stim-fix':
        for _, row in task_events.iterrows():
            if row['event_type'] == 'stimulus':
                if current_trial and 'stimulus' in current_trial:
                    trials.append(current_trial)
                current_trial = {'stimulus': row}
            elif row['event_type'] == 'fixation':
                current_trial['fixation'] = row
            elif row['event_type'] == 'response':
                current_trial['response'] = row
        if current_trial and 'stimulus' in current_trial:
            trials.append(current_trial)

    return trials


def group_trials_viseme(events_df):
    """Group events into trials for Viseme task (fix-stim-stim_off-response)."""
    trials = []
    current_trial = {}

    task_events = events_df[events_df['event_type'].isin(
        ['fixation', 'stimulus', 'stimulus_offset', 'response'])].reset_index(drop=True)

    for _, row in task_events.iterrows():
        if row['event_type'] == 'fixation':
            if current_trial and 'stimulus' in current_trial:
                trials.append(current_trial)
            current_trial = {'fixation': row}
        elif row['event_type'] == 'stimulus':
            current_trial['stimulus'] = row
        elif row['event_type'] == 'stimulus_offset':
            current_trial['stimulus_offset'] = row
        elif row['event_type'] == 'response':
            current_trial['response'] = row

    if current_trial and 'stimulus' in current_trial:
        trials.append(current_trial)

    return trials


def group_trials_rhythm(events_df):
    """Group events into trials for Visual Rhythm task (fix-stim-isi-[probe])."""
    trials = []
    current_trial = {}

    task_events = events_df[events_df['event_type'].isin(
        ['fixation', 'stimulus', 'stimulus_offset', 'isi', 'probe', 'response'])].reset_index(drop=True)

    for _, row in task_events.iterrows():
        if row['event_type'] == 'fixation':
            if current_trial and 'stimulus' in current_trial:
                trials.append(current_trial)
            current_trial = {'fixation': row}
        elif row['event_type'] == 'stimulus':
            current_trial['stimulus'] = row
        elif row['event_type'] == 'stimulus_offset':
            current_trial['stimulus_offset'] = row
        elif row['event_type'] == 'isi':
            current_trial['isi'] = row
        elif row['event_type'] == 'probe':
            current_trial['probe'] = row
        elif row['event_type'] == 'response':
            current_trial['response'] = row

    if current_trial and 'stimulus' in current_trial:
        trials.append(current_trial)

    return trials


def load_behavioral_data(csv_path):
    """Load behavioral CSV and filter to trial rows."""
    df = pd.read_csv(csv_path)
    # Find the trials column (varies: trials.thisN, block01.thisN, etc.)
    trial_col = None
    for col in df.columns:
        if col.endswith('.thisN'):
            trial_col = col
            break
    if trial_col:
        trial_rows = df[df[trial_col].notna()].copy().reset_index(drop=True)
    else:
        trial_rows = df.copy()
    return trial_rows


def build_events_tsv(trials, behavior_df, task_cfg, segment_start_sec=0):
    """Build BIDS events.tsv DataFrame (one row per event)."""
    n_merge = min(len(trials), len(behavior_df))
    rows = []

    for i in range(n_merge):
        trial = trials[i]
        behav = behavior_df.iloc[i] if i < len(behavior_df) else None
        trial_num = i + 1

        # Common fields for this trial
        base = {'trial_number': trial_num}

        # Add behavioral columns
        if behav is not None and task_cfg.get('stim_columns'):
            for col in task_cfg['stim_columns']:
                if col in behavior_df.columns:
                    val = behav[col]
                    base[col] = val if pd.notna(val) else 'n/a'

        if behav is not None and task_cfg.get('has_response') and task_cfg.get('response_corr_col'):
            corr_col = task_cfg['response_corr_col']
            if corr_col and corr_col in behavior_df.columns:
                val = behav[corr_col]
                base['accuracy'] = int(val) if pd.notna(val) else 'n/a'

            key_col = task_cfg.get('response_key_col')
            if key_col and key_col in behavior_df.columns:
                val = behav[key_col]
                base['response_key'] = str(val) if pd.notna(val) and str(val) != 'None' else 'n/a'

            rt_col = task_cfg.get('response_rt_col')
            if rt_col and rt_col in behavior_df.columns:
                val = behav[rt_col]
                base['response_time'] = round(float(val), 4) if pd.notna(val) else 'n/a'

        # Emit events for this trial
        # Fixation event
        if 'fixation' in trial:
            fix = trial['fixation']
            fix_onset = fix['onset'] - segment_start_sec
            # Duration: until stimulus
            if 'stimulus' in trial:
                fix_dur = trial['stimulus']['onset'] - fix['onset']
            else:
                fix_dur = 0
            row = {
                'onset': round(fix_onset, 4),
                'duration': round(fix_dur, 4),
                'sample': fix['sample'],
                'trial_type': 'fixation',
                'value': 6,
                **base,
            }
            rows.append(row)

        # Stimulus event
        if 'stimulus' in trial:
            stim = trial['stimulus']
            stim_onset = stim['onset'] - segment_start_sec
            # Duration: until stimulus_offset or response or next event
            if 'stimulus_offset' in trial:
                stim_dur = trial['stimulus_offset']['onset'] - stim['onset']
            elif 'response' in trial:
                stim_dur = trial['response']['onset'] - stim['onset']
            elif 'fixation' in trial and trial.get('fixation', {}).get('onset', 0) > stim['onset']:
                stim_dur = trial['fixation']['onset'] - stim['onset']
            else:
                stim_dur = 0
            row = {
                'onset': round(stim_onset, 4),
                'duration': round(stim_dur, 4),
                'sample': stim['sample'],
                'trial_type': 'stimulus',
                'value': 8,
                **base,
            }
            rows.append(row)

        # Response event
        if 'response' in trial:
            resp = trial['response']
            resp_onset = resp['onset'] - segment_start_sec
            row = {
                'onset': round(resp_onset, 4),
                'duration': 0,
                'sample': resp['sample'],
                'trial_type': 'response',
                'value': 7,
                **base,
            }
            rows.append(row)

        # ISI event (rhythm task)
        if 'isi' in trial:
            isi = trial['isi']
            isi_onset = isi['onset'] - segment_start_sec
            row = {
                'onset': round(isi_onset, 4),
                'duration': 0,
                'sample': isi['sample'],
                'trial_type': 'isi',
                'value': 'n/a',
                **base,
            }
            rows.append(row)

        # Probe event (rhythm task)
        if 'probe' in trial:
            probe = trial['probe']
            probe_onset = probe['onset'] - segment_start_sec
            row = {
                'onset': round(probe_onset, 4),
                'duration': 0,
                'sample': probe['sample'],
                'trial_type': 'probe',
                'value': 'n/a',
                **base,
            }
            rows.append(row)

    events_df = pd.DataFrame(rows)
    # Sort by onset
    if len(events_df) > 0:
        events_df = events_df.sort_values('onset').reset_index(drop=True)
    return events_df


def create_events_json(output_path, task_cfg):
    """Create events.json sidecar describing columns."""
    meta = {
        "onset": {"Description": "Event onset time in seconds from the beginning of the recording segment"},
        "duration": {"Description": "Event duration in seconds; 0 for instantaneous events"},
        "sample": {"Description": "Sample index within the recording segment (sampling rate: 2048 Hz)"},
        "trial_type": {
            "Description": "Type of event",
            "Levels": {
                "fixation": "Fixation cross presentation",
                "stimulus": "Stimulus onset",
                "response": "Participant response (button press)",
            }
        },
        "value": {"Description": "Original trigger code from SEEG DC channel"},
        "trial_number": {"Description": "Trial number within the task (1-indexed)"},
    }

    if task_cfg.get('has_response'):
        meta["accuracy"] = {"Description": "Response accuracy (1=correct, 0=incorrect, n/a=no response)"}
        meta["response_key"] = {"Description": "Key pressed by participant"}
        meta["response_time"] = {"Description": "Response time in seconds from stimulus onset"}

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)


def process_session(config, ses_key, bids_root, raw_root, segment_info):
    """Process events for a single session."""
    sub = config['participant_id']
    ses_cfg = config['sessions'][ses_key]
    ses_dir = bids_root / sub / ses_key / 'ieeg'

    print(f"\n--- {ses_key} ---")

    for task_cfg in ses_cfg.get('tasks', []):
        bids_task = task_cfg['bids_task']
        run = task_cfg['run']

        # Find the corresponding .vhdr file
        vhdr_name = f'{sub}_{ses_key}_task-{bids_task}_run-{run:02d}_ieeg.vhdr'
        vhdr_path = ses_dir / vhdr_name

        if not vhdr_path.exists():
            print(f"  [SKIP] {vhdr_name} not found")
            continue

        print(f"\n  task-{bids_task} run-{run:02d}")

        # Find segment info for this task
        seg_data = find_segment_info(segment_info, ses_key, bids_task, run)
        if not seg_data:
            print(f"    [ERROR] No segment info found")
            continue

        edf_path = Path(seg_data['edf_source'])
        task_start = seg_data['task_start_sec']
        task_end = seg_data['task_end_sec']
        seg_start = seg_data['segment_start_sec']

        # Extract annotations from original EDF
        events_df, sfreq = extract_annotations_from_edf(
            edf_path, task_start, task_end, seg_start)
        print(f"    Annotations: {len(events_df)} events")

        # Group into trials based on trial_grouping config
        grouping = task_cfg.get('trial_grouping', {})
        optional_events = grouping.get('optional_events', [])
        has_stim_offset = 'stimulus_offset' in optional_events
        has_isi = 'isi' in optional_events

        if has_stim_offset and has_isi:
            trials = group_trials_rhythm(events_df)
        elif has_stim_offset:
            trials = group_trials_viseme(events_df)
        else:
            trial_pattern = task_cfg.get('trial_pattern', 'fix-stim')
            trials = group_trials_day1(events_df, trial_pattern)
        print(f"    Trials grouped: {len(trials)}")

        # Load behavioral data
        behav_path = raw_root / task_cfg['behavior_csv']
        behavior_df = load_behavioral_data(behav_path)
        print(f"    Behavioral trials: {len(behavior_df)}")

        # Build events.tsv
        bids_events = build_events_tsv(trials, behavior_df, task_cfg, segment_start_sec=0)
        print(f"    Events rows: {len(bids_events)}")

        # Validate trial count
        n_stim_events = len(bids_events[bids_events['trial_type'] == 'stimulus']) if len(bids_events) > 0 else 0
        expected = task_cfg.get('n_expected_trials', 0)
        match_str = "OK" if n_stim_events == expected else f"MISMATCH (expected {expected})"
        print(f"    Stimulus events: {n_stim_events} [{match_str}]")

        # Write events.tsv
        events_tsv_path = ses_dir / f'{sub}_{ses_key}_task-{bids_task}_run-{run:02d}_events.tsv'
        bids_events.to_csv(events_tsv_path, sep='\t', index=False, na_rep='n/a')
        print(f"    Written: {events_tsv_path.name}")

        # Write events.json
        events_json_path = events_tsv_path.with_suffix('.json')
        create_events_json(events_json_path, task_cfg)


def find_segment_info(segment_info, ses_key, bids_task, run):
    """Find segment info matching a specific task/run.

    Supports the standardized key format: '{ses_key}/{bids_task}/run-{NN}'
    Also falls back to legacy day-based keys for backward compatibility.
    """
    # Standard key format
    std_key = f'{ses_key}/{bids_task}/run-{run:02d}'
    if std_key in segment_info:
        return segment_info[std_key]

    # Legacy format fallback (day1/day2/day3 nested dicts)
    for day_key in ['day1', 'day2', 'day3']:
        day_data = segment_info.get(day_key, {})
        if isinstance(day_data, dict):
            for seg_key, seg_data in day_data.items():
                if isinstance(seg_data, dict) and 'segment_start_sec' in seg_data:
                    # Try matching by segment key patterns
                    if ses_key in seg_key or bids_task in seg_key:
                        return seg_data

    return None


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=str, default=None)
    args = parser.parse_args()

    config_path = args.config or utils.get_config_path()
    config = utils.load_config(config_path)
    bids_root = utils.get_bids_root()
    raw_root = utils.get_raw_root(config)
    sub = config['participant_id']
    print(f"Creating events.tsv files for {sub}")

    # Load segment info (created by split_edf.py)
    segment_info_path = bids_root / 'code' / 'segment_info.json'
    with open(segment_info_path) as f:
        segment_info = json.load(f)

    for ses_key in config['sessions']:
        ses_cfg = config['sessions'][ses_key]
        if 'ieeg' in ses_cfg.get('modalities', []):
            process_session(config, ses_key, bids_root, raw_root, segment_info)

    print(f"\n{'='*70}")
    print("Events generation complete!")
    print(f"{'='*70}")


if __name__ == '__main__':
    main()
