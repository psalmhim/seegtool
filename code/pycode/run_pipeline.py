#!/usr/bin/env python3
"""
YUHS SEEG BIDS Pipeline — Interactive CLI

Usage:
    python3 run_pipeline.py                     # Interactive mode (new patient)
    python3 run_pipeline.py --config <yaml>     # Run with existing config
    python3 run_pipeline.py --config <yaml> --steps scaffold,split_edf  # Run specific steps
    python3 run_pipeline.py --config <yaml> --add-session  # Add new session to existing patient
"""

import argparse
import subprocess
import sys
import json
from pathlib import Path
from datetime import datetime

import yaml

import utils
from scan_edf import scan_edf_annotations, print_scan_report, format_time, format_duration


# ──────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────

PIPELINE_STEPS = [
    ("scaffold",        "bids_scaffold.py",     "BIDS 디렉토리 + 메타데이터 생성"),
    ("split_edf",       "split_edf.py",         "EDF → BrainVision 과제별 분할"),
    ("sidecars",        "create_sidecars.py",   "channels/electrodes/coordsystem/ieeg.json"),
    ("events",          "create_events.py",     "events.tsv 생성 (SEEG trigger + 행동데이터)"),
    ("verify_triggers", "verify_triggers.py",   "Trigger 품질 검증 + PsychoPy 보정"),
    ("copy_anat",       "copy_anat.py",         "해부학적 영상 + derivatives 복사"),
    ("transform_mni",   "transform_mni.py",     "전극 좌표 MNI152 변환 (ANTs SyN)"),
    ("readmes",         "create_readmes.py",    "README.md 생성"),
    ("validate",        "validate_bids.py",     "BIDS 검증"),
]

KNOWN_TASKS = {
    "lexicaldecision": "Visual word/nonword discrimination task.",
    "shapecontrol": "Shape matching control task.",
    "sentencenoun": "Sentence-noun semantic judgment task.",
    "sentencegrammar": "Sentence grammaticality judgment task.",
    "saliencepain": "Passive viewing of pain-related images.",
    "balloonwatching": "Passive viewing of balloon inflation videos.",
    "viseme": "Visual speech perception 2-AFC task.",
    "visemegen": "Visual speech generalization 2-AFC task.",
    "visualrhythm": "Passive viewing of lip rhythm videos.",
}


# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────

def ask(prompt, default=None, validator=None):
    """Prompt user for input with optional default and validator."""
    suffix = f" [{default}]" if default else ""
    while True:
        answer = input(f"{prompt}{suffix}: ").strip()
        if not answer and default is not None:
            answer = str(default)
        if not answer:
            print("  → 입력이 필요합니다.")
            continue
        if validator:
            err = validator(answer)
            if err:
                print(f"  → {err}")
                continue
        return answer


def ask_yn(prompt, default=True):
    """Yes/No question."""
    hint = "Y/n" if default else "y/N"
    answer = input(f"{prompt} [{hint}]: ").strip().lower()
    if not answer:
        return default
    return answer in ('y', 'yes', '예', 'ㅇ')


def ask_choice(prompt, choices, default=None):
    """Choose from a list."""
    for i, (key, desc) in enumerate(choices):
        marker = " *" if key == default else ""
        print(f"  [{i+1}] {key}: {desc}{marker}")
    while True:
        answer = input(f"{prompt}: ").strip()
        if not answer and default:
            return default
        try:
            idx = int(answer) - 1
            if 0 <= idx < len(choices):
                return choices[idx][0]
        except ValueError:
            # Try matching by key
            for key, _ in choices:
                if answer == key:
                    return key
        print(f"  → 1~{len(choices)} 사이 숫자를 입력하세요.")


def ask_path(prompt, must_exist=True, extensions=None):
    """Ask for a file path."""
    while True:
        path_str = input(f"{prompt}: ").strip()
        if not path_str:
            print("  → 경로를 입력하세요.")
            continue
        p = Path(path_str).expanduser()
        if must_exist and not p.exists():
            print(f"  → 파일을 찾을 수 없습니다: {p}")
            continue
        if extensions and p.suffix.lower() not in extensions:
            print(f"  → 지원하는 확장자: {extensions}")
            continue
        return p


