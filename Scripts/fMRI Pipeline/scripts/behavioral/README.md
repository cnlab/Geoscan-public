# Behavioral Data: Creating Events TSV Files

BIDS requires a `_events.tsv` file for each functional run, containing the onset, duration, and trial type of every event. These files are the direct input to the L1 pipeline — they are read run-by-run when building each subject's design matrix.

The scripts in `scripts/behavioral/` convert the raw behavioral CSVs exported from the task software into BIDS-compliant events TSV files and write them into the correct location in the BIDS directory.

**This step must be completed before running L1 modeling (Step 4).** The L1 notebook validates that every events file exists for every subject-run before generating any job files, and will raise a `File missing` error for any that are absent.

---

## Files

| File | Language | Purpose |
|------|----------|---------|
| `create_events_files_from_log.ipynb` | Python | **Active script** — geoscan image task events for GS and GEO subjects |

**Input:** raw behavioral CSV files at `data/behavioral/`

**Output:** BIDS events TSV files written to `data/bids_data/sub-{ID}/ses-t2/func/`

```
data/bids_data/
└── sub-GEO053/
    └── ses-t2/
        └── func/
            ├── sub-GEO053_ses-t2_task-image_run-1_events.tsv
            ├── sub-GEO053_ses-t2_task-image_run-2_events.tsv
            ├── sub-GEO053_ses-t2_task-image_run-3_events.tsv
            ├── sub-GEO053_ses-t2_task-image_run-4_events.tsv
            └── sub-GEO053_ses-t2_task-image_run-5_events.tsv
```

---

## `create_events_files_from_log.ipynb`

This Python notebook has two independent cells — one for GS subjects and one for GEO subjects. The two cohorts use different input file formats, so they are processed separately. Run only the cell relevant to the subjects you are adding.

### Input Files

| Cohort | Input | Format |
|--------|-------|--------|
| GS | One CSV per subject: `Images_T2_pmod_GS{ID}_T2.csv` | Multiple files in `data/behavioral/` |
| GEO | One combined CSV: `Images_T2_pmod_GEO.csv` | Single file containing all GEO subjects |

Both CSVs share the same column structure, with one row per trial across all runs:

| Input column | Output column | Description |
|-------------|---------------|-------------|
| `onset` | `onset` | Trial onset time in seconds from run start |
| `dur` | `duration` | Trial duration in seconds |
| `cond` | `trial_type` | Trial type label (e.g. `stimuli_standard_smoke`, `rating`, `stimuli_rest`) |
| `pmod1_rating` | `pmodRating` | Participant's rating response for parametric modulation |
| `run` | *(used for splitting)* | Integer run number (1–5) |
| `pID` | *(used for subject ID)* | Participant identifier — format differs by cohort (see below) |

### Subject ID Formats

The `pID` field is formatted differently between cohorts:

- **GS subjects** — `pID` contains bare IDs like `GS005`. The script extracts this via regex on the first row of each per-subject file, then looks for `sub-GS005` in the BIDS directory.
- **GEO subjects** — `pID` contains IDs with a session suffix, e.g. `GEO053_T2`. The script strips the `sub-` prefix from the BIDS folder name and appends `_T2` to match against this field (i.e., looks for `GEO053_T2` in the combined CSV).

### Cell 1 — GS Subjects

Globs for all `Images_T2_pmod_GS*_T2.csv` files in `data/behavioral/`. For each file, it checks whether the corresponding `sub-GS{ID}` directory exists in the BIDS directory — if not, it skips that subject. For subjects that do exist, it loops over runs, extracts the four output columns, and writes one TSV per run.

Run this cell when:
- Processing GS cohort subjects for the first time
- A new GS subject's behavioral CSV has been added to `data/behavioral/`

### Cell 2 — GEO Subjects

Reads the single combined `Images_T2_pmod_GEO.csv`. Gets the list of GEO subjects by scanning the BIDS directory for folders matching `sub-GEO[0-9]{3}`. For each subject, filters the combined CSV to rows where `pID == "{ID}_T2"`, then loops over runs and writes one TSV per run.

Run this cell when:
- Processing GEO cohort subjects for the first time
- New GEO subjects' data has been added to the combined behavioral CSV

### Known Issue: Crash on GEO Subjects Without T2 Data

Some GEO subjects (e.g. GEO074, GEO078) do not have a `ses-t2/` session in BIDS because they did not complete the T2 visit. When Cell 2 reaches one of these subjects, it will crash with:

```
FileNotFoundError: [Errno 2] No such file or directory:
'.../bids_data/sub-GEO074/ses-t2/func/sub-GEO074_ses-t2_task-image_run-1_events.tsv'
```

**This is expected and can be ignored.** All subjects processed before the crash will have had their events files written successfully — the crash only stops the loop at the first subject missing a T2 session. Subjects without T2 data are already listed in `Info.exclude.sub` in `task_images-GEO.json` and are excluded from L1 modeling regardless.

The comment in the notebook acknowledges this: *"Will crash since last two subjects don't have T2? Will still give events to the rest of the subjects."*

---

## Verifying Events Files

Before running L1, confirm that events files were written for all expected subject-runs. Run this in a notebook or terminal:

```python
import os, glob

bids_dir = '/data00/projects/geoscan_v2/data/bids_data'
events = glob.glob(os.path.join(bids_dir, 'sub-*/ses-t2/func/*task-image*_events.tsv'))
print(f'{len(events)} events files found')

# Check a specific subject
sub = 'sub-GEO053'
sub_events = sorted(e for e in events if sub in e)
print(f'\n{sub}: {len(sub_events)} run(s)')
for e in sub_events:
    print(f'  {os.path.basename(e)}')
```

To spot-check the content of a file:

```python
import pandas as pd
df = pd.read_csv(sub_events[0], sep='\t')
print(df.head(10))
print(f'\nTrial types present: {sorted(df.trial_type.unique())}')
```

Expected trial types for the geoscan image task:
- `stimuli_standard_smoke`, `stimuli_standard_nonsmoke`
- `stimuli_retail_smoke_familiar`, `stimuli_retail_smoke_unfamiliar`
- `stimuli_retail_nonsmoke_familiar`, `stimuli_retail_nonsmoke_unfamiliar`
- `stimuli_personal_smoke`, `stimuli_personal_nonsmoke`
- `rating`
- `stimuli_rest`
