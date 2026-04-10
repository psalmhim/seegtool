# SEEGRING — SEEG Population Dynamics Pipeline

## Overview

MATLAB pipeline for stereo-EEG (SEEG) population dynamics analysis.
Processes BIDS-formatted intracranial EEG through 18 stages: raw data → publication figures.

- **Subject**: EP01AN96M1047 (188 channels, 2048 Hz → resampled 512 Hz, BrainVision format)
- **Data**: `/Volumes/OHDD/DATA/epilepsy/` (BIDS structure)
- **Results**: `/Volumes/OHDD/DATA/epilepsy/derivatives/seegring/sub-EP01AN96M1047/`
- **MATLAB**: R2025b on macOS arm64

## Pipeline Stages (18 total)

Each stage saves to `results/stageNN_*.mat` independently → resumable, memory-efficient.

| Stage | File | Description |
|-------|------|-------------|
| 1 | `stage01_bids.mat` | Load BIDS data, channels, events, filter by condition |
| 2 | `stage02_config.mat` | Build task-specific configuration |
| 2b | `stage02b_tissue.mat` | **Optional** contact tissue classification (GM/WM) |
| 3 | `stage03_preproc.mat` | Rereferencing, filtering, artifact detection, resample 2048→512 Hz |
| 4 | `stage04_epochs.mat` | Extract event-locked trials (trials × channels × time) |
| 5 | `stage05_qc.mat` | Trial quality (green/yellow/red), weights |
| 6 | `stage06_erp.mat` | Event-related potentials + SEM |
| 7 | `stage07_timefreq.mat` | Continuous CWT → epoch (avoids edge artifacts) |
| 8 | `stage08_phase.mat` | Inter-trial phase coherence (ITPC) |
| 9 | `stage09_stats.mat` | Permutation tests across conditions |
| 9b | `stage09b_tf_stats.mat` | TF cluster permutation, adaptive peaks, MVPA, PAC |
| 10-11 | `stage11_latent.mat` | Population tensor → PCA → latent trajectories |
| 12 | `stage12_geometry.mat` | Trajectory geometry, condition separation |
| 13 | `stage13_dynamics.mat` | jPCA, dynamical systems |
| 14 | `stage14_decoding.mat` | Time-resolved neural decoding (LDA/logistic) |
| 14b | `stage14b_contrasts.mat` | Hierarchical contrast analysis (L1→L2) |
| 15 | `stage15_bootstrap.mat` | Bootstrap confidence tubes |
| 16 | `stage16_roi.mat` | Per-region latent analysis |
| 17 | figures/ | Publication figures (PDF + PNG) |
| 18 | `summary.mat` | Metadata, completion status |

## Directory Structure

```
seegring/
├── CLAUDE.md
├── code/
│   ├── process_bids_run.m    ← MAIN PIPELINE (18 stages, resumable)
│   ├── add_paths.m           ← adds all subdirs + fCWT to MATLAB path
│   ├── bids/                 ← BIDS I/O, events, electrodes, tissue classification
│   ├── config/               ← default_config.m, build_task_config.m
│   ├── preprocessing/        ← reref, filtering, artifact detection
│   ├── epoching/             ← event-locked trial extraction
│   ├── qc/                   ← trial quality assessment
│   ├── erp/                  ← ERP computation
│   ├── timefreq/             ← CWT backends, baseline normalization
│   │   ├── compute_tf_continuous_epoch.m  ← main TF function
│   │   └── compute_time_frequency.m       ← legacy per-epoch TF
│   ├── phase/                ← ITPC
│   ├── stats/                ← permutation statistics
│   ├── population/           ← population tensor, normalization (NaN-safe)
│   ├── latent/               ← PCA/FA/GPFA (NaN-safe)
│   ├── geometry/             ← trajectory geometry, separation
│   ├── dynamics/             ← jPCA, dynamical systems
│   ├── decoding/             ← LDA/logistic decoder, cross-validation (NaN-safe)
│   ├── contrasts/            ← hierarchical L1→L2 contrast analysis
│   ├── uncertainty/          ← bootstrap confidence intervals
│   ├── visualization/        ← Nature-style publication figures
│   ├── dashboard/            ← HTML dashboard for pipeline monitoring
│   ├── reporting/            ← report templates
│   └── utils/                ← general utilities
├── tools/fCWT/               ← fast CWT MEX (arm64)
├── run_single_test.m         ← test: single saliencepain run
├── run_EP01AN96M1047_all_tasks.m  ← batch: all tasks
└── open_dashboard.m          ← launch HTML dashboard
```