def ask_multi_path(prompt, extensions=None):
    """Ask for multiple file paths (one per line, empty line to finish)."""
    print(f"{prompt} (한 줄에 하나, 빈 줄로 종료):")
    paths = []
    while True:
        line = input("  > ").strip()
        if not line:
            break
        p = Path(line).expanduser()
        if not p.exists():
            print(f"    → 파일을 찾을 수 없습니다: {p}")
            continue
        if extensions and p.suffix.lower() not in extensions:
            print(f"    → 지원하는 확장자: {extensions}")
            continue
        paths.append(p)
    return paths


def run_step(script_name, config_path, extra_args=None):
    """Run a pipeline step as subprocess."""
    code_dir = Path(__file__).parent
    script = code_dir / script_name
    cmd = [sys.executable, str(script), '--config', str(config_path)]
    if extra_args:
        cmd.extend(extra_args)
    print(f"\n{'─'*60}")
    print(f"  실행: {script_name}")
    print(f"{'─'*60}")
    result = subprocess.run(cmd, cwd=str(code_dir))
    return result.returncode == 0


# ──────────────────────────────────────────────────────────────
# Interactive config builder
# ──────────────────────────────────────────────────────────────

def collect_demographics():
    """Collect patient demographics interactively."""
    print("\n━━━ 환자 기본 정보 ━━━")
    pid = ask("환자 ID (예: sub-EP01AN96M1047)")
    if not pid.startswith("sub-"):
        pid = f"sub-{pid}"
    age = ask("연령", validator=lambda x: None if x.isdigit() else "숫자를 입력하세요")
    sex = ask_choice("성별", [("M", "남성"), ("F", "여성")])
    hand = ask_choice("우세손", [("R", "오른손"), ("L", "왼손"), ("A", "양손")], default="R")
    pathology = ask("진단명", default="drug-resistant epilepsy")
    return {
        'participant_id': pid,
        'demographics': {
            'age': int(age),
            'sex': sex,
            'handedness': hand,
            'pathology': pathology,
        }
    }


def collect_seeg_info():
    """Collect SEEG recording parameters."""
    print("\n━━━ SEEG 녹화 정보 ━━━")
    sr = ask("Sampling rate (Hz)", default="2048",
             validator=lambda x: None if x.isdigit() else "숫자를 입력하세요")
    mfr = ask("장비 제조사", default="Natus")
    model = ask("장비 모델", default="XLTEK")
    ref = ask("Reference", default="white matter")
    freq = ask("Power line frequency (Hz)", default="60",
               validator=lambda x: None if x.isdigit() else "숫자를 입력하세요")
    elec_path = ask("전극 좌표 파일 경로 (elec.tsv)")

    return {
        'seeg': {
            'sampling_rate': int(sr),
            'manufacturer': mfr,
            'manufacturer_model': model,
            'reference': ref,
            'power_line_frequency': int(freq),
            'electrode_file': elec_path,
            'coordinate_system': 'Other',
            'coordinate_system_description': 'Native T1w MRI space, post-implant CT co-registered to pre-op T1w',
            'coordinate_units': 'mm',
        }
    }


def collect_soz_info():
    """Collect seizure onset zone info."""
    print("\n━━━ Seizure Onset Zone ━━━")
    if not ask_yn("SOZ 전극 정보를 입력하시겠습니까?", default=False):
        return {'soz': {'electrodes': [], 'description': '', 'determination_method': ''}}

    electrodes_str = ask("SOZ 전극 이름 (쉼표 구분, 예: LA_1,LA_2,LH_3)")
    electrodes = [e.strip() for e in electrodes_str.split(',') if e.strip()]
    desc = ask("SOZ 설명", default="")
    method = ask("결정 방법", default="clinical consensus from SEEG monitoring")

    return {
        'soz': {
            'electrodes': electrodes,
            'description': desc,
            'determination_method': method,
        }
    }


