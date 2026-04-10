#!/usr/bin/env python3
"""
Transform electrode coordinates from native T1w space to MNI152NLin2009cAsym space
using ANTsPy SyN nonlinear registration.

Generates:
  - space-MNI152NLin2009cAsym_electrodes.tsv in each ieeg session directory
  - coordsystem.json updated with MNI coordinate system info
  - Registration transforms saved in derivatives/ants/ for reuse

Usage:
  python3 transform_mni.py --config config/sub-EP01AN96M1047.yaml
"""

import argparse
import json
import shutil
from pathlib import Path

import ants
import numpy as np
import pandas as pd

import utils


def get_or_compute_registration(t1w_path, template, transforms_dir, force=False):
    """Compute or load cached T1w → MNI registration.

    Args:
        t1w_path: Path to native T1w NIfTI.
        template: ANTs image of MNI template.
        transforms_dir: Directory to cache transforms.
        force: Recompute even if cached.

    Returns:
        dict with 'fwdtransforms' and 'invtransforms' paths.
    """
    transforms_dir = Path(transforms_dir)
    transforms_dir.mkdir(parents=True, exist_ok=True)

    # Check for cached transforms
    warp_path = transforms_dir / 'native_to_mni_1Warp.nii.gz'
    affine_path = transforms_dir / 'native_to_mni_0GenericAffine.mat'

    if warp_path.exists() and affine_path.exists() and not force:
        print(f"  Using cached transforms from {transforms_dir}")
        return {
            'fwdtransforms': [str(warp_path), str(affine_path)],
            'invtransforms': [
                str(transforms_dir / 'native_to_mni_1InverseWarp.nii.gz'),
                str(affine_path),
            ],
        }

    # Run SyN registration
    print(f"  Computing SyN registration: {Path(t1w_path).name} → MNI152 ...")
    print(f"  (This may take 10-30 minutes)")
    moving = ants.image_read(str(t1w_path))

    reg = ants.registration(
        fixed=template,
        moving=moving,
        type_of_transform='SyN',
        outprefix=str(transforms_dir / 'native_to_mni_'),
    )

    print(f"  Registration complete.")
    print(f"  Forward transforms: {reg['fwdtransforms']}")

    return reg


def transform_electrodes_to_mni(electrodes_tsv, reg_transforms, template):
    """Apply ANTs transforms to electrode coordinates.

    ANTs point transforms require INVERSE transforms (native→MNI for points
    uses the inverse warp), and coordinates in LPS convention.

    Args:
        electrodes_tsv: Path to native-space electrodes.tsv.
        reg_transforms: dict with 'fwdtransforms' and 'invtransforms'.
        template: ANTs MNI template image.

    Returns:
        DataFrame with MNI coordinates.
    """
    df = pd.read_csv(electrodes_tsv, sep='\t')

    # ANTs uses LPS internally, but our coordinates are in RAS (standard neuroimaging)
    # Convert RAS → LPS for ANTs: negate x and y
    points = df[['x', 'y', 'z']].copy()

    # Create ANTs-compatible point set (LPS)
    pts_lps = points.copy()
    pts_lps['x'] = -points['x']  # RAS→LPS: negate x
    pts_lps['y'] = -points['y']  # RAS→LPS: negate y

    # ANTs apply_transforms_to_points works in REVERSE direction:
    # To go moving→fixed (native→MNI), we pass the INVERSE transforms
    # invtransforms = [InverseWarp, GenericAffine.mat]
    # whichtoinvert = [False, True] to invert the affine
    pts_df = pd.DataFrame({
        'x': pts_lps['x'].values,
        'y': pts_lps['y'].values,
        'z': pts_lps['z'].values,
        't': np.zeros(len(pts_lps)),
    })

    transformed = ants.apply_transforms_to_points(
        dim=3,
        points=pts_df,
        transformlist=reg_transforms['invtransforms'],
        whichtoinvert=[False, True],
    )

    # Convert back LPS → RAS
    mni_coords = pd.DataFrame({
        'x': -transformed['x'].values,  # LPS→RAS
        'y': -transformed['y'].values,
        'z': transformed['z'].values,
    })

    # Build output dataframe
    result = df.copy()
    result['x'] = np.round(mni_coords['x'].values, 4)
    result['y'] = np.round(mni_coords['y'].values, 4)
    result['z'] = np.round(mni_coords['z'].values, 4)

    return result