## Key Design Decisions

### Time-Frequency: Continuous CWT → Epoch
- `compute_tf_continuous_epoch.m` runs CWT on full continuous signal per channel, then epochs
- Avoids edge artifacts from per-epoch CWT (critical for low frequencies)
- **Backend priority**: fCWT MEX → MATLAB `cwt()` → manual Morlet (auto-fallback)
- Auto-selects best available backend; smoke-tests before committing
- Force backend: `cfg.tf_backend = 'matlab_cwt'` or `'morlet'`

### Resumability & Memory
- Each stage checks `isfile(sf('stageNN_name'))` → skip if done
- Delete a stage file to force re-run
- Large variables cleared after saving (`tf_power`, `cleaned`, `pop_tensor`)
- `build_result_for_viz()` loads only needed fields for plotting

### NaN Safety
- `normalize_population_tensor`: uses `'omitnan'` for mean/std
- `fit_pca_model`: replaces NaN→0 before PCA, clamps negative eigenvalues
- `train_linear_decoder`: NaN/Inf→0, regularization `1e-3`, uses `\` not `inv()`
- `run_cross_validation`: works with numeric indices internally, handles NaN features
- `lda_classify` (in `run_tf_multivariate_stats.m`): removes zero-var features, adaptive regularization

### Stage File Struct Nesting (Critical for Loading)
When loading stage files, variables are nested inside structs:
- `stage12_geometry.mat`: `separation.index`, `separation.p_values`, `separation.time_vec`, `geom`
- `stage14_decoding.mat`: `decoding.accuracy_time`, `decoding.onset_time`, `decoding.p_values`
- `stage13_dynamics.mat`: `dynamics.state_space.effective_dimensionality`, `dynamics.jpca.R2`
- `stage14b_contrasts.mat`: `contrast_results` (top-level struct array), `contrasts`
- `stage09b_tf_stats.mat`: `tf_stats` (top-level struct)
- Use `load_task_metrics(run_output)` helper to load all metrics correctly

### Condition Separation Statistics
- `compute_time_resolved_separation.m`: S(t) = ||centroid_A - centroid_B|| / (disp_A + disp_B + λ)
- Denominator regularized: λ = 0.1 × median(all dispersion values)
- Cluster-corrected p-values (Maris & Oostenveld 2007): cluster mass vs null max-cluster distribution
- 1000 permutations (set in `build_task_config.m`, not hardcoded in geometry functions)

### Contact Tissue Filtering (Optional)
- **Default**: OFF (`cfg.filter_tissue = false`) — all contacts included
- Enable: `cfg.filter_tissue = true`
- Methods: `'atlas'` (MNI coords + NIfTI atlas), `'neighbor'` (shaft heuristic), `'manual'` (TSV file)
- Atlas available: `/Volumes/OHDD/DATA/epilepsy/dTOR/rmonet_aal131.nii` (AAL131)
- Saves classification to `stage02b_tissue.mat`
- Config fields: `tissue_method`, `tissue_atlas_nii`, `tissue_manual_file`, `tissue_radius_mm`

### Contrast System
- `build_task_contrasts.m`: task-specific defaults (switch/case per task)
- `define_contrasts.m`: generates contrast specs from condition labels
  - Types: `all_pairwise`, `one_vs_rest`, `first_vs_rest`, `sequential`, `custom`, `factorial`
- `run_contrast_analysis.m`: L1 (per-condition betas) → L2 (contrast weights + permutation)
- Uses cell array internally for uniform struct fields (prevents "dissimilar structures" error)
- To add contrasts for a new task:
  ```matlab
  % In build_task_contrasts.m, add:
  case 'yourtask'
      specs = {struct('name', 'A > B', 'A', {{'condA'}}, 'B', {{'condB'}})};
      contrasts = define_contrasts(condition_labels, 'type', 'custom', 'specs', specs);
  ```

## Tasks (EP01AN96M1047)

| Task ID | Name | Conditions | Epoch Window |
|---------|------|-----------|--------------|
| task05 | saliencepain | pain, noPain | -2.0 to +5.0s |
| task06 | lexicaldecision | by direction | -1.0 to +2.0s |
| task09 | viseme | viseme categories | -0.5 to +2.5s |
| task10 | balloonwatching | anticipation levels | -0.5 to +1.5s |

## fCWT Setup

MEX binary at `tools/fCWT/MATLAB/fCWT.mexmaca64` (arm64, compiled with R2025a).
Rpaths patched via `install_name_tool` for:
- `libfCWT.2.0.dylib` → `tools/fCWT/buildosxm1/`
- MATLAB R2025b libs → `/Applications/MATLAB_R2025b.app/`

Wisdom files (`.wis`) in `tools/fCWT/MATLAB/` optimize FFT per signal length.
Auto-created on first run via `fCWT_create_plan()`.

**Known**: fCWT prints C-level `WARNING: Optimization scheme...` to stdout (cosmetic, not suppressible from MATLAB). Thread warning suppressed via `warning('off', 'fcwt:nothreads')`.

## Running

```matlab
run_single_test              % single saliencepain run
run_EP01AN96M1047_all_tasks  % all tasks
open_dashboard               % HTML status dashboard
```

## Common Operations

```matlab
% Force re-run of specific stage
delete('results/stage07_timefreq.mat')

