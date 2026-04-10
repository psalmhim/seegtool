#!/usr/bin/env python3
"""
Split continuous SEEG EDF files into per-task segments for BIDS.

Reads task boundaries from EDF annotations using config-driven annotation
schemes (sequential or labeled mode) and exports each task segment as
BrainVision format (.vhdr/.vmrk/.eeg).

BrainVision is used instead of EDF because Natus XLTEK EDF files have empty
physical min/max header fields, causing overflow errors during EDF re-export.
"""

import json
import mne
from pathlib import Path

from utils import (load_config, should_write, get_active_tasks,
                   filter_sessions, get_bids_root, get_raw_root,
                   get_config_path)


BUFFER_SEC = 5.0  # seconds of buffer before/after task


def find_task_boundaries_generic(raw, scheme):
    """Find task boundaries using config-driven annotation scheme.

    Args:
        raw: MNE Raw object with annotations
        scheme: dict with annotation_scheme from config
            mode: 'sequential' or 'labeled'
            For sequential:
                start_label, end_label, task_order
            For labeled:
                start_labels, end_label, skip_labels, task_mapping

    Returns:
        list of dicts: [{ses, bids_task, run, task_start_sec, task_end_sec}, ...]
    """
    mode = scheme.get('mode', 'labeled')

    # Collect all task-related annotations
    events = []
    for ann in raw.annotations:
        desc = ann['description'].strip()
        if desc:
            events.append((ann['onset'], desc))
    events.sort(key=lambda x: x[0])

    if mode == 'sequential':
        return _find_boundaries_sequential(events, scheme)
    else:
        return _find_boundaries_labeled(events, scheme)


def _find_boundaries_sequential(events, scheme):
    """Sequential mode: all tasks share same start/end labels, distinguished by order."""
    start_label = scheme['start_label']
    end_label = scheme['end_label']
    task_order = scheme['task_order']

    starts = [(t, l) for t, l in events if l == start_label]
    ends = [(t, l) for t, l in events if l == end_label]

    # Pair starts with ends, skipping interrupted tasks
    completed = []
    end_idx = 0
    for start_time, _ in starts:
        for ei in range(end_idx, len(ends)):
            end_time = ends[ei][0]
            if end_time <= start_time:
                continue
            # Check if another start exists between this start and end
            next_starts = [t for t, l in starts if t > start_time]
            if next_starts and next_starts[0] < end_time:
                # Interrupted: skip this start
                break
            completed.append((start_time, end_time))
            end_idx = ei + 1
            break

    # Map completed boundaries to task_order
    results = []
    for i, (tmin, tmax) in enumerate(completed):
        if i < len(task_order):
            mapping = task_order[i]
            results.append({
                'ses': mapping['ses'],
                'bids_task': mapping['bids_task'],
                'run': mapping['run'],
                'task_start_sec': tmin,
                'task_end_sec': tmax,
            })

    return results


def _find_boundaries_labeled(events, scheme):
    """Labeled mode: different start labels map to different tasks."""
    start_labels = set(scheme.get('start_labels', []))
    end_label = scheme.get('end_label', 'task_end')
    skip_labels = set(scheme.get('skip_labels', []))
    task_mapping = scheme.get('task_mapping', {})

    # All labels that could be a "start" (including ones to skip)
    all_start_like = start_labels | skip_labels

    # Track auto_increment counters per label
    auto_counters = {}

    results = []
    i = 0
    while i < len(events):
        onset, desc = events[i]

        if desc in skip_labels:
            i += 1
            continue

        if desc in start_labels:
            # Look for matching end
            found_end = False
            for j in range(i + 1, len(events)):
                next_onset, next_desc = events[j]
                if next_desc == end_label:
                    # Found the matching end
                    mapping = task_mapping.get(desc, {})
                    if mapping:
                        # Handle auto_increment: same label appears multiple times
                        if mapping.get('auto_increment', False):
                            run_start = mapping.get('run_start', 1)
                            count = auto_counters.get(desc, 0)
                            run = run_start + count
                            auto_counters[desc] = count + 1
                        else:
                            run = mapping['run']

                        results.append({
                            'ses': mapping['ses'],
                            'bids_task': mapping['bids_task'],
                            'run': run,
                            'task_start_sec': onset,
                            'task_end_sec': next_onset,
                        })
                    i = j + 1
                    found_end = True
                    break
                elif next_desc in all_start_like:
                    # Interrupted: another start/skip before end
                    i = j
                    found_end = True
                    break
            if not found_end:
                i += 1
        else:
            i += 1

    return results


def crop_and_export(raw, tmin, tmax, output_path, buffer=BUFFER_SEC, incremental=False):
    """Crop raw data and export as BrainVision format.

    Returns:
        (actual_tmin, actual_tmax) or None if skipped
    """
    if not should_write(output_path, incremental):
        return None

    actual_tmin = max(0, tmin - buffer)
    actual_tmax = min(raw.times[-1], tmax + buffer)

    segment = raw.copy().crop(tmin=actual_tmin, tmax=actual_tmax)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    mne.export.export_raw(str(output_path), segment, fmt='brainvision',
                          overwrite=True)

    duration = actual_tmax - actual_tmin
    print(f"  Exported: {output_path.name} ({duration:.1f}s, {segment.info['nchan']} channels)")

    return actual_tmin, actual_tmax