def collect_modalities():
    """Ask which modalities to include."""
    print("\n━━━ 포함할 Modality 선택 ━━━")
    mods = {}
    for mod, desc in [('anat', '해부학적 MRI (T1w, FLAIR, CT)'),
                       ('dwi', 'Diffusion (DTI)'),
                       ('func', 'fMRI (resting state)'),
                       ('pet', 'PET'),
                       ('ieeg', 'iEEG (SEEG)'),
                       ('derivatives', 'Derivatives (FreeSurfer, tractography, etc.)')]:
        mods[mod] = ask_yn(f"  {mod} ({desc})?", default=True)
    return {'modalities_include': mods}


def collect_edf_sessions(raw_root):
    """Scan EDF files and interactively map tasks."""
    print("\n━━━ EDF 파일 스캔 ━━━")
    edfs = ask_multi_path("EDF 파일 경로들", extensions=['.edf'])
    if not edfs:
        print("EDF 파일이 없습니다. ieeg 세션을 건너뜁니다.")
        return {}, {}

    annotation_schemes = {}
    sessions = {}

    for edf_path in edfs:
        # Scan annotations
        print(f"\n  스캔 중: {edf_path.name} ...")
        result = scan_edf_annotations(edf_path)
        print_scan_report(edf_path, result)

        # Relative path for config
        try:
            rel_path = str(edf_path.relative_to(raw_root))
        except ValueError:
            rel_path = str(edf_path)

        # Ask user to map each task boundary
        if not result['task_boundaries']:
            print("  → task boundary를 찾을 수 없습니다. 건너뜁니다.")
            continue

        print(f"\n  {len(result['task_boundaries'])}개의 task가 감지되었습니다.")
        if result['interrupted']:
            print(f"  {len(result['interrupted'])}개의 중단된 task가 있습니다.")

        user_mappings = []
        boundaries_to_map = result['task_boundaries']

        for i, (start, end, label) in enumerate(boundaries_to_map):
            dur = end - start
            print(f"\n  Task [{i+1}/{len(boundaries_to_map)}]: "
                  f"{format_time(start)} ~ {format_time(end)} ({format_duration(dur)}) [{label}]")

            if not ask_yn("  이 task를 포함하시겠습니까?", default=True):
                continue

            ses_key = ask(f"  세션 키 (예: ses-task01)")
            if not ses_key.startswith("ses-"):
                ses_key = f"ses-{ses_key}"

            bids_task = ask(f"  BIDS task label (예: lexicaldecision)")
            run = int(ask(f"  Run 번호", default="1",
                         validator=lambda x: None if x.isdigit() else "숫자를 입력하세요"))

            task_date = ask(f"  촬영 일자 (YYYY-MM-DD)")
            purpose = ask(f"  세션 설명", default=KNOWN_TASKS.get(bids_task, ""))

            has_response = ask_yn(f"  반응(response)이 있는 과제입니까?", default=True)

            behavior_csv = ""
            psychopy_onset_col = ""
            psychopy_thisN_col = ""
            if ask_yn(f"  PsychoPy 행동데이터 CSV가 있습니까?", default=True):
                behavior_csv = ask(f"  CSV 경로 (raw_root 기준 상대경로)")
                psychopy_onset_col = ask(f"  PsychoPy stimulus onset 컬럼명 (예: movie_viseme.started)")
                psychopy_thisN_col = ask(f"  PsychoPy thisN 컬럼명 (예: block01.thisN)")

            n_expected = ask(f"  예상 trial 수", default="0",
                            validator=lambda x: None if x.isdigit() else "숫자를 입력하세요")

            mapping = {'ses': ses_key, 'bids_task': bids_task, 'run': run}
            user_mappings.append(mapping)

            # Build task config
            task_cfg = {
                'bids_task': bids_task,
                'run': run,
                'task_name': purpose,
                'has_response': has_response,
                'trial_grouping': {
                    'trigger_event': 'fixation',
                    'required_events': ['stimulus'],
                    'optional_events': ['stimulus_offset', 'response'] if has_response else [],
                },
                'n_expected_trials': int(n_expected),
            }
            if behavior_csv:
                task_cfg['behavior_csv'] = behavior_csv
                task_cfg['psychopy_onset_col'] = psychopy_onset_col
                task_cfg['psychopy_thisN_col'] = psychopy_thisN_col

            # Add response columns if applicable
            if has_response:
                resp_key = ask(f"  response key 컬럼명", default="")
                if resp_key:
                    task_cfg['response_key_col'] = resp_key
                    task_cfg['response_corr_col'] = ask(f"  response corr 컬럼명", default="")
                    task_cfg['response_rt_col'] = ask(f"  response rt 컬럼명", default="")

            # Add to sessions dict
            if ses_key not in sessions:
                sessions[ses_key] = {
                    'date': task_date,
                    'context': 'monitoring',
                    'purpose': purpose,
                    'modalities': ['ieeg'],
                    'edf_files': [rel_path],
                    'tasks': [],
                }
            else:
                if rel_path not in sessions[ses_key].get('edf_files', []):
                    sessions[ses_key]['edf_files'].append(rel_path)
            sessions[ses_key]['tasks'].append(task_cfg)

        # Build annotation scheme from scan result
        from scan_edf import generate_annotation_scheme
        if user_mappings:
            scheme = generate_annotation_scheme(result, user_mappings)
            annotation_schemes[rel_path] = scheme

    return sessions, annotation_schemes


