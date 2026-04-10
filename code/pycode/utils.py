#!/usr/bin/env python3
"""
Shared utilities for the YUHS SEEG BIDS pipeline.
"""

import yaml
from pathlib import Path


def load_config(config_path):
    """Load and return YAML config dict."""
    with open(config_path) as f:
        return yaml.safe_load(f)


def should_write(output_path, incremental=False):
    """Check if a file should be written.

    Returns True if:
    - File doesn't exist, OR
    - incremental is False (overwrite mode)

    Returns False (skip) if:
    - File exists AND incremental is True
    """
    output_path = Path(output_path)
    if not output_path.exists():
        return True
    if incremental:
        print(f"  [SKIP] {output_path.name} already exists (incremental mode)")
        return False
    return True


def filter_sessions(config, session_filter=None):
    """Return dict of active sessions (exclude=False, matching filter).

    Args:
        config: Full config dict
        session_filter: Optional list of session keys to include (e.g., ['ses-task08'])

    Returns:
        Dict of {ses_key: ses_cfg} for active sessions
    """
    result = {}
    for ses_key, ses_cfg in config.get('sessions', {}).items():
        if ses_cfg.get('exclude', False):
            continue
        if session_filter and ses_key not in session_filter:
            continue
        result[ses_key] = ses_cfg
    return result


def get_active_tasks(ses_cfg):
    """Return list of non-excluded tasks from a session config."""
    return [
        task for task in ses_cfg.get('tasks', [])
        if not task.get('exclude', False)
    ]


def get_bids_root(script_path=None):
    """Get BIDS root directory (parent of code/).

    Args:
        script_path: Path to the calling script. If None, uses default.
    """
    if script_path:
        return Path(script_path).parent.parent
    return Path(__file__).parent.parent


def get_raw_root(config):
    """Get raw data root from config."""
    return Path(config.get('raw_data_root', '/remotenas2/YUHS/SEEG_PSYCHOPY'))


def get_config_path(config_name=None, script_dir=None):
    """Get config file path.

    Args:
        config_name: Config filename or full path.
        script_dir: Directory containing the code/ folder.
    """
    if config_name:
        p = Path(config_name)
        if p.is_absolute() and p.exists():
            return p
        # Try relative to code/config/
        if script_dir:
            candidate = Path(script_dir) / 'config' / config_name
            if candidate.exists():
                return candidate
    # List available configs
    if script_dir:
        config_dir = Path(script_dir) / 'config'
        if config_dir.exists():
            yamls = sorted(config_dir.glob('*.yaml'))
            if yamls:
                return yamls[0]
    return None


def get_event_type_mapping(config):
    """Get annotation-to-event-type mapping from config, with defaults."""
    defaults = {
        'fixation': 'fixation',
        'stimuli': 'stimulus',
        'stim_on': 'stimulus',
        'stim_off': 'stimulus_offset',
        'response': 'response',
        'isi': 'isi',
        'probe': 'probe',
    }
    return {**defaults, **config.get('event_type_mapping', {})}


def get_task_description(config, bids_task):
    """Get task description from config."""
    return config.get('task_descriptions', {}).get(bids_task, '')


def get_soz_electrodes(config):
    """Get SOZ electrode names from config."""
    return set(config.get('soz', {}).get('electrodes', []))


def get_modalities_include(config):
    """Get modality inclusion flags with defaults (all True)."""
    defaults = {
        'anat': True, 'dwi': True, 'func': True,
        'pet': True, 'ieeg': True, 'derivatives': True,
    }
    return {**defaults, **config.get('modalities_include', {})}
