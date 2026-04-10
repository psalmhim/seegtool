#!/usr/bin/env python3
"""
Trigger quality verification and PsychoPy-based correction.

For each run:
1. Read SEEG triggers from original EDF (within task boundaries)
2. Read PsychoPy behavioral CSV timing
3. Compare: trial count, bunched detection, ITI correlation
4. If problems detected → reconstruct using PsychoPy timing
5. Output: trigger_report.json + corrected .vmrk / events.tsv (if needed)

Usage:
    python verify_triggers.py                          # default config
    python verify_triggers.py --config path/to/config.yaml
    python verify_triggers.py --config ... --auto-correct
"""

import argparse
import json
import shutil
from datetime import datetime
from pathlib import Path

import mne
import numpy as np
import pandas as pd

import utils

# ---------------------------------------------------------------------------
# Thresholds
# ---------------------------------------------------------------------------
BUNCHED_MIN_GAP = 0.5       # seconds — events closer than this are "bunched"
BUNCHED_EVENT_THRESHOLD = 4  # >N events at same timestamp = bunched region
ITI_CORR_WARN = 0.99         # correlation below this triggers warning
MAX_RESIDUAL_WARN_MS = 50.0  # ms — residual above this triggers warning
DRIFT_WARN_PPM = 100.0       # ppm — clock drift above this triggers warning


# ---------------------------------------------------------------------------
# Core analysis functions
# ---------------------------------------------------------------------------
def detect_bunched_events(stim_times, min_gap=BUNCHED_MIN_GAP):
    """
    Detect events bunched at the same timestamp.

    Returns:
        clean_times: list of timestamps with bunched duplicates removed
        bunched_regions: list of {'timestamp': float, 'n_events': int}
    """
    if len(stim_times) == 0:
        return [], []

    # Deduplicate by min_gap
    unique = [stim_times[0]]
    for t in stim_times[1:]:
        if t - unique[-1] > min_gap:
            unique.append(t)

    # Find bunched regions: check all events (not just stim) at each timestamp
    bunched_regions = []
    from collections import Counter
    ts_counts = Counter(round(t, 3) for t in stim_times)
    for ts, cnt in sorted(ts_counts.items()):
        if cnt > 1:  # More than 1 stim_on at same rounded timestamp
            bunched_regions.append({'timestamp': ts, 'n_stim_duplicates': cnt})

    # Clean = unique timestamps excluding bunched regions
    bunched_ts = {r['timestamp'] for r in bunched_regions}
    clean = [t for t in unique if round(t, 3) not in bunched_ts]

    return clean, bunched_regions


def detect_bunched_all_events(all_event_times, threshold=BUNCHED_EVENT_THRESHOLD):
    """
    Detect bunched regions by looking at ALL event types at same timestamp.
    """
    from collections import Counter
    ts_counts = Counter(round(t, 3) for t in all_event_times)
    return [{'timestamp': ts, 'n_events': cnt}
            for ts, cnt in sorted(ts_counts.items()) if cnt > threshold]