def collect_imaging_sessions():
    """Collect non-iEEG session info (preop, postimplant)."""
    print("\n━━━ 뇌영상 세션 정보 ━━━")
    sessions = {}

    if ask_yn("Pre-operative 영상 세션이 있습니까?", default=True):
        date = ask("  촬영 일자 (YYYY-MM-DD)")
        mods = []
        for m in ['anat', 'dwi', 'func', 'pet']:
            if ask_yn(f"  {m} 포함?", default=True):
                mods.append(m)
        sessions['ses-preop'] = {
            'date': date,
            'context': 'preoperative',
            'purpose': 'Presurgical MRI workup',
            'modalities': mods,
        }

    if ask_yn("Post-implant 영상 세션이 있습니까?", default=True):
        date = ask("  촬영 일자 (YYYY-MM-DD)")
        mods = []
        for m in ['anat', 'dwi', 'func']:
            if ask_yn(f"  {m} 포함?", default=True):
                mods.append(m)
        sessions['ses-postimplant'] = {
            'date': date,
            'context': 'postimplant',
            'purpose': 'Post-SEEG electrode implantation CT and MRI',
            'modalities': mods,
        }

    return sessions


def collect_neuroimaging_paths():
    """Collect neuroimaging source file paths."""
    print("\n━━━ 뇌영상 소스 파일 경로 ━━━")
    print("(raw_data_root 기준 상대경로로 입력)")

    neuroimaging = {}

    if ask_yn("Preop 영상 경로를 입력하시겠습니까?", default=True):
        preop = {}
        for key, desc in [('T1w', 'T1w MRI'), ('FLAIR', 'FLAIR'), ('dwi', 'DWI'),
                          ('func_rest', 'resting fMRI'), ('pet', 'PET')]:
            if ask_yn(f"  {desc} 있습니까?", default=True):
                preop[key] = ask(f"    {desc} 경로")
        neuroimaging['preop'] = preop

    if ask_yn("Postimplant 영상 경로를 입력하시겠습니까?", default=True):
        postimplant = {}
        for key, desc in [('CT', 'CT'), ('T1w', 'T1w MRI'), ('FLAIR', 'FLAIR'),
                          ('dwi', 'DWI'), ('func_rest', 'resting fMRI')]:
            if ask_yn(f"  {desc} 있습니까?", default=True):
                postimplant[key] = ask(f"    {desc} 경로")
        neuroimaging['postimplant'] = postimplant

    return neuroimaging


