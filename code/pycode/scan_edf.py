#!/usr/bin/env python3
"""
EDF Annotation Scanner — Reads EDF files and analyzes annotation structure.

Used by the interactive CLI to auto-detect task boundaries and generate
YAML annotation_scheme configuration.
"""

import mne
from pathlib import Path
from collections import Counter, OrderedDict


def scan_edf_annotations(edf_path):
    """Scan an EDF file and return annotation summary.

    Args:
        edf_path: Path to EDF file.

    Returns:
        dict with:
            - labels: Counter of annotation labels
            - annotations: list of (onset_sec, duration, label) sorted by onset
            - task_boundaries: list of (start_sec, end_sec) for completed tasks
            - interrupted: list of (start_sec,) for interrupted tasks
            - suggested_mode: 'sequential' or 'labeled'
            - unique_start_labels: set of labels that look like task starts
            - unique_end_labels: set of labels that look like task ends
    """
    raw = mne.io.read_raw_edf(str(edf_path), preload=False, verbose=False)

    annotations = []
    label_counts = Counter()
    for ann in raw.annotations:
        label = ann['description'].strip()
        if not label:
            continue
        annotations.append((ann['onset'], ann['duration'], label))
        label_counts[label] += 1

    annotations.sort(key=lambda x: x[0])

    # Identify start/end labels
    start_labels = set()
    end_labels = set()
    for label in label_counts:
        ll = label.lower()
        if 'task_start' in ll or 'start' in ll:
            start_labels.add(label)
        if 'task_end' in ll or 'end' in ll:
            end_labels.add(label)

    # Determine mode
    if len(start_labels) == 1 and len(end_labels) == 1:
        suggested_mode = 'sequential'
    else:
        suggested_mode = 'labeled'

    # Find task boundaries (pair starts with ends)
    task_boundaries, interrupted = _find_boundaries(annotations, start_labels, end_labels)

    return {
        'labels': label_counts,
        'annotations': annotations,
        'task_boundaries': task_boundaries,
        'interrupted': interrupted,
        'suggested_mode': suggested_mode,
        'unique_start_labels': start_labels,
        'unique_end_labels': end_labels,
    }


def _find_boundaries(annotations, start_labels, end_labels):
    """Find task start/end pairs, detecting interrupted tasks.

    Returns:
        task_boundaries: list of (start_sec, end_sec, start_label)
        interrupted: list of (start_sec, start_label)
    """
    # Collect start and end events
    starts = []
    ends = []
    for onset, dur, label in annotations:
        if label in start_labels:
            starts.append((onset, label))
        elif label in end_labels:
            ends.append((onset, label))

    if not starts or not ends:
        return [], []

    task_boundaries = []
    interrupted = []

    i = 0
    while i < len(starts):
        start_time, start_label = starts[i]

        # Check if there's another start before the next end (interrupted)
        next_start_time = starts[i + 1][0] if i + 1 < len(starts) else float('inf')

        # Find the next end after this start
        end_time = None
        for e_time, e_label in ends:
            if e_time > start_time:
                end_time = e_time
                break

        if end_time is None or next_start_time < end_time:
            # Interrupted: next start comes before any end
            interrupted.append((start_time, start_label))
            i += 1
            continue

        task_boundaries.append((start_time, end_time, start_label))
        i += 1

    return task_boundaries, interrupted