def process_edf_file(config, edf_rel_path, raw_root, bids_root, incremental=False):
    """Process a single EDF file using its annotation scheme from config.

    Args:
        config: Full config dict
        edf_rel_path: Relative path to EDF (e.g., '260311/STUDY001.EDF')
        raw_root: Raw data root path
        bids_root: BIDS output root path
        incremental: Skip existing files

    Returns:
        dict of segment info: {'{ses}/{bids_task}/run-{NN}': {...}, ...}
    """
    sub = config['participant_id']
    edf_path = raw_root / edf_rel_path
    scheme = config.get('edf_annotation_schemes', {}).get(edf_rel_path, {})

    if not scheme:
        print(f"  [WARNING] No annotation_scheme for {edf_rel_path}, skipping")
        return {}

    print(f"\n{'='*60}")
    print(f"Processing: {edf_path.name} (mode: {scheme.get('mode', 'labeled')})")
    print(f"{'='*60}")

    raw = mne.io.read_raw_edf(str(edf_path), preload=False, verbose=False)
    boundaries = find_task_boundaries_generic(raw, scheme)
    print(f"Found {len(boundaries)} completed task segments")

    # Check which tasks are excluded
    excluded_tasks = set()
    for ses_key, ses_cfg in config.get('sessions', {}).items():
        if ses_cfg.get('exclude', False):
            for task in ses_cfg.get('tasks', []):
                excluded_tasks.add((ses_key, task['bids_task'], task['run']))
        else:
            for task in ses_cfg.get('tasks', []):
                if task.get('exclude', False):
                    excluded_tasks.add((ses_key, task['bids_task'], task['run']))

    segment_info = {}
    for boundary in boundaries:
        ses_key = boundary['ses']
        bids_task = boundary['bids_task']
        run = boundary['run']
        tmin = boundary['task_start_sec']
        tmax = boundary['task_end_sec']

        # Check if excluded
        if (ses_key, bids_task, run) in excluded_tasks:
            print(f"\n  [SKIP] {ses_key}/task-{bids_task}/run-{run:02d} (excluded)")
            continue

        filename = f"{sub}_{ses_key}_task-{bids_task}_run-{run:02d}_ieeg.vhdr"
        output_path = bids_root / sub / ses_key / 'ieeg' / filename

        print(f"\n  [{ses_key}] task-{bids_task} run-{run:02d}")
        print(f"  Time range: {tmin:.3f}s - {tmax:.3f}s ({(tmax-tmin)/60:.1f}min)")

        result = crop_and_export(raw, tmin, tmax, output_path, incremental=incremental)
        if result is None:
            # Skipped (incremental), but still record segment info if file exists
            actual_tmin = max(0, tmin - BUFFER_SEC)
            actual_tmax = min(raw.times[-1], tmax + BUFFER_SEC)
        else:
            actual_tmin, actual_tmax = result

        info_key = f"{ses_key}/{bids_task}/run-{run:02d}"
        segment_info[info_key] = {
            'task_start_sec': tmin,
            'task_end_sec': tmax,
            'segment_start_sec': actual_tmin,
            'segment_end_sec': actual_tmax,
            'edf_source': str(edf_path),
        }

    return segment_info


def run(config, bids_root=None, incremental=False, session_filter=None, **kwargs):
    """Main entry point for pipeline orchestration.

    Args:
        config: Config dict (already loaded)
        bids_root: BIDS output root path
        incremental: Skip existing files
        session_filter: Optional list of session keys to process
    """
    if bids_root is None:
        bids_root = get_bids_root()
    bids_root = Path(bids_root)
    raw_root = get_raw_root(config)

    sub = config['participant_id']
    print(f"Splitting EDF files for {sub}")

    # Collect all unique EDF files referenced in annotation_schemes
    edf_files = list(config.get('edf_annotation_schemes', {}).keys())

    # If session_filter is set, only process EDFs referenced by those sessions
    if session_filter:
        active_sessions = filter_sessions(config, session_filter)
        relevant_edfs = set()
        for ses_key, ses_cfg in active_sessions.items():
            for edf in ses_cfg.get('edf_files', []):
                if isinstance(edf, dict):
                    relevant_edfs.add(edf['file'])
                else:
                    relevant_edfs.add(edf)
        edf_files = [e for e in edf_files if e in relevant_edfs]

    all_segments = {}
    for edf_rel in edf_files:
        segments = process_edf_file(config, edf_rel, raw_root, bids_root,
                                    incremental=incremental)
        all_segments.update(segments)

    # Save segment info
    info_path = bids_root / 'code' / 'segment_info.json'
    with open(info_path, 'w') as f:
        json.dump(all_segments, f, indent=2)
    print(f"\nSegment info saved to: {info_path}")

    print(f"\n{'='*60}")
    print("EDF splitting complete!")
    print(f"{'='*60}")

    return all_segments


def main():
    """Standalone execution with argparse-based config discovery."""
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=str, default=None)
    args = parser.parse_args()

    config_path = args.config or get_config_path()
    config = load_config(config_path)
    bids_root = get_bids_root()
    run(config, bids_root=bids_root)


if __name__ == '__main__':
    main()
