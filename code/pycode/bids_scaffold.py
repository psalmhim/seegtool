#!/usr/bin/env python3
"""
Create BIDS directory scaffolding and top-level metadata files.
Reads patient config from YAML and generates the complete folder structure.
"""

import json
import yaml
import pandas as pd
from pathlib import Path

import utils


def create_directories(bids_root, config):
    """Create all BIDS directories based on config."""
    sub = config['participant_id']
    sub_dir = bids_root / sub

    # Top-level directories
    (bids_root / 'stimuli').mkdir(parents=True, exist_ok=True)
    (bids_root / 'code' / 'config').mkdir(parents=True, exist_ok=True)
    (bids_root / 'derivatives' / 'freesurfer' / sub).mkdir(parents=True, exist_ok=True)
    (bids_root / 'derivatives' / 'tractography' / sub).mkdir(parents=True, exist_ok=True)
    (bids_root / 'derivatives' / 'electrode-localization' / sub).mkdir(parents=True, exist_ok=True)

    # Stimuli subdirectories
    task_labels = set()
    for ses_key, ses_cfg in config['sessions'].items():
        if 'tasks' in ses_cfg:
            for task in ses_cfg['tasks']:
                task_labels.add(task['bids_task'])
    for label in sorted(task_labels):
        (bids_root / 'stimuli' / f'task-{label}').mkdir(exist_ok=True)

    # Session directories with modality subdirectories
    for ses_key, ses_cfg in config['sessions'].items():
        ses_dir = sub_dir / ses_key
        for modality in ses_cfg['modalities']:
            (ses_dir / modality).mkdir(parents=True, exist_ok=True)

    print(f"Created directory structure under {bids_root}")


def write_dataset_description(bids_root):
    """Write dataset_description.json."""
    desc = {
        "Name": "YUHS SEEG Cognitive Tasks",
        "BIDSVersion": "1.9.0",
        "DatasetType": "raw",
        "License": "CC0",
        "Authors": [
            "TODO: Add authors"
        ],
        "Acknowledgements": "Data collected at Yonsei University Health System (Severance Hospital), Seoul, South Korea.",
        "Funding": ["TODO: Add funding sources"],
        "DatasetDOI": "n/a",
        "GeneratedBy": [
            {
                "Name": "Custom Python BIDS conversion pipeline",
                "Version": "1.0.0",
                "Description": "SEEG task data BIDS conversion for YUHS epilepsy monitoring patients"
            }
        ]
    }
    path = bids_root / 'dataset_description.json'
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(desc, f, indent=2, ensure_ascii=False)
    print(f"Written: {path.name}")


def write_participants(bids_root, config):
    """Write participants.tsv and participants.json."""
    demo = config['demographics']
    sub = config['participant_id']

    # participants.tsv
    df = pd.DataFrame([{
        'participant_id': sub,
        'age': demo['age'],
        'sex': demo['sex'],
        'handedness': demo['handedness'],
        'pathology': demo['pathology'],
    }])
    tsv_path = bids_root / 'participants.tsv'
    df.to_csv(tsv_path, sep='\t', index=False)
    print(f"Written: {tsv_path.name}")

    # participants.json
    meta = {
        "participant_id": {"Description": "Unique participant identifier"},
        "age": {"Description": "Age of participant at time of SEEG monitoring", "Units": "years"},
        "sex": {"Description": "Biological sex", "Levels": {"M": "male", "F": "female"}},
        "handedness": {"Description": "Handedness", "Levels": {"R": "right", "L": "left", "A": "ambidextrous"}},
        "pathology": {"Description": "Primary neurological diagnosis"},
    }
    json_path = bids_root / 'participants.json'
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
    print(f"Written: {json_path.name}")


