#!/usr/bin/env python3
"""
Create README.md files for each session and modality folder.
Generates content from YAML config rather than hardcoded dicts.
"""

from pathlib import Path

import utils


def generate_session_readme(ses_key, ses_cfg, config):
    """Generate README content for a session from config data."""
    lines = []
    purpose = ses_cfg.get('purpose', ses_key)
    date = ses_cfg.get('date', 'unknown')
    context = ses_cfg.get('context', '')
    modalities = ses_cfg.get('modalities', [])
    task_descs = config.get('task_descriptions', {})
    seeg_cfg = config.get('seeg', {})

    lines.append(f"# Session: {ses_key} ({purpose})\n")
    lines.append(f"- **Date**: {date}")
    if context:
        lines.append(f"- **Context**: {context}")

    # Task sessions
    tasks = ses_cfg.get('tasks', [])
    if tasks:
        active_tasks = [t for t in tasks if not t.get('exclude')]
        excluded_tasks = [t for t in tasks if t.get('exclude')]

        for t in active_tasks:
            bids_task = t['bids_task']
            task_name = t.get('task_name', bids_task)
            desc = task_descs.get(bids_task, '')
            n_trials = t.get('n_expected_trials', '?')
            has_resp = t.get('has_response', False)

            lines.append(f"- **Task**: {task_name}")
            if desc:
                lines.append(f"- **Description**: {desc}")
            lines.append(f"- **Trials**: {n_trials}")
            if has_resp:
                lines.append(f"- **Response**: Yes")

        if len(active_tasks) > 1:
            lines.append("\n## Runs")
            for t in active_tasks:
                run = t['run']
                task_name = t.get('task_name', t['bids_task'])
                n = t.get('n_expected_trials', '?')
                label = f"task-{t['bids_task']}" if t['bids_task'] != active_tasks[0]['bids_task'] else ""
                if label:
                    lines.append(f"- **{label} run-{run:02d}**: {task_name} ({n} trials)")
                else:
                    lines.append(f"- **run-{run:02d}**: {task_name} ({n} trials)")

        if excluded_tasks:
            lines.append("\n## Excluded Runs")
            for t in excluded_tasks:
                reason = t.get('exclude_reason', 'excluded')
                lines.append(f"- **run-{t['run']:02d}**: {reason}")

    # Imaging sessions
    if 'anat' in modalities or 'dwi' in modalities or 'func' in modalities:
        lines.append("\n## Acquired Data")
        if 'anat' in modalities:
            lines.append("- **anat/**: Structural imaging (T1w, FLAIR, CT)")
        if 'dwi' in modalities:
            lines.append("- **dwi/**: Diffusion tensor imaging")
        if 'func' in modalities:
            lines.append("- **func/**: Resting-state fMRI")
        if 'pet' in modalities:
            lines.append("- **pet/**: PET imaging")

    # Recording info for ieeg sessions
    if 'ieeg' in modalities:
        edf_files = ses_cfg.get('edf_files', [])
        if edf_files:
            lines.append("\n## Source EDF")
            for edf in edf_files:
                lines.append(f"- {edf}")
        if seeg_cfg:
            sr = seeg_cfg.get('sampling_rate', '?')
            mfr = seeg_cfg.get('manufacturer', '?')
            model = seeg_cfg.get('manufacturer_model', '?')
            lines.append(f"\n## Equipment")
            lines.append(f"- {mfr} {model}, {sr} Hz")

    return '\n'.join(lines) + '\n'


MODALITY_READMES = {
    'anat': "# Anatomical Data\n\nStructural brain imaging (T1w, FLAIR, CT).\n",
    'dwi': "# Diffusion-Weighted Imaging\n\nDiffusion tensor imaging for white matter tractography.\n",
    'func': "# Functional MRI\n\nResting-state fMRI data.\n",
    'pet': "# PET Data\n\nFDG-PET co-registered to T1w.\n",
    'ieeg': ("# Intracranial EEG (SEEG)\n\n"
             "Stereo-electroencephalography task recordings in BrainVision format.\n\n"
             "Files per run:\n"
             "- `*_ieeg.vhdr/.vmrk/.eeg`: BrainVision data (header/markers/data)\n"
             "- `*_channels.tsv`: Channel metadata\n"
             "- `*_events.tsv`: Task events with behavioral data\n"
             "- `*_events.json`: Event column descriptions\n"
             "- `*_ieeg.json`: Recording metadata\n\n"
             "Session-level files:\n"
             "- `*_electrodes.tsv`: Electrode coordinates (native T1w space)\n"
             "- `*_coordsystem.json`: Coordinate system description\n"),
}


def create_session_readmes(config, bids_root):
    """Create session-level README files from config."""
    sub = config['participant_id']

    for ses_key, ses_cfg in config['sessions'].items():
        ses_dir = bids_root / sub / ses_key
        if ses_dir.exists():
            content = generate_session_readme(ses_key, ses_cfg, config)
            readme_path = ses_dir / 'README.md'

            # Preserve manually edited READMEs: only overwrite if not customized
            # (check for a marker comment)
            if readme_path.exists():
                existing = readme_path.read_text()
                if '<!-- custom -->' in existing:
                    print(f"Skipped (custom): {ses_key}/README.md")
                    continue

            with open(readme_path, 'w') as f:
                f.write(content)
            print(f"Written: {ses_key}/README.md")


def create_modality_readmes(config, bids_root):
    """Create modality-level README files in each session's modality folders."""
    sub = config['participant_id']

    for ses_key in config['sessions']:
        ses_dir = bids_root / sub / ses_key
        if not ses_dir.exists():
            continue

        for mod_dir in ses_dir.iterdir():
            if mod_dir.is_dir() and mod_dir.name in MODALITY_READMES:
                readme_path = mod_dir / 'README.md'
                with open(readme_path, 'w') as f:
                    f.write(MODALITY_READMES[mod_dir.name])
                print(f"Written: {ses_key}/{mod_dir.name}/README.md")


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=str, default=None)
    args = parser.parse_args()

    config_path = args.config or utils.get_config_path()
    config = utils.load_config(config_path)
    bids_root = utils.get_bids_root()
    print(f"Creating README files for {config['participant_id']}")

    create_session_readmes(config, bids_root)
    create_modality_readmes(config, bids_root)

    print("\nREADME generation complete!")


if __name__ == '__main__':
    main()