def create_mni_coordsystem_json(output_path, native_coordsystem_path=None):
    """Create coordsystem.json for MNI space electrodes."""
    coord = {}
    if native_coordsystem_path and Path(native_coordsystem_path).exists():
        with open(native_coordsystem_path) as f:
            coord = json.load(f)

    coord.update({
        'iEEGCoordinateSystem': 'MNI152NLin2009cAsym',
        'iEEGCoordinateUnits': 'mm',
        'iEEGCoordinateProcessingDescription': (
            'Native T1w electrode coordinates transformed to MNI152NLin2009cAsym space '
            'using ANTsPy SyN nonlinear registration (moving=native T1w, fixed=MNI152 template). '
            'Transforms applied via ants.apply_transforms_to_points.'
        ),
        'iEEGCoordinateProcessingReference': (
            'Avants BB, et al. A reproducible evaluation of ANTs similarity metric '
            'performance in brain image registration. NeuroImage. 2011;54(3):2033-2044.'
        ),
    })

    with open(output_path, 'w') as f:
        json.dump(coord, f, indent=2, ensure_ascii=False)


def run(config_path, force=False):
    """Main entry point."""
    config = utils.load_config(config_path)
    bids_root = utils.get_bids_root()
    raw_root = utils.get_raw_root(config)
    sub = config['participant_id']

    print(f"\n{'='*60}")
    print(f"  MNI Coordinate Transform: {sub}")
    print(f"{'='*60}")

    # Find the native T1w (use preop as primary)
    t1w_path = None
    for ses in ['ses-preop', 'ses-postimplant']:
        candidate = bids_root / sub / ses / 'anat' / f'{sub}_{ses}_T1w.nii.gz'
        if candidate.exists():
            t1w_path = candidate
            print(f"  T1w: {candidate}")
            break

    if not t1w_path:
        print("  ERROR: No T1w found in ses-preop or ses-postimplant")
        return False

    # Load MNI template
    print(f"  Loading MNI152 template...")
    template = ants.image_read(ants.get_ants_data('mni'))

    # Compute/load registration
    transforms_dir = bids_root / 'derivatives' / 'ants' / sub
    reg = get_or_compute_registration(t1w_path, template, transforms_dir, force=force)

    # Find all sessions with ieeg electrodes
    sessions = utils.filter_sessions(config)
    n_written = 0

    for ses_key, ses_cfg in sessions.items():
        if 'ieeg' not in ses_cfg.get('modalities', []):
            continue

        ieeg_dir = bids_root / sub / ses_key / 'ieeg'
        native_elec = ieeg_dir / f'{sub}_{ses_key}_electrodes.tsv'
        native_coord = ieeg_dir / f'{sub}_{ses_key}_coordsystem.json'

        if not native_elec.exists():
            continue

        print(f"\n  Transforming: {ses_key}")

        # Transform coordinates
        mni_df = transform_electrodes_to_mni(native_elec, reg, template)

        # Write MNI electrodes.tsv
        mni_elec_path = ieeg_dir / f'{sub}_{ses_key}_space-MNI152NLin2009cAsym_electrodes.tsv'
        mni_df.to_csv(mni_elec_path, sep='\t', index=False)
        print(f"    Written: {mni_elec_path.name}")

        # Write MNI coordsystem.json
        mni_coord_path = ieeg_dir / f'{sub}_{ses_key}_space-MNI152NLin2009cAsym_coordsystem.json'
        create_mni_coordsystem_json(mni_coord_path, native_coord)
        print(f"    Written: {mni_coord_path.name}")

        n_written += 1

    # Save warped T1w for QC
    print(f"\n  Saving warped T1w for QC...")
    moving = ants.image_read(str(t1w_path))
    warped = ants.apply_transforms(
        fixed=template,
        moving=moving,
        transformlist=reg['fwdtransforms'],
    )
    warped_path = transforms_dir / f'{sub}_space-MNI152NLin2009cAsym_T1w.nii.gz'
    ants.image_write(warped, str(warped_path))
    print(f"    Written: {warped_path}")

    print(f"\n{'='*60}")
    print(f"  Complete: {n_written} sessions transformed")
    print(f"  Transforms cached: {transforms_dir}")
    print(f"  QC: Compare {warped_path.name} with MNI template")
    print(f"{'='*60}")

    return True


def main():
    parser = argparse.ArgumentParser(description='Transform electrodes to MNI space using ANTs SyN')
    parser.add_argument('--config', type=str, default=None, help='YAML config path')
    parser.add_argument('--force', action='store_true', help='Recompute registration even if cached')
    args = parser.parse_args()

    config_path = args.config or utils.get_config_path()
    success = run(config_path, force=args.force)
    import sys
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
