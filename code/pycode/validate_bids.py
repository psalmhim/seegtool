#!/usr/bin/env python3
"""
Validate the BIDS dataset structure and file naming.
Uses bids_validator for path validation + custom checks for content consistency.
"""

import json
import yaml
import pandas as pd
from pathlib import Path
from bids_validator import BIDSValidator

import utils


def validate_path_names(bids_root):
    """Check all data files against BIDS naming conventions."""
    validator = BIDSValidator()
    errors = []
    warnings = []
    valid_count = 0
    skip_count = 0

    ignore_patterns = ['README', 'CHANGES', '.bidsignore', 'code/', 'stimuli/',
                       'derivatives/', 'LICENSE']

    for fpath in sorted(bids_root.rglob('*')):
        if fpath.is_dir():
            continue

        rel = str(fpath.relative_to(bids_root))

        # Skip files we expect to be outside BIDS validation
        if any(rel.startswith(p) or rel == p for p in ignore_patterns):
            skip_count += 1
            continue
        if fpath.name == 'README.md':
            skip_count += 1
            continue

        # BIDSValidator expects /sub-xxx/... format
        bids_path = '/' + rel
        if validator.is_bids(bids_path):
            valid_count += 1
        else:
            # Check if it's a known BIDS file type that the validator might not recognize
            if fpath.suffix in ['.eeg', '.vhdr', '.vmrk']:
                valid_count += 1  # BrainVision iEEG files are valid BIDS
            elif fpath.name.endswith('_sessions.tsv') or fpath.name.endswith('_sessions.json'):
                valid_count += 1
            else:
                warnings.append(f"  Not recognized by BIDSValidator: {rel}")

    return valid_count, warnings, skip_count


def validate_required_files(bids_root):
    """Check that required top-level files exist."""
    errors = []
    required = [
        'dataset_description.json',
        'participants.tsv',
        'README',
    ]
    for fname in required:
        if not (bids_root / fname).exists():
            errors.append(f"Missing required file: {fname}")

    # Validate dataset_description.json content
    dd_path = bids_root / 'dataset_description.json'
    if dd_path.exists():
        with open(dd_path) as f:
            dd = json.load(f)
        for field in ['Name', 'BIDSVersion']:
            if field not in dd:
                errors.append(f"dataset_description.json missing required field: {field}")

    return errors


def validate_sessions_tsv(bids_root, config):
    """Validate sessions.tsv consistency."""
    errors = []
    sub = config['participant_id']
    sessions_path = bids_root / sub / f'{sub}_sessions.tsv'

    if not sessions_path.exists():
        errors.append(f"Missing: {sessions_path.name}")
        return errors

    df = pd.read_csv(sessions_path, sep='\t')
    if 'session_id' not in df.columns:
        errors.append("sessions.tsv missing 'session_id' column")
        return errors

    # Check all configured sessions exist
    for ses_key in config['sessions']:
        if ses_key not in df['session_id'].values:
            errors.append(f"Session {ses_key} in config but not in sessions.tsv")

    # Check session directories exist
    for ses_id in df['session_id']:
        ses_dir = bids_root / sub / ses_id
        if not ses_dir.exists():
            errors.append(f"sessions.tsv lists {ses_id} but directory missing")

    return errors


def validate_ieeg_files(bids_root, config):
    """Validate iEEG file completeness per session."""
    errors = []
    warnings = []
    sub = config['participant_id']

    for ses_key, ses_cfg in config['sessions'].items():
        if 'ieeg' not in ses_cfg.get('modalities', []):
            continue

        ses_dir = bids_root / sub / ses_key / 'ieeg'
        if not ses_dir.exists():
            errors.append(f"{ses_key}/ieeg/ directory missing")
            continue

        # Check for required files per task run
        for task_cfg in ses_cfg.get('tasks', []):
            if task_cfg.get('exclude'):
                continue
            bids_task = task_cfg['bids_task']
            run = task_cfg['run']
            prefix = f'{sub}_{ses_key}_task-{bids_task}_run-{run:02d}'

            # BrainVision trio
            for ext in ['.vhdr', '.vmrk', '.eeg']:
                fpath = ses_dir / f'{prefix}_ieeg{ext}'
                if not fpath.exists():
                    errors.append(f"Missing: {ses_key}/ieeg/{prefix}_ieeg{ext}")

            # Sidecar files
            for suffix in ['_channels.tsv', '_events.tsv', '_ieeg.json']:
                fpath = ses_dir / f'{prefix}{suffix}'
                if not fpath.exists():
                    errors.append(f"Missing: {ses_key}/ieeg/{prefix}{suffix}")

        # Session-level files
        for suffix in ['_electrodes.tsv', '_coordsystem.json']:
            fpath = ses_dir / f'{sub}_{ses_key}{suffix}'
            if not fpath.exists():
                errors.append(f"Missing: {ses_key}/ieeg/{sub}_{ses_key}{suffix}")

    return errors, warnings