def write_sessions_tsv(bids_root, config):
    """Write sessions.tsv under the subject directory."""
    sub = config['participant_id']
    sub_dir = bids_root / sub

    rows = []
    for ses_key, ses_cfg in config['sessions'].items():
        rows.append({
            'session_id': ses_key,
            'acq_date': ses_cfg.get('date', 'n/a'),
            'acq_context': ses_cfg.get('context', 'n/a'),
            'purpose': ses_cfg.get('purpose', 'n/a'),
            'modalities': ','.join(ses_cfg.get('modalities', [])),
        })

    df = pd.DataFrame(rows)
    tsv_path = sub_dir / f'{sub}_sessions.tsv'
    tsv_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(tsv_path, sep='\t', index=False)
    print(f"Written: {tsv_path.name}")

    # sessions.json
    meta = {
        "session_id": {"Description": "Session identifier"},
        "acq_date": {"Description": "Date of data acquisition (YYYY-MM-DD)"},
        "acq_context": {"Description": "Clinical context of acquisition",
                        "Levels": {
                            "preoperative": "Before SEEG electrode implantation",
                            "postimplant": "After SEEG electrode implantation, before cognitive tasks",
                            "monitoring": "During SEEG monitoring with cognitive task performance"
                        }},
        "purpose": {"Description": "Purpose of the session"},
        "modalities": {"Description": "Comma-separated list of data modalities acquired in this session"},
    }
    json_path = sub_dir / f'{sub}_sessions.json'
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
    print(f"Written: {json_path.name}")


def write_bidsignore(bids_root):
    """Write .bidsignore to exclude README.md files from validation."""
    content = "**/README.md\n"
    path = bids_root / '.bidsignore'
    with open(path, 'w') as f:
        f.write(content)
    print(f"Written: {path.name}")


def write_changes(bids_root, config):
    """Write CHANGES file with info from config."""
    from datetime import date
    sub = config['participant_id']
    sessions = config.get('sessions', {})
    n_tasks = sum(1 for s in sessions.values()
                  if 'ieeg' in s.get('modalities', []))
    today = date.today().isoformat()
    content = (f"1.0.0 {today}\n"
               f"  - Initial BIDS dataset creation\n"
               f"  - Patient {sub}: {n_tasks} task sessions\n")
    path = bids_root / 'CHANGES'
    with open(path, 'w') as f:
        f.write(content)
    print(f"Written: {path.name}")


def write_top_readme(bids_root, config):
    """Write top-level README from config."""
    task_descs = config.get('task_descriptions', {})
    seeg_cfg = config.get('seeg', {})
    raw_root = config.get('raw_data_root', '')

    task_lines = []
    for task_name, desc in task_descs.items():
        short = desc.split('.')[0] if desc else task_name
        task_lines.append(f"- **{task_name}**: {short}")

    content = f"""# YUHS SEEG Cognitive Tasks Dataset

## Overview
This dataset contains intracranial EEG (SEEG) recordings from epilepsy patients at
Yonsei University Health System (Severance Hospital) who performed cognitive tasks
during SEEG monitoring.

## Tasks
{chr(10).join(task_lines)}

## Recording Equipment
- SEEG system: {seeg_cfg.get('manufacturer', '?')} {seeg_cfg.get('manufacturer_model', '?')}, {seeg_cfg.get('sampling_rate', '?')} Hz sampling rate
- Task presentation: PsychoPy on MacBook Air
- Trigger synchronization: ZMQ-based DC trigger system

## Original Data Location
- {raw_root}

## License
CC0
"""
    path = bids_root / 'README'
    with open(path, 'w') as f:
        f.write(content)
    print(f"Written: {path.name}")


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=str, default=None)
    args = parser.parse_args()

    config_path = args.config or utils.get_config_path()
    config = utils.load_config(config_path)
    bids_root = utils.get_bids_root()
    print(f"Loaded config for {config['participant_id']}")

    create_directories(bids_root, config)
    write_dataset_description(bids_root)
    write_participants(bids_root, config)
    write_sessions_tsv(bids_root, config)
    write_bidsignore(bids_root)
    write_changes(bids_root, config)
    write_top_readme(bids_root, config)

    print("\nBIDS scaffolding complete!")


if __name__ == '__main__':
    main()