def build_config_interactive():
    """Full interactive config builder."""
    print("=" * 60)
    print("  YUHS SEEG BIDS Pipeline — 새 환자 설정")
    print("=" * 60)

    raw_root = Path(ask("Raw data root 경로", default="/remotenas2/YUHS/SEEG_PSYCHOPY"))

    config = {
        'raw_data_root': str(raw_root),
        'pipeline': {
            'steps': [s[0] for s in PIPELINE_STEPS],
            'incremental': False,
        },
    }

    # Demographics
    config.update(collect_demographics())

    # SEEG info
    config.update(collect_seeg_info())

    # SOZ
    config.update(collect_soz_info())

    # Modalities
    config.update(collect_modalities())

    # Event type mapping (use defaults)
    config['event_type_mapping'] = {
        'fixation': 'fixation',
        'stimuli': 'stimulus',
        'stim_on': 'stimulus',
        'stim_off': 'stimulus_offset',
        'response': 'response',
        'isi': 'isi',
        'probe': 'probe',
    }

    # Task descriptions
    config['task_descriptions'] = dict(KNOWN_TASKS)

    # EDF sessions
    ieeg_sessions, annotation_schemes = collect_edf_sessions(raw_root)
    if annotation_schemes:
        config['edf_annotation_schemes'] = annotation_schemes

    # Imaging sessions
    imaging_sessions = collect_imaging_sessions()

    # Merge sessions
    all_sessions = {**imaging_sessions, **ieeg_sessions}
    config['sessions'] = all_sessions

    # Neuroimaging paths
    if any(m in imaging_sessions for m in ['ses-preop', 'ses-postimplant']):
        config['neuroimaging'] = collect_neuroimaging_paths()
        if ask_yn("Derivatives (FreeSurfer, tractography 등) 경로를 입력하시겠습니까?", default=False):
            derivatives = {}
            for key, desc in [('freesurfer', 'FreeSurfer'), ('tractography', 'Tractography')]:
                if ask_yn(f"  {desc}?", default=True):
                    derivatives[key] = ask(f"    {desc} 경로")
            config['derivatives'] = derivatives

    return config


# ──────────────────────────────────────────────────────────────
# Pipeline execution
# ──────────────────────────────────────────────────────────────

def execute_pipeline(config_path, steps=None):
    """Execute pipeline steps sequentially."""
    config = utils.load_config(config_path)
    pid = config['participant_id']
    available_steps = config.get('pipeline', {}).get('steps', [s[0] for s in PIPELINE_STEPS])

    if steps:
        run_steps = [s for s in PIPELINE_STEPS if s[0] in steps]
    else:
        run_steps = [s for s in PIPELINE_STEPS if s[0] in available_steps]

    print(f"\n{'='*60}")
    print(f"  BIDS Pipeline 실행: {pid}")
    print(f"  Config: {config_path}")
    print(f"  Steps: {[s[0] for s in run_steps]}")
    print(f"{'='*60}")

    results = {}
    for step_name, script_name, description in run_steps:
        print(f"\n▶ [{step_name}] {description}")

        extra_args = None
        if step_name == 'verify_triggers':
            # Ask whether to auto-correct
            if not ask_yn("  Trigger 문제 발견 시 자동 보정을 적용하시겠습니까?", default=True):
                extra_args = ['--no-correct']

        success = run_step(script_name, config_path, extra_args)
        results[step_name] = success

        if not success:
            print(f"\n  ✗ [{step_name}] 실패!")
            if step_name == 'validate':
                # Validation failure is non-blocking
                print("  → 검증 실패는 경고로 처리합니다.")
                continue
            if not ask_yn("  계속 진행하시겠습니까?", default=False):
                print("\n  Pipeline 중단.")
                break

    # Summary
    print(f"\n{'='*60}")
    print(f"  Pipeline 실행 완료")
    print(f"{'='*60}")
    for step_name, _, desc in run_steps:
        if step_name in results:
            status = "✓" if results[step_name] else "✗"
            print(f"  {status} {step_name}: {desc}")

    return all(results.values())