def align_psychopy_to_seeg(clean_seeg, psychopy_onsets):
    """
    ITI pattern matching to find PsychoPy ↔ SEEG alignment.

    Strategy:
    1. Use first N clean SEEG ITIs for sliding-window correlation to find trial offset
    2. Fit linear model on ALL matched pairs
    3. If residual is too high (step jump), use only the first half for fitting
       and verify on the second half — if both halves have low residuals, the fit is good

    Returns:
        dict with trial_offset, slope, intercept, drift_ppm,
        residual_std_ms, residual_max_ms, n_matched
    """
    if len(clean_seeg) < 5 or len(psychopy_onsets) < 5:
        return None

    # ITI-based sliding window correlation
    seeg_itis = np.diff(clean_seeg[:min(30, len(clean_seeg))])
    psych_itis = np.diff(psychopy_onsets)

    if len(seeg_itis) < 3:
        return None

    window = min(len(seeg_itis), 20)
    best_r, best_offset = -1, 0
    for i in range(len(psych_itis) - window + 1):
        r = np.corrcoef(seeg_itis[:window], psych_itis[i:i + window])[0, 1]
        if r > best_r:
            best_r = r
            best_offset = i

    # Full linear fit
    n_match = min(len(clean_seeg), len(psychopy_onsets) - best_offset)
    seeg_matched = np.array(clean_seeg[:n_match])
    psych_matched = psychopy_onsets[best_offset:best_offset + n_match]

    a, b = np.polyfit(psych_matched, seeg_matched, 1)
    predicted = a * psych_matched + b
    residuals = seeg_matched - predicted
    residual_max = np.max(np.abs(residuals)) * 1000

    # If full fit is bad, try using only the first half (pre-jump)
    if residual_max > MAX_RESIDUAL_WARN_MS and n_match > 10:
        # Try progressively smaller subsets until residuals are acceptable
        for n_fit in [n_match // 2, n_match // 3, min(30, n_match)]:
            if n_fit < 5:
                break
            a_sub, b_sub = np.polyfit(psych_matched[:n_fit], seeg_matched[:n_fit], 1)
            # Verify on ALL clean triggers using this fit
            pred_all = a_sub * psych_matched + b_sub
            resid_all = seeg_matched - pred_all
            # Use nearest-match approach instead of 1:1
            recon_all = a_sub * psychopy_onsets + b_sub
            verify_resid = []
            for s_t in clean_seeg:
                ci = np.argmin(np.abs(recon_all - s_t))
                verify_resid.append(s_t - recon_all[ci])
            verify_resid = np.array(verify_resid)
            verify_max = np.max(np.abs(verify_resid)) * 1000

            if verify_max < MAX_RESIDUAL_WARN_MS:
                a, b = a_sub, b_sub
                predicted = a * psych_matched + b
                residuals = seeg_matched - predicted
                # Recompute using nearest-match
                residual_max = verify_max
                residual_std = np.std(verify_resid) * 1000
                return {
                    'trial_offset': int(best_offset),
                    'iti_correlation': float(best_r),
                    'slope': float(a),
                    'intercept': float(b),
                    'drift_ppm': float((a - 1) * 1e6),
                    'residual_std_ms': float(residual_std),
                    'residual_max_ms': float(residual_max),
                    'n_matched': int(n_match),
                    'fit_method': f'partial_{n_fit}_of_{n_match}',
                }

    residual_std = np.std(residuals) * 1000
    residual_max = np.max(np.abs(residuals)) * 1000

    return {
        'trial_offset': int(best_offset),
        'iti_correlation': float(best_r),
        'slope': float(a),
        'intercept': float(b),
        'drift_ppm': float((a - 1) * 1e6),
        'residual_std_ms': float(residual_std),
        'residual_max_ms': float(residual_max),
        'n_matched': int(n_match),
        'fit_method': 'full',
    }


def check_run_triggers(edf_path, task_start, task_end, stim_label,
                       behavior_csv, psychopy_onset_col, psychopy_thisN_col,
                       raw_root, event_type_mapping=None):
    """
    Check trigger quality for a single run.

    Returns:
        report dict with status, counts, bunched info, alignment results
    """
    report = {
        'edf_file': str(edf_path),
        'task_start_sec': task_start,
        'task_end_sec': task_end,
    }

    # --- Read SEEG events ---
    raw = mne.io.read_raw_edf(str(edf_path), preload=False, verbose=False)

    stim_times = []
    all_event_times = []
    for ann in raw.annotations:
        onset = ann['onset']
        desc = ann['description'].strip()
        if task_start <= onset <= task_end:
            all_event_times.append(onset)
            # Map event type
            mapped = desc
            if event_type_mapping and desc in event_type_mapping:
                mapped = event_type_mapping[desc]
            if mapped == stim_label or desc == stim_label:
                stim_times.append(onset)

    report['seeg_stim_count_raw'] = len(stim_times)

    # --- Detect bunched events ---
    clean_seeg, bunched_stim = detect_bunched_events(stim_times)
    bunched_all = detect_bunched_all_events(all_event_times)
    report['seeg_stim_count_unique'] = len(clean_seeg) + len(bunched_stim)
    report['seeg_stim_count_clean'] = len(clean_seeg)
    report['bunched_regions'] = bunched_all

    # --- Read PsychoPy data ---
    if behavior_csv and psychopy_onset_col:
        csv_path = Path(raw_root) / behavior_csv if raw_root else Path(behavior_csv)
        if csv_path.exists():
            df = pd.read_csv(csv_path)
            if psychopy_thisN_col and psychopy_thisN_col in df.columns:
                df_trials = df.dropna(subset=[psychopy_thisN_col]).reset_index(drop=True)
            else:
                df_trials = df

            report['psychopy_trial_count'] = len(df_trials)

            if psychopy_onset_col in df_trials.columns:
                psych_onsets = df_trials[psychopy_onset_col].values
                psych_onsets = psych_onsets[~np.isnan(psych_onsets)]
                report['psychopy_onset_count'] = len(psych_onsets)

                # --- Alignment ---
                alignment = align_psychopy_to_seeg(clean_seeg, psych_onsets)
                if alignment:
                    report['alignment'] = alignment
            else:
                report['psychopy_onset_count'] = 0
                report['warning'] = f"Column '{psychopy_onset_col}' not found in CSV"
        else:
            report['psychopy_trial_count'] = 0
            report['warning'] = f"Behavioral CSV not found: {csv_path}"
    else:
        report['psychopy_trial_count'] = 0

    # --- Determine status ---
    has_bunched = len(bunched_all) > 0
    count_mismatch = (report.get('psychopy_trial_count', 0) > 0 and
                      report['seeg_stim_count_raw'] != report.get('psychopy_trial_count', 0))

    if has_bunched or count_mismatch:
        alignment = report.get('alignment')
        if alignment and alignment['residual_max_ms'] < MAX_RESIDUAL_WARN_MS:
            report['status'] = 'correctable'
            report['correction_needed'] = True
        else:
            report['status'] = 'warning'
            report['correction_needed'] = True
    else:
        # Check alignment quality even for "ok" runs
        alignment = report.get('alignment')
        if alignment and alignment['residual_max_ms'] < MAX_RESIDUAL_WARN_MS:
            report['status'] = 'ok'
            report['correction_needed'] = False
        elif alignment:
            report['status'] = 'warning'
            report['correction_needed'] = False
        else:
            report['status'] = 'ok'
            report['correction_needed'] = False

    return report


# ---------------------------------------------------------------------------
# Correction functions
# ---------------------------------------------------------------------------
def reconstruct_all_events(alignment, psychopy_df, onset_col, thisN_col,
                           task_cfg, seg_start, sfreq):
    """
    Reconstruct all trial events using PsychoPy timing aligned to SEEG.

    Returns:
        list of event dicts: [{onset, duration, sample, trial_type, trial_number, ...}]
    """
    if thisN_col and thisN_col in psychopy_df.columns:
        df_trials = psychopy_df.dropna(subset=[thisN_col]).reset_index(drop=True)
    else:
        df_trials = psychopy_df.reset_index(drop=True)

    a = alignment['slope']
    b = alignment['intercept']
    p_onsets = df_trials[onset_col].values

    # Transform PsychoPy time → SEEG absolute time → segment-relative
    recon_abs = a * p_onsets + b
    recon_rel = recon_abs - seg_start

    events = []
    n_trials = len(df_trials)

    # Determine which PsychoPy columns to use for other events
    # Try to find fixation and stim_off columns
    fix_col = None
    stim_off_col = None
    for col in df_trials.columns:
        if 'fixiation.started' in col or 'fixation.started' in col:
            fix_col = col
        if '.stopped' in col and onset_col.replace('.started', '') in col.replace('.stopped', ''):
            stim_off_col = col

    has_response = task_cfg.get('has_response', False)
    resp_rt_col = task_cfg.get('response_rt_col')
    resp_key_col = task_cfg.get('response_key_col')

    for i in range(n_trials):
        trial_num = i + 1

        # Fixation
        if fix_col and fix_col in df_trials.columns and not pd.isna(df_trials.loc[i, fix_col]):
            fix_abs = a * df_trials.loc[i, fix_col] + b
            fix_rel = fix_abs - seg_start
            fix_dur = recon_rel[i] - fix_rel
            events.append({
                'onset': round(fix_rel, 6),
                'duration': round(max(fix_dur, 0), 6),
                'sample': int(round(fix_rel * sfreq)),
                'trial_type': 'fixation',
                'value': 'n/a',
                'trial_number': trial_num,
            })

        # Stimulus
        stim_dur = 0.0
        if stim_off_col and stim_off_col in df_trials.columns and not pd.isna(df_trials.loc[i, stim_off_col]):
            off_abs = a * df_trials.loc[i, stim_off_col] + b
            off_rel = off_abs - seg_start
            stim_dur = round(off_rel - recon_rel[i], 6)

        events.append({
            'onset': round(recon_rel[i], 6),
            'duration': stim_dur,
            'sample': int(round(recon_rel[i] * sfreq)),
            'trial_type': 'stimulus',
            'value': 'n/a',
            'trial_number': trial_num,
        })

        # Stimulus offset
        if stim_off_col and stim_off_col in df_trials.columns and not pd.isna(df_trials.loc[i, stim_off_col]):
            events.append({
                'onset': round(off_rel, 6),
                'duration': 0.0,
                'sample': int(round(off_rel * sfreq)),
                'trial_type': 'stimulus_offset',
                'value': 'n/a',
                'trial_number': trial_num,
            })

        # Response
        if has_response and resp_rt_col and resp_rt_col in df_trials.columns:
            if not pd.isna(df_trials.loc[i, resp_rt_col]):
                rt = df_trials.loc[i, resp_rt_col]
                resp_onset = recon_rel[i] + rt
                events.append({
                    'onset': round(resp_onset, 6),
                    'duration': 0.0,
                    'sample': int(round(resp_onset * sfreq)),
                    'trial_type': 'response',
                    'value': 'n/a',
                    'trial_number': trial_num,
                })

    return events, df_trials


def correct_vmrk(vmrk_path, reconstructed_events, task_start_rel, task_end_rel,
                 sfreq, backup=True):
    """
    Replace .vmrk markers with PsychoPy-reconstructed events.
    Backs up original as .vmrk.orig.
    """
    vmrk_path = Path(vmrk_path)

    if backup and vmrk_path.exists():
        orig_path = vmrk_path.with_suffix('.vmrk.orig')
        if not orig_path.exists():
            shutil.copy2(vmrk_path, orig_path)

    # Read header
    with open(vmrk_path) as f:
        lines = f.readlines()
    header = [l for l in lines if not l.startswith('Mk')]

    # Event type → vmrk label mapping
    type_to_label = {
        'fixation': 'fixation',
        'stimulus': 'stim_on',
        'stimulus_offset': 'stim_off',
        'response': 'response',
    }

    # Build markers
    markers = []
    mk_num = 1

    # task_start marker
    markers.append(f'Mk{mk_num}=Comment,task_start,{int(round(task_start_rel * sfreq))},0,0\n')
    mk_num += 1

    for evt in reconstructed_events:
        label = type_to_label.get(evt['trial_type'], evt['trial_type'])
        sample = evt['sample']
        markers.append(f'Mk{mk_num}=Comment,{label},{sample},0,0\n')
        mk_num += 1

    # task_end marker
    markers.append(f'Mk{mk_num}=Comment,task_end,{int(round(task_end_rel * sfreq))},0,0\n')
    mk_num += 1

    with open(vmrk_path, 'w') as f:
        f.writelines(header)
        f.writelines(markers)

    return mk_num - 1


def correct_events_tsv(events_tsv_path, reconstructed_events, behavior_df,
                       task_cfg, sfreq, backup=True):
    """
    Replace events.tsv with PsychoPy-reconstructed events.
    Backs up original as .tsv.orig.
    """
    events_tsv_path = Path(events_tsv_path)

    if backup and events_tsv_path.exists():
        orig_path = events_tsv_path.with_suffix('.tsv.orig')
        if not orig_path.exists():
            shutil.copy2(events_tsv_path, orig_path)

    events_df = pd.DataFrame(reconstructed_events)

    # Add behavioral columns
    stim_columns = task_cfg.get('stim_columns', [])
    existing_cols = [c for c in stim_columns if c in behavior_df.columns]
    for col in existing_cols:
        events_df[col] = events_df['trial_number'].apply(
            lambda tn: behavior_df.loc[tn - 1, col] if tn - 1 < len(behavior_df) else 'n/a'
        )

    # Response columns
    resp_key_col = task_cfg.get('response_key_col')
    resp_corr_col = task_cfg.get('response_corr_col')
    resp_rt_col = task_cfg.get('response_rt_col')

    if resp_key_col:
        resp_mask = events_df['trial_type'] == 'response'
        events_df['response_key'] = 'n/a'
        events_df['response_correct'] = 'n/a'
        events_df['response_time'] = 'n/a'
        for idx in events_df[resp_mask].index:
            tn = events_df.loc[idx, 'trial_number'] - 1
            if tn < len(behavior_df):
                if resp_key_col and resp_key_col in behavior_df.columns:
                    events_df.loc[idx, 'response_key'] = str(behavior_df.loc[tn, resp_key_col])
                if resp_corr_col and resp_corr_col in behavior_df.columns:
                    events_df.loc[idx, 'response_correct'] = str(behavior_df.loc[tn, resp_corr_col])
                if resp_rt_col and resp_rt_col in behavior_df.columns:
                    events_df.loc[idx, 'response_time'] = str(behavior_df.loc[tn, resp_rt_col])

    events_df.to_csv(events_tsv_path, sep='\t', index=False)
    return len(events_df)


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------
def run(config, bids_root=None, auto_correct=True, **kwargs):
    """
    Run trigger verification for all active sessions/tasks.
    """
    if bids_root is None:
        bids_root = utils.get_bids_root()
    bids_root = Path(bids_root)
    raw_root = utils.get_raw_root(config)
    sub = config['participant_id']
    sfreq = config['seeg']['sampling_rate']
    event_type_mapping = utils.get_event_type_mapping(config)

    # Load segment_info
    seg_info_path = bids_root / 'code' / 'segment_info.json'
    with open(seg_info_path) as f:
        segment_info = json.load(f)

    report = {
        'generated': datetime.now().isoformat(),
        'patient': sub,
        'auto_correct': auto_correct,
        'runs': {},
    }

    sessions = utils.filter_sessions(config)
    for ses_key, ses_cfg in sessions.items():
        if 'ieeg' not in ses_cfg.get('modalities', []):
            continue

        for task_cfg in utils.get_active_tasks(ses_cfg):
            bids_task = task_cfg['bids_task']
            run_num = task_cfg['run']
            run_key = f"{ses_key}/{bids_task}/run-{run_num:02d}"

            print(f"\n--- Checking {run_key} ---")

            # Find segment info
            seg = segment_info.get(run_key)
            if not seg:
                print(f"  WARNING: No segment_info for {run_key}, skipping")
                report['runs'][run_key] = {'status': 'skipped', 'reason': 'no segment_info'}
                continue

            # Determine which stim label to look for in EDF
            stim_label = 'stimulus'
            # For day1 tasks the EDF label might be "stimuli" or "fixation" depending on trigger_event
            trigger_event = task_cfg.get('trial_grouping', {}).get('trigger_event', 'fixation')
            required_events = task_cfg.get('trial_grouping', {}).get('required_events', ['stimulus'])

            # We want to count the main stimulus event in SEEG
            # Map back from standard name to possible EDF labels
            reverse_map = {}
            for edf_label, std_name in event_type_mapping.items():
                reverse_map.setdefault(std_name, []).append(edf_label)

            # Use "stimulus" as the default check target
            stim_edf_labels = reverse_map.get('stimulus', ['stimulus', 'stimuli', 'stim_on'])

            # Get stim events from EDF
            edf_path = seg['edf_source']
            raw = mne.io.read_raw_edf(str(edf_path), preload=False, verbose=False)

            stim_times = []
            all_event_times = []
            for ann in raw.annotations:
                onset = ann['onset']
                desc = ann['description'].strip()
                if seg['task_start_sec'] <= onset <= seg['task_end_sec']:
                    all_event_times.append(onset)
                    if desc in stim_edf_labels:
                        stim_times.append(onset)

            # Detect bunched
            clean_seeg, _ = detect_bunched_events(stim_times)
            bunched_all = detect_bunched_all_events(all_event_times)

            # PsychoPy data
            behavior_csv = task_cfg.get('behavior_csv')
            onset_col = task_cfg.get('psychopy_onset_col')
            thisN_col = task_cfg.get('psychopy_thisN_col')

            psych_onsets = None
            psych_df = None
            n_psych = 0
            if behavior_csv and onset_col:
                csv_path = Path(raw_root) / behavior_csv
                if csv_path.exists():
                    df = pd.read_csv(csv_path)
                    if thisN_col and thisN_col in df.columns:
                        psych_df = df.dropna(subset=[thisN_col]).reset_index(drop=True)
                    else:
                        psych_df = df.reset_index(drop=True)
                    n_psych = len(psych_df)
                    if onset_col in psych_df.columns:
                        psych_onsets = psych_df[onset_col].dropna().values

            # Alignment
            alignment = None
            if psych_onsets is not None and len(clean_seeg) >= 5:
                alignment = align_psychopy_to_seeg(clean_seeg, psych_onsets)

            # Build report
            has_bunched = len(bunched_all) > 0
            count_mismatch = n_psych > 0 and len(stim_times) != n_psych

            run_report = {
                'seeg_stim_count': len(stim_times),
                'psychopy_trial_count': n_psych,
                'bunched_regions': bunched_all,
                'count_match': not count_mismatch,
            }

            if alignment:
                run_report['iti_correlation'] = alignment['iti_correlation']
                run_report['max_residual_ms'] = alignment['residual_max_ms']
                run_report['drift_ppm'] = alignment['drift_ppm']
                run_report['alignment'] = alignment

            needs_correction = has_bunched or count_mismatch

            if needs_correction:
                print(f"  ISSUE: stim_count={len(stim_times)} vs psychopy={n_psych}, "
                      f"bunched={len(bunched_all)}")
                if alignment and alignment['residual_max_ms'] < MAX_RESIDUAL_WARN_MS:
                    run_report['status'] = 'correctable'
                else:
                    run_report['status'] = 'warning'
                    if alignment:
                        print(f"  WARNING: residual too high ({alignment['residual_max_ms']:.1f}ms)")

                # Auto-correct if enabled and alignment is good
                if auto_correct and alignment and alignment['residual_max_ms'] < MAX_RESIDUAL_WARN_MS:
                    print(f"  Applying PsychoPy-based correction...")
                    seg_start = seg['segment_start_sec']

                    recon_events, beh_df = reconstruct_all_events(
                        alignment, psych_df, onset_col, thisN_col,
                        task_cfg, seg_start, sfreq)

                    # Correct vmrk
                    ses_dir = bids_root / sub / ses_key / 'ieeg'
                    prefix = f'{sub}_{ses_key}_task-{bids_task}_run-{run_num:02d}'
                    vmrk_path = ses_dir / f'{prefix}_ieeg.vmrk'
                    task_start_rel = seg['task_start_sec'] - seg_start
                    task_end_rel = seg['task_end_sec'] - seg_start

                    n_markers = correct_vmrk(vmrk_path, recon_events,
                                             task_start_rel, task_end_rel, sfreq)

                    # Correct events.tsv
                    events_path = ses_dir / f'{prefix}_events.tsv'
                    n_rows = correct_events_tsv(events_path, recon_events,
                                                beh_df, task_cfg, sfreq)

                    run_report['status'] = 'corrected'
                    run_report['correction_applied'] = True
                    run_report['correction_method'] = 'iti_pattern_match + linear_fit'
                    run_report['correction_accuracy_ms'] = alignment['residual_max_ms']
                    run_report['corrected_vmrk_markers'] = n_markers
                    run_report['corrected_events_rows'] = n_rows
                    run_report['original_backed_up'] = True
                    print(f"  CORRECTED: {n_markers} markers, {n_rows} events rows")
            else:
                run_report['status'] = 'ok'
                run_report['correction_needed'] = False
                if alignment:
                    print(f"  OK: {len(stim_times)} triggers, "
                          f"residual={alignment['residual_max_ms']:.1f}ms")
                else:
                    print(f"  OK: {len(stim_times)} triggers (no PsychoPy alignment)")

            report['runs'][run_key] = run_report

    # Save report
    report_path = bids_root / 'code' / 'trigger_report.json'
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2, default=str)
    print(f"\n=== Report saved: {report_path} ===")

    # Summary
    statuses = [r.get('status', 'unknown') for r in report['runs'].values()]
    print(f"\nSummary: {len(statuses)} runs checked")
    for s in ['ok', 'corrected', 'correctable', 'warning', 'skipped']:
        n = statuses.count(s)
        if n > 0:
            print(f"  {s}: {n}")

    return report


def main():
    parser = argparse.ArgumentParser(description='Verify SEEG trigger quality')
    parser.add_argument('--config', type=str, default=None,
                        help='Path to YAML config file')
    parser.add_argument('--no-correct', action='store_true',
                        help='Do not auto-correct, only report')
    args = parser.parse_args()

    config_path = args.config or utils.get_config_path()
    config = utils.load_config(config_path)
    bids_root = utils.get_bids_root()

    run(config, bids_root=bids_root, auto_correct=not args.no_correct)


if __name__ == '__main__':
    main()