% Force re-run from stage 11 onward
delete('results/stage11_latent.mat')
delete('results/stage12_geometry.mat')
% ... etc

% Use MATLAB cwt instead of fCWT
cfg.tf_backend = 'matlab_cwt';

% Enable gray matter filtering
cfg.filter_tissue = true;
cfg.tissue_atlas_nii = '/Volumes/OHDD/DATA/epilepsy/dTOR/rmonet_aal131.nii';

% Check pipeline status
status = check_pipeline_status(results_dir, runs);
generate_dashboard(results_dir, status);
```

## Dependencies

- MATLAB R2025b (or R2025a)
- EEGLAB with bva-io plugin (BrainVision import)
- Wavelet Toolbox (fallback CWT backend)
- Signal Processing Toolbox
- Statistics Toolbox (optional)

## Recent Fixes

### 2026-03-25
- **Separation test**: cluster-corrected permutation (Maris & Oostenveld), denominator regularization, 1000 perms
- **Field name mismatches**: `load_task_metrics.m` now reads nested struct fields correctly (`separation.index` not `separation_index`)
- **Report generators**: `generate_markdown_report.m`, `generate_latex_report.m`, `write_stats_table.m` all use `load_task_metrics()` instead of summary struct
- **Config**: 10 latent dims (was 6), 10ms smoothing (was 20ms), 1000 perms (was 500)
- **LDA MVPA**: adaptive regularization, zero-variance feature removal
- **Stage 9b**: TF cluster permutation, adaptive peaks, band contrasts, MVPA, PAC
- **Resampling**: 2048→512 Hz in Stage 3 (zero info loss, fixes visualrhythm OOM)
- **Event filtering**: `filter_events_by_type` uses `.trial_type` field (TSV `condition` column no longer overwrites)

### 2026-03-17
- Continuous CWT→epoch replaces per-epoch CWT (Stage 7)
- NaN-safe PCA, normalization, and decoding
- Contrast analysis: uniform struct fields via cell array + make_empty_cr()
- fCWT rpaths fixed for R2025b, wisdom auto-creation
- Tissue filtering as optional pipeline config
- `isfield(cfg, 'filter_tissue')` guard for backward compatibility with old configs