def format_time(seconds):
    """Format seconds as HH:MM:SS."""
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def format_duration(seconds):
    """Format duration in a human-readable way."""
    if seconds < 60:
        return f"{seconds:.1f}s"
    m = int(seconds // 60)
    s = seconds % 60
    return f"{m}m {s:.0f}s"


def print_scan_report(edf_path, result):
    """Print a human-readable report of the scan results."""
    print(f"\n{'='*60}")
    print(f"EDF Annotation Report: {Path(edf_path).name}")
    print(f"{'='*60}")

    print(f"\n--- Annotation Labels (총 {sum(result['labels'].values())}개) ---")
    for label, count in result['labels'].most_common():
        print(f"  {label:30s} : {count:4d}")

    print(f"\n--- Task Start Labels ---")
    for label in sorted(result['unique_start_labels']):
        print(f"  {label} ({result['labels'][label]}회)")

    print(f"\n--- Task End Labels ---")
    for label in sorted(result['unique_end_labels']):
        print(f"  {label} ({result['labels'][label]}회)")

    print(f"\n--- 감지된 Task Boundaries ({len(result['task_boundaries'])}개) ---")
    for i, (start, end, label) in enumerate(result['task_boundaries']):
        duration = end - start
        print(f"  [{i+1}] {format_time(start)} ~ {format_time(end)} "
              f"({format_duration(duration)}) [{label}]")

    if result['interrupted']:
        print(f"\n--- 중단된 Task ({len(result['interrupted'])}개) ---")
        for start, label in result['interrupted']:
            print(f"  [X] {format_time(start)} [{label}] (task_end 없음)")

    print(f"\n--- 추천 모드: {result['suggested_mode']} ---")
    if result['suggested_mode'] == 'sequential':
        print("  → 모든 task가 동일한 start/end label 사용 (순서로 구분)")
    else:
        print("  → task마다 다른 start label 사용 (label로 구분)")

    print()


def generate_annotation_scheme(result, user_mappings, mode=None):
    """Generate YAML-compatible annotation_scheme dict from scan results and user mappings.

    Args:
        result: Output from scan_edf_annotations()
        user_mappings: list of dicts with {ses, bids_task, run} for each boundary
                       (ordered, matching result['task_boundaries'])
        mode: Override mode ('sequential' or 'labeled')

    Returns:
        dict suitable for YAML annotation_scheme
    """
    mode = mode or result['suggested_mode']

    if mode == 'sequential':
        # All boundaries share the same start/end label
        start_label = list(result['unique_start_labels'])[0]
        end_label = list(result['unique_end_labels'])[0]

        scheme = {
            'mode': 'sequential',
            'start_label': start_label,
            'end_label': end_label,
            'task_order': user_mappings,
        }
    else:
        # Labeled mode: each start label maps to a specific task
        start_labels = sorted(result['unique_start_labels'])
        end_label = list(result['unique_end_labels'])[0] if result['unique_end_labels'] else 'task_end'

        # Find skip labels (start labels not in user mappings)
        mapped_labels = set()
        task_mapping = {}
        for boundary, mapping in zip(result['task_boundaries'], user_mappings):
            _, _, label = boundary
            mapped_labels.add(label)
            task_mapping[label] = mapping

        skip_labels = [l for l in start_labels if l not in mapped_labels]

        scheme = {
            'mode': 'labeled',
            'start_labels': sorted(mapped_labels),
            'end_label': end_label,
            'task_mapping': task_mapping,
        }
        if skip_labels:
            scheme['skip_labels'] = skip_labels

    return scheme


def scan_directory_for_edfs(data_dir):
    """Find all EDF files in a directory (non-recursive).

    Args:
        data_dir: Directory to search.

    Returns:
        List of Path objects for EDF files found.
    """
    data_dir = Path(data_dir)
    edfs = sorted(data_dir.glob('*.EDF')) + sorted(data_dir.glob('*.edf'))
    return edfs


if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python scan_edf.py <edf_file_or_directory>")
        print("  Scans EDF file(s) and reports annotation structure.")
        sys.exit(1)

    target = Path(sys.argv[1])

    if target.is_dir():
        edfs = scan_directory_for_edfs(target)
        if not edfs:
            print(f"No EDF files found in {target}")
            sys.exit(1)
        for edf in edfs:
            result = scan_edf_annotations(edf)
            print_scan_report(edf, result)
    elif target.is_file():
        result = scan_edf_annotations(target)
        print_scan_report(target, result)
    else:
        print(f"Not found: {target}")
        sys.exit(1)
