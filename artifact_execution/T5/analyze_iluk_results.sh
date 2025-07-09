#!/bin/bash

# T5: ILUK Algorithm Analysis
# This script prepares all required data and runs the ILUK algorithm analysis

echo "================================================================================"
echo "T5: ILUK Algorithm Analysis"
echo "================================================================================"

# Set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs"
COLLECT_DATA_DIR="$PROJECT_ROOT/script_src/python_scripts/collect_data"
ALGORITHM_DIR="$PROJECT_ROOT/script_src/python_scripts/algorithm"

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Check if required input files exist
required_files=(
    "$LOGS_DIR/norm2_os.csv"
    "$LOGS_DIR/norm2_s.csv" 
    "$LOGS_DIR/iluk_raw.csv"
    "$LOGS_DIR/diag_min.csv"
    "$LOGS_DIR/inf_norm_os.csv"
)

echo "Checking for required input files..."
missing_files=()
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    else
        echo "Found: $(basename "$file")"
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo "Missing required input files:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    echo "Please ensure T3 and T4 have been completed successfully."
    exit 1
fi

echo -e "\n1. Computing ILUK speedups from raw results..."
cd "$COLLECT_DATA_DIR"
python3 compute_iluk_speedups.py
if [[ $? -ne 0 ]]; then
    echo "Failed to compute ILUK speedups"
    exit 1
fi
echo "ILUK speedups computed successfully"

echo -e "\n2. Collecting matrix application data (if not already done)..."
cd "$COLLECT_DATA_DIR"
if [[ ! -f "$LOGS_DIR/matrix_application.csv" ]]; then
    python3 application_get.py
    if [[ $? -ne 0 ]]; then
        echo "Failed to collect matrix application data"
        exit 1
    fi
    echo "Matrix application data collected successfully"
else
    echo "Matrix application data already exists"
fi

echo -e "\n3. Computing wavefront data (if not already done)..."
cd "$COLLECT_DATA_DIR"
if [[ ! -f "$LOGS_DIR/wavefronts.csv" ]]; then
    python3 compute_wavefronts.py
    if [[ $? -ne 0 ]]; then
        echo "Failed to compute wavefront data"
        exit 1
    fi
    echo "Wavefront data computed successfully"
else
    echo "Wavefront data already exists"
fi

echo -e "\n4. Computing approximated condition numbers..."
cd "$COLLECT_DATA_DIR"
python3 aprx_cond_num.py
if [[ $? -ne 0 ]]; then
    echo "Failed to compute approximated condition numbers"
    exit 1
fi
echo "Approximated condition numbers computed successfully"

# Check if all required output files were created
output_files=(
    "$LOGS_DIR/iluk_speedups_best_fill_factor.csv"
    "$LOGS_DIR/iluk_raw_best_fill_factor.csv"
    "$LOGS_DIR/matrix_application.csv"
    "$LOGS_DIR/wavefronts.csv"
    "$LOGS_DIR/approximated_condition_number_inf.csv"
)

echo -e "\nVerifying output files..."
missing_outputs=()
for file in "${output_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_outputs+=("$file")
    else
        echo "Created: $(basename "$file")"
    fi
done

if [[ ${#missing_outputs[@]} -gt 0 ]]; then
    echo "Missing output files:"
    for file in "${missing_outputs[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

echo -e "\n5. Running ILUK algorithm analysis..."
cd "$ALGORITHM_DIR"
python3 alg_iluk.py
if [[ $? -ne 0 ]]; then
    echo "Failed to run ILUK algorithm analysis"
    exit 1
fi
echo "ILUK algorithm analysis completed successfully"

echo -e "\n================================================================================"
echo "T5 ILUK Analysis Complete!"
echo "================================================================================"
echo "Output files created:"
echo "  - $LOGS_DIR/iluk_speedups_best_fill_factor.csv"
echo "  - $LOGS_DIR/iluk_raw_best_fill_factor.csv"
echo "  - $LOGS_DIR/matrix_application.csv"
echo "  - $LOGS_DIR/wavefronts.csv"
echo "  - $LOGS_DIR/approximated_condition_number_inf.csv"
echo "  - $ALGORITHM_DIR/best_oracle_selection_gpu_pi_from_prediction.csv"
echo "  - $ALGORITHM_DIR/gmean_speedup_by_application_iluk.csv"
echo "================================================================================"