def validate_events_tsv(bids_root, config):
    """Validate events.tsv content."""
    errors = []
    warnings = []
    sub = config['participant_id']

    for ses_key, ses_cfg in config['sessions'].items():
        if 'ieeg' not in ses_cfg.get('modalities', []):
            continue

        ses_dir = bids_root / sub / ses_key / 'ieeg'

        for task_cfg in ses_cfg.get('tasks', []):
            if task_cfg.get('exclude'):
                continue
            bids_task = task_cfg['bids_task']
            run = task_cfg['run']
            prefix = f'{sub}_{ses_key}_task-{bids_task}_run-{run:02d}'
            events_path = ses_dir / f'{prefix}_events.tsv'

            if not events_path.exists():
                continue

            df = pd.read_csv(events_path, sep='\t')

            # Required columns
            for col in ['onset', 'duration', 'trial_type']:
                if col not in df.columns:
                    errors.append(f"{prefix}_events.tsv missing column: {col}")

            if 'onset' in df.columns:
                # Check onsets are non-negative
                if (df['onset'] < 0).any():
                    errors.append(f"{prefix}_events.tsv has negative onset values")

                # Check onsets are sorted
                if not df['onset'].is_monotonic_increasing:
                    warnings.append(f"{prefix}_events.tsv onsets not strictly increasing")

            # Count stimulus events
            if 'trial_type' in df.columns:
                n_stim = (df['trial_type'] == 'stimulus').sum()
                expected = task_cfg.get('n_expected_trials')
                if expected and n_stim != expected:
                    warnings.append(
                        f"{prefix}_events.tsv: {n_stim} stimulus events "
                        f"(config expects {expected})")

    return errors, warnings


def validate_channels_tsv(bids_root, config):
    """Validate channels.tsv files."""
    errors = []
    sub = config['participant_id']

    for ses_key, ses_cfg in config['sessions'].items():
        if 'ieeg' not in ses_cfg.get('modalities', []):
            continue

        ses_dir = bids_root / sub / ses_key / 'ieeg'
        channels_files = sorted(ses_dir.glob('*_channels.tsv'))

        for ch_path in channels_files:
            df = pd.read_csv(ch_path, sep='\t')
            required_cols = ['name', 'type', 'units', 'sampling_frequency']
            for col in required_cols:
                if col not in df.columns:
                    errors.append(f"{ch_path.name} missing column: {col}")

            # Check sampling frequency matches config
            if 'sampling_frequency' in df.columns:
                expected_sf = config['seeg']['sampling_rate']
                actual_sf = df['sampling_frequency'].iloc[0]
                if actual_sf != expected_sf:
                    errors.append(
                        f"{ch_path.name}: sampling_frequency {actual_sf} != expected {expected_sf}")

    return errors


def validate_anat(bids_root, config):
    """Check anatomical files exist."""
    errors = []
    sub = config['participant_id']

    for ses_key in ['ses-preop', 'ses-postimplant']:
        ses_dir = bids_root / sub / ses_key
        if not ses_dir.exists():
            errors.append(f"Missing session directory: {ses_key}")
            continue

        anat_dir = ses_dir / 'anat'
        if anat_dir.exists():
            nii_files = list(anat_dir.glob('*.nii.gz'))
            if not nii_files:
                errors.append(f"{ses_key}/anat/ has no .nii.gz files")

    return errors


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=str, default=None)
    args = parser.parse_args()

    config_path = args.config or utils.get_config_path()
    config = utils.load_config(config_path)
    bids_root = utils.get_bids_root()
    sub = config['participant_id']

    print(f"{'='*70}")
    print(f"BIDS Validation Report for {sub}")
    print(f"{'='*70}")

    all_errors = []
    all_warnings = []

    # 1. Required files
    print("\n[1] Required top-level files...")
    errs = validate_required_files(bids_root)
    all_errors.extend(errs)
    print(f"    {'PASS' if not errs else 'FAIL'} ({len(errs)} errors)")

    # 2. Path naming
    print("\n[2] BIDS path naming validation...")
    valid, warns, skipped = validate_path_names(bids_root)
    all_warnings.extend(warns)
    print(f"    {valid} valid files, {skipped} skipped (code/stimuli/derivatives/README)")
    if warns:
        for w in warns[:10]:
            print(f"    {w}")
        if len(warns) > 10:
            print(f"    ... and {len(warns) - 10} more")

    # 3. Sessions
    print("\n[3] sessions.tsv consistency...")
    errs = validate_sessions_tsv(bids_root, config)
    all_errors.extend(errs)
    print(f"    {'PASS' if not errs else 'FAIL'} ({len(errs)} errors)")

    # 4. iEEG completeness
    print("\n[4] iEEG file completeness...")
    errs, warns = validate_ieeg_files(bids_root, config)
    all_errors.extend(errs)
    all_warnings.extend(warns)
    print(f"    {'PASS' if not errs else 'FAIL'} ({len(errs)} errors)")
    for e in errs:
        print(f"    ERROR: {e}")

    # 5. events.tsv content
    print("\n[5] events.tsv content validation...")
    errs, warns = validate_events_tsv(bids_root, config)
    all_errors.extend(errs)
    all_warnings.extend(warns)
    print(f"    {'PASS' if not errs else 'FAIL'} ({len(errs)} errors, {len(warns)} warnings)")
    for w in warns:
        print(f"    WARNING: {w}")

    # 6. channels.tsv
    print("\n[6] channels.tsv validation...")
    errs = validate_channels_tsv(bids_root, config)
    all_errors.extend(errs)
    print(f"    {'PASS' if not errs else 'FAIL'} ({len(errs)} errors)")

    # 7. Anatomical data
    print("\n[7] Anatomical data check...")
    errs = validate_anat(bids_root, config)
    all_errors.extend(errs)
    print(f"    {'PASS' if not errs else 'FAIL'} ({len(errs)} errors)")

    # Summary
    print(f"\n{'='*70}")
    print(f"SUMMARY: {len(all_errors)} errors, {len(all_warnings)} warnings")
    print(f"{'='*70}")

    if all_errors:
        print("\nERRORS:")
        for e in all_errors:
            print(f"  ✗ {e}")

    if all_warnings:
        print("\nWARNINGS:")
        for w in all_warnings:
            print(f"  ! {w}")

    if not all_errors:
        print("\n✓ Dataset passes all validation checks!")

    return len(all_errors)


if __name__ == '__main__':
    import sys
    sys.exit(main())
