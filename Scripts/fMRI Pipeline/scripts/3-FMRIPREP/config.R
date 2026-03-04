# config.R
#
# Configuration for auto_motion_fmriprep.R
# Used by generate_outlier_report.ipynb (called via Rscript)
#
# Set BASE_DIR to the project root. All other paths are derived from it.
# If running this file directly from scripts/FMRIPREP/, the default value
# using dirname(dirname(getwd())) will resolve correctly automatically.

# ── Project root ──────────────────────────────────────────────────────────────
# Default: derive from the location of this config file (scripts/FMRIPREP/)
BASE_DIR <- dirname(dirname(normalizePath(getwd())))

# Override manually if needed:
# BASE_DIR <- '/data00/projects/geoscan_v2'

# ── Derived paths ─────────────────────────────────────────────────────────────
confoundDir <- file.path(BASE_DIR, 'data/bids_data/derivatives')
outputDir   <- file.path(BASE_DIR, 'data/bids_data/derivatives/outlier')

cat('BASE_DIR    :', BASE_DIR,    '\n')
cat('confoundDir :', confoundDir, '\n')
cat('outputDir   :', outputDir,   '\n')

# ── Study variables ───────────────────────────────────────────────────────────
version = '20.0.6'     # fMRIPrep version used
study   = 'geoscan_v2' # Study name label in output
ses     = 't3'         # Session label (used in file matching; set to FALSE if no sessions)

# ── Output options ────────────────────────────────────────────────────────────
noRP        = FALSE    # Suppress motion regressor text files
noNames     = FALSE    # Suppress column headers in regressor files
noPlot      = FALSE    # Suppress per-subject-run motion plots
noEuclidean = FALSE    # Use raw realignment params instead of Euclidean distance
                       # If FALSE (default): output cols = euclidean_trans, euclidean_rot,
                       #   euclidean_trans_deriv, euclidean_rot_deriv, trash
                       # If TRUE: output cols = X, Y, Z, RotX, RotY, RotZ, trash

# ── Plot settings ─────────────────────────────────────────────────────────────
figIndicators = c('FramewiseDisplacement', 'GlobalSignal', 'stdDVARS')
figFormat     = '.png'
figHeight     = 5.5
figWidth      = 7
figDPI        = 250