def add_session_interactive(config_path):
    """Add a new session to an existing patient config."""
    config = utils.load_config(config_path)
    raw_root = Path(config.get('raw_data_root', '/remotenas2/YUHS/SEEG_PSYCHOPY'))
    pid = config['participant_id']

    print(f"\n{'='*60}")
    print(f"  세션 추가: {pid}")
    print(f"{'='*60}")

    existing = list(config.get('sessions', {}).keys())
    print(f"  기존 세션: {existing}")

    session_type = ask_choice("추가할 세션 유형",
                              [("ieeg", "iEEG (새 EDF)"),
                               ("imaging", "뇌영상 (MRI/CT/PET)")])

    if session_type == 'ieeg':
        new_sessions, new_schemes = collect_edf_sessions(raw_root)
        config.setdefault('sessions', {}).update(new_sessions)
        config.setdefault('edf_annotation_schemes', {}).update(new_schemes)
    else:
        new_sessions = collect_imaging_sessions()
        config.setdefault('sessions', {}).update(new_sessions)

    # Save updated config
    with open(config_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    print(f"\n  Config 업데이트 완료: {config_path}")

    # Ask to run pipeline for new sessions
    if ask_yn("새 세션에 대해 pipeline을 실행하시겠습니까?", default=True):
        execute_pipeline(config_path)


# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="YUHS SEEG BIDS Pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 run_pipeline.py                           # 새 환자 (대화형)
  python3 run_pipeline.py --config config/sub-EP01.yaml  # 기존 config로 실행
  python3 run_pipeline.py --config config/sub-EP01.yaml --steps split_edf,events
  python3 run_pipeline.py --config config/sub-EP01.yaml --add-session
        """)
    parser.add_argument('--config', type=str, help='YAML config 파일 경로')
    parser.add_argument('--steps', type=str, help='실행할 단계 (쉼표 구분)')
    parser.add_argument('--add-session', action='store_true', help='기존 환자에 세션 추가')
    parser.add_argument('--list-steps', action='store_true', help='사용 가능한 단계 목록')

    args = parser.parse_args()

    if args.list_steps:
        print("\n사용 가능한 Pipeline 단계:")
        for name, script, desc in PIPELINE_STEPS:
            print(f"  {name:20s} ({script:25s}) — {desc}")
        return

    # Resolve config
    code_dir = Path(__file__).parent
    config_path = None

    if args.config:
        config_path = utils.get_config_path(args.config, code_dir)
        if not config_path or not config_path.exists():
            print(f"Config 파일을 찾을 수 없습니다: {args.config}")
            sys.exit(1)

    if args.add_session:
        if not config_path:
            print("--add-session은 --config와 함께 사용해야 합니다.")
            sys.exit(1)
        add_session_interactive(config_path)
        return

    if config_path:
        # Run with existing config
        steps = args.steps.split(',') if args.steps else None
        success = execute_pipeline(config_path, steps)
        sys.exit(0 if success else 1)

    # Interactive mode: build new config
    config = build_config_interactive()

    # Save config
    pid = config['participant_id']
    config_dir = code_dir / 'config'
    config_dir.mkdir(exist_ok=True)
    config_path = config_dir / f'{pid}.yaml'

    print(f"\n━━━ Config 저장 ━━━")
    if config_path.exists():
        if not ask_yn(f"  {config_path.name} 이미 존재합니다. 덮어쓰시겠습니까?", default=False):
            config_path = config_dir / f'{pid}_{datetime.now().strftime("%Y%m%d_%H%M%S")}.yaml'

    with open(config_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    print(f"  저장: {config_path}")

    # Ask to run pipeline
    if ask_yn("\n지금 Pipeline을 실행하시겠습니까?", default=True):
        execute_pipeline(config_path)


if __name__ == '__main__':
    main()
