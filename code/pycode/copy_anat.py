#!/usr/bin/env python3
"""
Copy anatomical/neuroimaging data to BIDS structure.
Handles ses-preop and ses-postimplant sessions.
Also copies derivatives (FreeSurfer, tractography, electrode localization).
"""

import shutil
import json
import yaml
from pathlib import Path

import utils


def copy_file(src, dst, dry_run=False):
    """Copy a file, creating parent dirs as needed."""
    if not src.exists():
        print(f"  [MISSING] {src}")
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dry_run:
        shutil.copy2(src, dst)
    print(f"  {'[DRY]' if dry_run else ''} {src.name} -> {dst}")
    return True


def copy_preop(config, bids_root, raw_root):
    """Copy pre-operative imaging data to ses-preop."""
    sub = config['participant_id']
    neuro = config['neuroimaging']['preop']
    ses_dir = bids_root / sub / 'ses-preop'
    prefix = f'{sub}_ses-preop'

    print("\n=== ses-preop ===")

    # T1w
    copy_file(raw_root / neuro['T1w'],
              ses_dir / 'anat' / f'{prefix}_T1w.nii.gz')
    copy_file(raw_root / neuro['T1w_json'],
              ses_dir / 'anat' / f'{prefix}_T1w.json')

    # FLAIR
    copy_file(raw_root / neuro['FLAIR'],
              ses_dir / 'anat' / f'{prefix}_FLAIR.nii.gz')

    # DWI
    copy_file(raw_root / neuro['dwi'],
              ses_dir / 'dwi' / f'{prefix}_dwi.nii.gz')
    copy_file(raw_root / neuro['dwi_bval'],
              ses_dir / 'dwi' / f'{prefix}_dwi.bval')
    copy_file(raw_root / neuro['dwi_bvec'],
              ses_dir / 'dwi' / f'{prefix}_dwi.bvec')
    copy_file(raw_root / neuro['dwi_json'],
              ses_dir / 'dwi' / f'{prefix}_dwi.json')

    # Resting-state fMRI
    copy_file(raw_root / neuro['func_rest'],
              ses_dir / 'func' / f'{prefix}_task-rest_bold.nii.gz')

    # PET
    copy_file(raw_root / neuro['pet'],
              ses_dir / 'pet' / f'{prefix}_pet.nii.gz')


def copy_postimplant(config, bids_root, raw_root):
    """Copy post-implant imaging data to ses-postimplant."""
    sub = config['participant_id']
    neuro = config['neuroimaging']['postimplant']
    ses_dir = bids_root / sub / 'ses-postimplant'
    prefix = f'{sub}_ses-postimplant'

    print("\n=== ses-postimplant ===")

    # CT
    copy_file(raw_root / neuro['CT'],
              ses_dir / 'anat' / f'{prefix}_CT.nii.gz')

    # T1w
    copy_file(raw_root / neuro['T1w'],
              ses_dir / 'anat' / f'{prefix}_T1w.nii.gz')

    # FLAIR
    copy_file(raw_root / neuro['FLAIR'],
              ses_dir / 'anat' / f'{prefix}_FLAIR.nii.gz')

    # DWI
    copy_file(raw_root / neuro['dwi'],
              ses_dir / 'dwi' / f'{prefix}_dwi.nii.gz')

    # Resting-state fMRI
    copy_file(raw_root / neuro['func_rest'],
              ses_dir / 'func' / f'{prefix}_task-rest_bold.nii.gz')


def copy_derivatives(config, bids_root, raw_root):
    """Copy derivative data (FreeSurfer, tractography, electrode localization)."""
    sub = config['participant_id']
    deriv = config['derivatives']

    print("\n=== derivatives ===")

    # FreeSurfer
    fs_src = raw_root / deriv['freesurfer']
    fs_dst = bids_root / 'derivatives' / 'freesurfer' / sub
    if fs_src.exists():
        print(f"  Copying FreeSurfer: {fs_src}")
        if fs_dst.exists():
            shutil.rmtree(fs_dst)
        shutil.copytree(fs_src, fs_dst)
        print(f"  -> {fs_dst}")
    else:
        print(f"  [MISSING] FreeSurfer: {fs_src}")

    # Tractography
    tract_src = raw_root / deriv['tractography']
    tract_dst = bids_root / 'derivatives' / 'tractography' / sub
    if tract_src.exists():
        print(f"  Copying tractography: {tract_src}")
        if tract_dst.exists():
            shutil.rmtree(tract_dst)
        shutil.copytree(tract_src, tract_dst)
        print(f"  -> {tract_dst}")

    # Electrode localization
    elec_dst = bids_root / 'derivatives' / 'electrode-localization' / sub
    elec_dst.mkdir(parents=True, exist_ok=True)
    for key, path in deriv['electrode_localization'].items():
        src = raw_root / path
        if src.exists():
            dst = elec_dst / src.name
            shutil.copy2(src, dst)
            print(f"  {src.name} -> electrode-localization/")


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=str, default=None)
    args = parser.parse_args()

    config_path = args.config or utils.get_config_path()
    config = utils.load_config(config_path)
    bids_root = utils.get_bids_root()
    raw_root = utils.get_raw_root(config)
    print(f"Copying neuroimaging data for {config['participant_id']}")

    copy_preop(config, bids_root, raw_root)
    copy_postimplant(config, bids_root, raw_root)
    copy_derivatives(config, bids_root, raw_root)

    print("\nAnatomical data copy complete!")


if __name__ == '__main__':
    main()
