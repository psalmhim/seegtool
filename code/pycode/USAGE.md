# YUHS SEEG BIDS Pipeline 사용법

## 개요

이 파이프라인은 YUHS(연세대학교 의료원) SEEG 환자의 인지 과제 데이터를 [BIDS (Brain Imaging Data Structure)](https://bids-specification.readthedocs.io/) 형식으로 자동 변환합니다.

### 주요 특징
- **대화형 CLI**: 새 환자 설정을 질문/답변으로 진행
- **YAML config 기반**: 한 번 설정하면 재실행 가능
- **Trigger 자동 검증**: SEEG trigger와 PsychoPy 행동데이터 타이밍 비교, 문제 시 자동 보정
- **단계별 실행**: 원하는 단계만 선택적 실행
- **세션 추가**: 기존 환자에 새 데이터 추가 가능

---

## 빠른 시작

```bash
cd /remotenas2/YUHS/SEEG_PSYCHOPY/BIDS/code

# 1. 새 환자 (대화형 모드)
python3 run_pipeline.py

# 2. 기존 config로 전체 파이프라인 실행
python3 run_pipeline.py --config config/sub-EP01AN96M1047.yaml
```

---

## 명령어 레퍼런스

### 기본 문법

```bash
python3 run_pipeline.py [옵션]
```

| 옵션 | 설명 |
|------|------|
| (없음) | 대화형 모드 — 새 환자 설정부터 시작 |
| `--config <yaml>` | 기존 YAML config로 파이프라인 실행 |
| `--steps <단계들>` | 실행할 단계를 쉼표로 지정 (--config 필수) |
| `--add-session` | 기존 환자에 새 세션 추가 (--config 필수) |
| `--list-steps` | 사용 가능한 파이프라인 단계 목록 표시 |

---

## 사용 예시

### 1. 새 환자 등록 (대화형)

```bash
python3 run_pipeline.py
```

터미널에서 아래와 같이 질문이 나타나며 순서대로 입력합니다:

```
━━━ 환자 기본 정보 ━━━
환자 ID (예: sub-EP01AN96M1047): sub-EP02BK45F0823
연령: 35
  [1] M: 남성
  [2] F: 여성
성별: 2
우세손 [R]: R
진단명 [drug-resistant epilepsy]: drug-resistant epilepsy

━━━ SEEG 녹화 정보 ━━━
Sampling rate (Hz) [2048]: 2048
장비 제조사 [Natus]: Natus
장비 모델 [XLTEK]: XLTEK
Reference [white matter]: white matter
Power line frequency (Hz) [60]: 60
전극 좌표 파일 경로 (elec.tsv): psychopy_patient/BIDS/sub-002/elec/elec.tsv

━━━ EDF 파일 스캔 ━━━
EDF 파일 경로들 (한 줄에 하나, 빈 줄로 종료):
  > /remotenas2/YUHS/SEEG_PSYCHOPY/260401/STUDY001.EDF
  > /remotenas2/YUHS/SEEG_PSYCHOPY/260402/STUDY002.EDF
  >

  스캔 중: STUDY001.EDF ...
  ============================================================
  EDF Annotation Report: STUDY001.EDF
  ...
  --- 감지된 Task Boundaries (4개) ---
  [1] 00:05:23 ~ 00:12:45 (7m 22s) [task_start]
  [2] 00:15:10 ~ 00:20:33 (5m 23s) [task_start]
  ...

  Task [1/4]: 00:05:23 ~ 00:12:45 (7m 22s) [task_start]
  이 task를 포함하시겠습니까? [Y/n]: Y
  세션 키 (예: ses-task01): ses-task01
  BIDS task label (예: lexicaldecision): lexicaldecision
  Run 번호 [1]: 1
  촬영 일자 (YYYY-MM-DD): 2026-04-01
  ...
```

모든 정보 입력 후 YAML config가 자동 생성되고, 파이프라인 실행 여부를 물어봅니다.

### 2. 기존 config로 전체 실행

```bash
python3 run_pipeline.py --config config/sub-EP01AN96M1047.yaml
```

8개 단계를 순서대로 실행합니다:
1. scaffold → 2. split_edf → 3. sidecars → 4. events → 5. verify_triggers → 6. copy_anat → 7. readmes → 8. validate

### 3. 특정 단계만 실행

EDF 분할과 이벤트 생성만 다시 실행하고 싶을 때:

```bash
python3 run_pipeline.py --config config/sub-EP01AN96M1047.yaml --steps split_edf,events
```

Trigger 검증만 실행:

```bash
python3 run_pipeline.py --config config/sub-EP01AN96M1047.yaml --steps verify_triggers
```

BIDS 검증만:

```bash
python3 run_pipeline.py --config config/sub-EP01AN96M1047.yaml --steps validate
```

이벤트 재생성 + trigger 보정 + 검증을 한 번에:

```bash
python3 run_pipeline.py --config config/sub-EP01AN96M1047.yaml --steps events,verify_triggers,validate
```

### 4. 기존 환자에 새 세션 추가

환자의 추가 녹화가 진행된 경우:

```bash
python3 run_pipeline.py --config config/sub-EP01AN96M1047.yaml --add-session
```

```
━━━ 세션 추가: sub-EP01AN96M1047 ━━━
  기존 세션: ['ses-preop', 'ses-postimplant', 'ses-task01', ...]

  [1] ieeg: iEEG (새 EDF)
  [2] imaging: 뇌영상 (MRI/CT/PET)
추가할 세션 유형: 1

EDF 파일 경로들 (한 줄에 하나, 빈 줄로 종료):
  > /remotenas2/YUHS/SEEG_PSYCHOPY/260320/STUDY005.EDF
  >
  ...
```

### 5. 사용 가능한 단계 확인

```bash
python3 run_pipeline.py --list-steps
```

출력:
```
사용 가능한 Pipeline 단계:
  scaffold             (bids_scaffold.py         ) — BIDS 디렉토리 + 메타데이터 생성
  split_edf            (split_edf.py             ) — EDF → BrainVision 과제별 분할
  ...
  transform_mni        (transform_mni.py         ) — 전극 좌표 MNI152 변환 (ANTs SyN)
  sidecars             (create_sidecars.py       ) — channels/electrodes/coordsystem/ieeg.json
  events               (create_events.py         ) — events.tsv 생성 (SEEG trigger + 행동데이터)
  verify_triggers      (verify_triggers.py       ) — Trigger 품질 검증 + PsychoPy 보정
  copy_anat            (copy_anat.py             ) — 해부학적 영상 + derivatives 복사
  readmes              (create_readmes.py        ) — README.md 생성
  validate             (validate_bids.py         ) — BIDS 검증
```

### 6. 개별 스크립트 직접 실행

파이프라인 없이 각 스크립트를 독립적으로 실행할 수도 있습니다:

```bash
# EDF annotation 구조 분석 (새 EDF를 처음 볼 때 유용)
python3 scan_edf.py /remotenas2/YUHS/SEEG_PSYCHOPY/260401/STUDY001.EDF

# 디렉토리 내 모든 EDF 스캔
python3 scan_edf.py /remotenas2/YUHS/SEEG_PSYCHOPY/260401/

# Trigger 검증만 (보정 없이 리포트만)
python3 verify_triggers.py --config config/sub-EP01AN96M1047.yaml --no-correct

# BIDS 검증만
python3 validate_bids.py --config config/sub-EP01AN96M1047.yaml
```

---

## 파이프라인 단계 상세

### Step 1: scaffold
BIDS 디렉토리 구조와 필수 메타데이터 파일을 생성합니다.
- `dataset_description.json`, `participants.tsv`, `participants.json`
- `sessions.tsv`, `sessions.json`
- `.bidsignore`, `CHANGES`, `README`
- 세션별/모달리티별 디렉토리, `stimuli/` 디렉토리

### Step 2: split_edf
연속 EDF 녹화를 과제별로 분할하여 BrainVision 형식(.vhdr/.vmrk/.eeg)으로 저장합니다.
- YAML config의 `edf_annotation_schemes`를 참조하여 task boundary 결정
- Sequential mode: task_start/task_end 순서로 매핑
- Labeled mode: task_start_esk_b1 등 label별 매핑
- 전후 5초 buffer 포함하여 crop
- `segment_info.json` 생성 (각 세그먼트의 절대 시각 정보)

### Step 3: sidecars
BIDS 사이드카 파일을 생성합니다.
- `*_channels.tsv`: 채널 이름, 타입(SEEG/ECG/TRIG), 단위, sampling rate
- `*_electrodes.tsv`: 전극 좌표 (native T1w MRI space)
- `*_coordsystem.json`: 좌표계 정보
- `*_ieeg.json`: 녹화 메타데이터 (장비, task 설명, 채널 수 등)

### Step 4: events
SEEG trigger와 PsychoPy 행동데이터를 병합하여 `events.tsv`를 생성합니다.
- 원본 EDF에서 annotation 추출 (segment 시간 범위 기준)
- PsychoPy CSV에서 trial 정보 로드
- Trial별 이벤트 (fixation, stimulus, response 등) 1행씩 기록
- 행동데이터 컬럼 (정답, RT, 자극 조건 등) 병합

### Step 5: verify_triggers
SEEG trigger와 PsychoPy 행동데이터의 타이밍을 비교 검증합니다.
- **Bunched event 감지**: 동일 timestamp에 여러 이벤트가 묶인 경우
- **Trial count 불일치 감지**: SEEG trigger 수 vs PsychoPy trial 수
- **ITI 패턴 매칭**: 깨끗한 trigger의 inter-trial interval과 PsychoPy onset을 상관분석하여 alignment 확인
- **자동 보정**: 문제 발견 시 PsychoPy 타이밍 기반으로 events.tsv + .vmrk를 재생성 (±20ms 이내 정확도)
- 원본 파일은 `.orig`로 백업

### Step 6: copy_anat
해부학적 영상과 derivatives를 BIDS 구조로 복사합니다.
- ses-preop: T1w, FLAIR, DWI(+bval+bvec), fMRI rest, PET
- ses-postimplant: CT, T1w, FLAIR, DWI, fMRI rest
- derivatives: FreeSurfer, tractography, electrode-localization

### Step 7: transform_mni
전극 좌표를 native T1w space에서 MNI152NLin2009cAsym space로 변환합니다.
- ANTsPy SyN 비선형 정합 (preop T1w → MNI152 template)
- 정합 결과는 `derivatives/ants/<sub>/`에 캐싱 (재실행 시 즉시 완료)
- 각 ieeg 세션에 `space-MNI152NLin2009cAsym_electrodes.tsv` + `coordsystem.json` 생성
- QC용 warped T1w 저장 (`derivatives/ants/<sub>/<sub>_space-MNI152NLin2009cAsym_T1w.nii.gz`)
- `--force` 옵션으로 정합 재계산 가능

#### MNI 정합 품질 확인 (FSLeyes)

FSLeyes로 MNI 템플릿 위에 warped T1w를 overlay하여 정합 품질을 확인합니다:

```bash
# FSLeyes 설치 (최초 1회)
pip install fsleyes

# 정합 결과 확인 — MNI 템플릿(회색) + warped T1w(빨간색) 겹쳐보기
FSLDIR=/usr/local/fsl /home/eskim/.local/bin/fsleyes \
  ~/.antspy/mni.nii.gz \
  derivatives/ants/sub-EP01AN96M1047/sub-EP01AN96M1047_space-MNI152NLin2009cAsym_T1w.nii.gz \
  -a 40 -cm red &
```

확인 포인트:
- sagittal view에서 corpus callosum, brainstem 윤곽이 일치하는지
- axial view에서 뇌실, 피질 경계가 정렬되는지
- coronal view에서 좌우 외측 경계가 일치하는지

#### 전극 좌표 업데이트 후 재변환

전극 좌표를 수정한 경우 `--force`로 재변환:

```bash
# 전극 좌표만 재변환 (정합 결과 캐시 재사용)
python3 transform_mni.py --config config/sub-EP01AN96M1047.yaml

# 정합까지 다시 계산 (T1w가 변경된 경우)
python3 transform_mni.py --config config/sub-EP01AN96M1047.yaml --force
```

### Step 8: readmes
각 세션과 모달리티 폴더에 README.md를 생성합니다.
- `<!-- custom -->` 마커가 있는 파일은 덮어쓰지 않습니다.
- 수동 편집이 필요한 경우 파일 첫 줄에 `<!-- custom -->`을 추가하세요.

### Step 9: validate
BIDS 표준 준수 여부를 검증합니다.
- 필수 파일 존재 확인
- BIDS 파일명 규칙 검증
- sessions.tsv 일관성
- iEEG 파일 완전성 (BrainVision trio + 사이드카)
- events.tsv 내용 검증 (onset, duration, trial_type, trial count)
- channels.tsv 검증 (sampling rate 일치)
- 해부학 데이터 존재 확인

---

## YAML Config 구조

환자별 설정 파일은 `code/config/<participant_id>.yaml`에 저장됩니다.
대화형 모드에서 자동 생성되지만, 직접 편집도 가능합니다.

### 주요 섹션

```yaml
# 환자 정보
participant_id: "sub-EP01AN96M1047"
demographics:
  age: 29
  sex: "M"
  handedness: "R"
  pathology: "drug-resistant epilepsy"

# 파이프라인 제어
pipeline:
  steps: [scaffold, split_edf, sidecars, events, verify_triggers, copy_anat, readmes, validate]
  incremental: false  # true면 기존 파일 건너뜀

# Modality 선택
modalities_include:
  anat: true
  dwi: true
  func: true
  pet: true
  ieeg: true
  derivatives: true

# Seizure Onset Zone (연구자가 입력)
soz:
  electrodes: ["LA_1", "LA_2", "LH_3"]
  description: "Left anterior temporal"
  determination_method: "clinical consensus from SEEG monitoring"

# EDF annotation 스키마
edf_annotation_schemes:
  "260311/STUDY001.EDF":
    mode: "sequential"            # 동일 start/end label, 순서로 구분
    start_label: "task_start"
    end_label: "task_end"
    task_order:
      - {ses: "ses-task05", bids_task: "saliencepain", run: 1}
      - {ses: "ses-task06", bids_task: "balloonwatching", run: 1}
      ...

  "260312/STUDY002.EDF":
    mode: "labeled"               # task별 다른 start label
    start_labels: ["task_start_esk_b1", "task_start_esk_b2"]
    end_label: "task_end"
    skip_labels: ["task_start_prac"]  # 무시할 label
    task_mapping:
      task_start_esk_b1: {ses: "ses-task08", bids_task: "viseme", run: 1}
      task_start_esk_b2: {ses: "ses-task08", bids_task: "viseme", run: 2}

# 세션 정의
sessions:
  ses-task01:
    date: "2026-03-11"
    modalities: ["ieeg"]
    tasks:
      - bids_task: "lexicaldecision"
        run: 1
        has_response: true
        n_expected_trials: 100
        behavior_csv: "260311/Task01_LDT/data/xxx.csv"
        psychopy_onset_col: "img_words.started"    # PsychoPy stimulus onset 컬럼
        psychopy_thisN_col: "trials.thisN"          # PsychoPy trial index 컬럼
        response_key_col: "key_resp_words.keys"
        response_corr_col: "key_resp_words.corr"
        response_rt_col: "key_resp_words.rt"

      # 제외할 run
      - bids_task: "visualrhythm"
        run: 1
        exclude: true
        exclude_reason: "PsychoPy 중단 - 방해 요소 과다"
```

### 제외(exclude) 설정

특정 run을 BIDS에서 제외하려면:

```yaml
tasks:
  - bids_task: "visualrhythm"
    run: 1
    exclude: true
    exclude_reason: "PsychoPy 중단"
```

제외된 run의 파일은 생성/복사되지 않고, 검증에서도 건너뜁니다.

---

## Trigger 검증 상세

### 문제 유형

| 유형 | 설명 | 자동 보정 |
|------|------|-----------|
| bunched events | 동일 timestamp에 여러 trigger 묶임 (ZMQ 버퍼 문제) | 가능 |
| missing triggers | SEEG trigger 수 < PsychoPy trial 수 | 가능 |
| count mismatch | trigger 수 불일치 | 가능 (정렬 가능한 경우) |
| clock drift | 두 시계 간 점진적 차이 | 선형 보정으로 해결 |

### 보정 원리

1. **깨끗한 trigger 추출**: bunched 이벤트 제외
2. **ITI 패턴 매칭**: SEEG trigger 간격과 PsychoPy onset 간격의 상관분석으로 1:1 trial 대응 탐색
3. **선형 회귀**: `t_seeg = a * t_psychopy + b` 추정
4. **Residual 검증**: 정상 trigger와의 오차가 ±50ms 이내인지 확인
5. **전체 trial 복원**: PsychoPy 타이밍 기반으로 모든 event onset 재계산
6. **events.tsv + .vmrk 재생성**: 보정된 타이밍으로 덮어쓰기 (원본은 .orig 백업)

### 보정 결과 확인

```bash
# 보정 리포트 확인
cat trigger_report.json | python3 -m json.tool

# 보정 전 원본과 비교
diff sub-EP01AN96M1047_ses-task08_task-viseme_run-03_events.tsv.orig \
     sub-EP01AN96M1047_ses-task08_task-viseme_run-03_events.tsv
```

---

## 새 환자 추가 시 체크리스트

1. **데이터 준비**
   - [ ] EDF 파일 위치 확인
   - [ ] PsychoPy 행동데이터 CSV 위치 확인
   - [ ] 전극 좌표 파일 (elec.tsv) 준비
   - [ ] 뇌영상 파일 (preop/postimplant) 위치 확인

2. **대화형 CLI 실행**
   ```bash
   python3 run_pipeline.py
   ```

3. **EDF 사전 스캔 (선택사항)**
   ```bash
   # 어떤 annotation이 있는지 미리 확인
   python3 scan_edf.py /path/to/STUDY001.EDF
   ```

4. **제외할 데이터 결정**
   - PsychoPy 중단으로 CSV가 없는 세션
   - 방해 요소가 많아 분석에서 제외할 run
   - 중단된 task (scan_edf.py가 자동 감지)

5. **Pipeline 실행 후 확인**
   - [ ] trigger_report.json 확인 (문제 run 유무)
   - [ ] validate 결과 0 errors 확인
   - [ ] 제외된 run이 정확히 빠졌는지 확인
   - [ ] events.tsv의 trial count가 예상과 일치하는지 확인

---

## 문제 해결

### "EDF 재저장 ValueError: exceeds maximum field length"
→ 이미 해결됨. BrainVision 포맷으로 출력하기 때문에 발생하지 않습니다.

### "BrainVision .vmrk에 이벤트가 없다"
→ MNE의 BrainVision export는 EDF annotations를 .vmrk marker로 포함합니다. 파일을 다시 열어보세요.

### "Trigger 보정 후 onset이 strictly increasing이 아니다"
→ 정상입니다. 한 trial의 response가 다음 trial의 fixation보다 늦을 수 있습니다 (trial 내 순서는 정확).

### "CT 파일이 BIDSValidator에서 인식되지 않는다"
→ Python BIDSValidator 라이브러리의 제한. BIDS 표준에서 CT는 유효한 modality이며, 공식 웹 validator에서는 통과합니다.

### "Python 패키지가 없다"
```bash
pip install mne pybv bids-validator pyyaml pandas numpy antspyx
```

---

## SEEG Task 분석 가이드

### 각 과제 폴더(ses-taskXX/ieeg/)의 파일과 용도

```
ses-task01/ieeg/
├── sub-EP01_ses-task01_task-lexicaldecision_run-01_ieeg.vhdr    ← 데이터 로드 진입점
├── sub-EP01_ses-task01_task-lexicaldecision_run-01_ieeg.vmrk    ← 이벤트 마커 (MNE 자동 로드)
├── sub-EP01_ses-task01_task-lexicaldecision_run-01_ieeg.eeg     ← SEEG 원시 신호 (2048Hz)
├── sub-EP01_ses-task01_task-lexicaldecision_run-01_events.tsv   ← ★ 분석의 핵심: trial 정보
├── sub-EP01_ses-task01_task-lexicaldecision_run-01_events.json  ← events.tsv 컬럼 설명
├── sub-EP01_ses-task01_task-lexicaldecision_run-01_channels.tsv ← 채널 정보 (타입, sampling rate)
├── sub-EP01_ses-task01_task-lexicaldecision_run-01_ieeg.json    ← 녹화 메타데이터
├── sub-EP01_ses-task01_electrodes.tsv                           ← 전극 좌표 (native T1w)
├── sub-EP01_ses-task01_space-MNI152NLin2009cAsym_electrodes.tsv ← 전극 좌표 (MNI)
├── sub-EP01_ses-task01_coordsystem.json                         ← native 좌표계 정보
└── sub-EP01_ses-task01_space-MNI152NLin2009cAsym_coordsystem.json ← MNI 좌표계 정보
```

### events.tsv 구조

events.tsv는 **one-row-per-event** 형식으로, 각 trial의 개별 이벤트가 별도 행으로 기록됩니다:

| onset | duration | sample | trial_type | trial_number | (행동데이터 컬럼들...) |
|-------|----------|--------|-----------|-------------|----------------------|
| 5.123 | 1.500    | 10492  | fixation  | 1           | ...                  |
| 6.623 | 0.500    | 13564  | stimulus  | 1           | img_file, direction, ... |
| 7.401 | 0.000    | 15157  | response  | 1           | key, corr, rt        |
| 7.850 | 1.200    | 16077  | fixation  | 2           | ...                  |

- **onset**: 세그먼트 시작 기준 초 단위 시각
- **sample**: onset에 해당하는 샘플 번호 (epoching에 직접 사용)
- **trial_type**: `fixation`, `stimulus`, `stimulus_offset`, `response`, `isi`, `probe`
- **trial_number**: trial 번호 (1부터 시작)
- **행동데이터 컬럼**: task에 따라 다름 (자극 조건, 정답, RT 등)

### MNE-Python 분석 예시

```python
import mne
import pandas as pd
import numpy as np

# ── 1. 데이터 로드 ──
vhdr = 'sub-EP01AN96M1047/ses-task01/ieeg/sub-EP01AN96M1047_ses-task01_task-lexicaldecision_run-01_ieeg.vhdr'
raw = mne.io.read_raw_brainvision(vhdr, preload=True)

# ── 2. events.tsv에서 이벤트 로드 ──
events_file = vhdr.replace('_ieeg.vhdr', '_events.tsv')
events_df = pd.read_csv(events_file, sep='\t')

# stimulus 이벤트만 추출
stim = events_df[events_df.trial_type == 'stimulus'].copy()
print(f"총 {len(stim)} trials")

# ── 3. MNE events 배열로 변환 ──
# events.tsv의 sample 컬럼을 직접 사용
mne_events = np.column_stack([
    stim['sample'].values.astype(int),
    np.zeros(len(stim), dtype=int),
    np.ones(len(stim), dtype=int),
])

# 조건별 event_id (예: 정답 여부)
# event_id = {'correct': 1, 'incorrect': 2}

# ── 4. Epoching ──
epochs = mne.Epochs(raw, mne_events, tmin=-0.5, tmax=1.5, baseline=(-0.5, 0),
                    preload=True, picks='seeg')

# ── 5. 전극 좌표 (MNI) ──
elec_file = vhdr.replace('_task-lexicaldecision_run-01_ieeg.vhdr',
                          '_space-MNI152NLin2009cAsym_electrodes.tsv')
elec = pd.read_csv(elec_file, sep='\t')
print(elec[['name', 'x', 'y', 'z']].head())
```

### MATLAB 분석 예시

```matlab
% FieldTrip
cfg = [];
cfg.dataset = 'sub-EP01_ses-task01_task-lexicaldecision_run-01_ieeg.vhdr';
data = ft_preprocessing(cfg);

% events.tsv 로드
events = readtable('sub-EP01_ses-task01_task-lexicaldecision_run-01_events.tsv', ...
    'FileType', 'text', 'Delimiter', '\t');
stim_idx = strcmp(events.trial_type, 'stimulus');
stim_samples = events.sample(stim_idx);

% MNI 전극 좌표
elec = readtable('sub-EP01_ses-task01_space-MNI152NLin2009cAsym_electrodes.tsv', ...
    'FileType', 'text', 'Delimiter', '\t');
```

### 과제별 분석 참고사항

| 과제 | trial_type에서 볼 것 | 행동데이터 핵심 컬럼 | 비고 |
|------|---------------------|---------------------|------|
| lexicaldecision | stimulus, response | direction, correct_ans, key, corr, rt | 단어/비단어 판별 |
| shapecontrol | stimulus, response | match_shape, diff_shape, key, corr, rt | 도형 매칭 |
| sentencenoun | stimulus, response | LT, RT, direction, corr, rt | 문장-명사 의미 판단 |
| sentencegrammar | stimulus, response | LT, RT, direction, corr, rt | 문법성 판단 |
| saliencepain | fixation, stimulus | imgList, Pain | 수동 시청 (response 없음) |
| balloonwatching | stimulus, fixation | videos, condition, duration | 수동 시청 (response 없음) |
| viseme | fixation, stimulus, stimulus_offset, response | video_file, viseme_id, viseme_category, correct_key, corr, rt | 시각 음성 지각 2-AFC |
| visemegen | fixation, stimulus, stimulus_offset, response | (viseme과 동일 구조) | 새 화자 일반화 |
| visualrhythm | fixation, stimulus | video_file, condition, condition_name | 수동 시청 (probe 무시) |

---

## 파일 구조 참조

```
BIDS/
├── code/
│   ├── run_pipeline.py          # 메인 CLI
│   ├── config/                  # 환자별 YAML config
│   │   └── sub-EP01AN96M1047.yaml
│   ├── scan_edf.py              # EDF annotation 분석
│   ├── bids_scaffold.py         # Step 1: 디렉토리 생성
│   ├── split_edf.py             # Step 2: EDF 분할
│   ├── create_sidecars.py       # Step 3: 사이드카 생성
│   ├── create_events.py         # Step 4: events.tsv
│   ├── verify_triggers.py       # Step 5: trigger 검증/보정
│   ├── copy_anat.py             # Step 6: 영상 복사
│   ├── transform_mni.py         # Step 7: MNI 좌표 변환
│   ├── create_readmes.py        # Step 8: README 생성
│   ├── validate_bids.py         # Step 9: BIDS 검증
│   ├── utils.py                 # 공유 유틸리티
│   ├── segment_info.json        # split_edf 출력 (자동 생성)
│   ├── trigger_report.json      # verify_triggers 출력 (자동 생성)
│   └── USAGE.md                 # 이 문서
├── sub-<participant_id>/
│   ├── ses-preop/
│   │   ├── anat/    (T1w, FLAIR)
│   │   ├── dwi/     (DTI)
│   │   ├── func/    (resting fMRI)
│   │   └── pet/     (PET)
│   ├── ses-postimplant/
│   │   └── anat/    (CT, T1w, FLAIR)
│   ├── ses-task01/
│   │   └── ieeg/    (.vhdr/.vmrk/.eeg + channels.tsv + events.tsv + ieeg.json)
│   ├── ses-task08/
│   │   └── ieeg/    (viseme run-01~03 + visemegen run-01)
│   └── ...
├── stimuli/             # 과제별 자극 파일 (symlink)
├── derivatives/
│   ├── freesurfer/      # FreeSurfer
│   ├── tractography/    # 트랙토그래피
│   ├── electrode-localization/  # 전극 위치 추정
│   └── ants/            # ANTs 정합 (T1w→MNI transforms, warped T1w)
├── dataset_description.json
├── participants.tsv
├── .bidsignore
└── README
```
