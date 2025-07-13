#!/bin/bash

echo "=== ILU0 Algorithm Analysis Pipeline ==="

# Change to the script directory
cd "$(dirname "$0")"
LOGS_DIR="../../logs"
COLLECT_DIR="../../script_src/python_scripts/collect_data"
ALGORITHM_DIR="../../script_src/python_scripts/algorithm"

# Check if logs directory exists
if [ ! -d "$LOGS_DIR" ]; then
    echo "ERROR: Logs directory not found at $LOGS_DIR"
    exit 1
fi

echo "Step 1: Generating matrix application data..."
if [ ! -f "$LOGS_DIR/matrix_application.csv" ]; then
    echo "Generating matrix_application.csv..."
    cd "$COLLECT_DIR"
    python3 application_get.py
    cd - > /dev/null
    if [ ! -f "$LOGS_DIR/matrix_application.csv" ]; then
        echo "ERROR: Failed to generate matrix_application.csv"
        exit 1
    fi
    echo "Generated matrix_application.csv"
else
    echo "matrix_application.csv already exists"
fi

echo "Step 2: Computing approximated condition numbers..."
if [ ! -f "$LOGS_DIR/approximated_condition_number_inf.csv" ]; then
    echo "Computing approximated condition numbers..."
    cd "$COLLECT_DIR"
    python3 aprx_cond_num.py
    cd - > /dev/null
    if [ ! -f "$LOGS_DIR/approximated_condition_number_inf.csv" ]; then
        echo "ERROR: Failed to generate approximated_condition_number_inf.csv"
        exit 1
    fi
    echo "Generated approximated_condition_number_inf.csv"
else
    echo "approximated_condition_number_inf.csv already exists"
fi

echo "Step 3: Computing ILU0 speedups..."
if [ ! -f "$LOGS_DIR/ilu0_speedups.csv" ]; then
    echo "Computing ILU0 speedups from raw data..."
    python3 << 'EOF'
import pandas as pd
import numpy as np

# Read the raw ILU0 data
raw_df = pd.read_csv("../../logs/ilu0_raw.csv")
print(f"Loaded {len(raw_df)} rows from ilu0_raw.csv")

# Group by matrix name to compute speedups
results = []

for matrix_name in raw_df["Matrix Name"].unique():
    matrix_data = raw_df[raw_df["Matrix Name"] == matrix_name]
    
    # Find the baseline (sparsification ratio = 0)
    baseline = matrix_data[matrix_data["Sparsification Ratio"] == 0]
    if len(baseline) == 0:
        print(f"Warning: No baseline (ratio=0) found for matrix {matrix_name}")
        continue
    
    baseline_row = baseline.iloc[0]
    baseline_overall_time = baseline_row["Overall Time (ms)"]
    baseline_iterations = baseline_row["Iterations Spent"]
    
    # Calculate per-iteration time for baseline
    baseline_per_iter_time = baseline_overall_time / baseline_iterations if baseline_iterations > 0 else float('inf')
    
    # Process sparsified versions
    sparsified_data = matrix_data[matrix_data["Sparsification Ratio"] > 0]
    
    for _, row in sparsified_data.iterrows():
        sp_ratio = row["Sparsification Ratio"]
        sp_overall_time = row["Overall Time (ms)"]
        sp_iterations = row["Iterations Spent"]
        
        # Calculate per-iteration time for sparsified version
        sp_per_iter_time = sp_overall_time / sp_iterations if sp_iterations > 0 else float('inf')
        
        # Calculate speedups
        per_iter_speedup = baseline_per_iter_time / sp_per_iter_time if sp_per_iter_time > 0 else 0
        end_to_end_speedup = baseline_overall_time / sp_overall_time if sp_overall_time > 0 else 0
        
        results.append({
            "Matrix Name": matrix_name,
            "Sparsification Ratio": sp_ratio,
            "Per-iteration Speedup": per_iter_speedup,
            "End-to-end Speedup": end_to_end_speedup
        })

# Create DataFrame and save
speedup_df = pd.DataFrame(results)
speedup_df.to_csv("../../logs/ilu0_speedups.csv", index=False)
print(f"Saved {len(speedup_df)} speedup records to ilu0_speedups.csv")
EOF
    
    if [ ! -f "$LOGS_DIR/ilu0_speedups.csv" ]; then
        echo "ERROR: Failed to generate ilu0_speedups.csv"
        exit 1
    fi
    echo "Generated ilu0_speedups.csv"
else
    echo "ilu0_speedups.csv already exists"
fi

echo "Step 4: Creating wavefronts data..."
if [ ! -f "$LOGS_DIR/wavefronts.csv" ]; then
    echo "Processing wavefront data from timing files..."
    python3 << 'EOF'
import pandas as pd
import os
import glob

# Find all timing files
timing_files = glob.glob("../../factors/timing/*_timing.csv")
print(f"Found {len(timing_files)} timing files")

if len(timing_files) == 0:
    print("ERROR: No timing files found")
    exit(1)

# Combine all timing data
all_timing_data = []

for file_path in timing_files:
    try:
        df = pd.read_csv(file_path)
        all_timing_data.append(df)
    except Exception as e:
        print(f"Error reading {file_path}: {e}")

if not all_timing_data:
    print("ERROR: No valid timing data found")
    exit(1)

# Combine all data
timing_df = pd.concat(all_timing_data, ignore_index=True)
print(f"Combined {len(timing_df)} timing records")

# Process timing data to create wavefronts CSV
wavefront_results = []

for _, row in timing_df.iterrows():
    matrix_name = row["Matrix Name"]
    sparsified = row["Sparsified"]
    removal_percentage = row["Removal Percentage"]
    wavefront_count = row["#Wavefront Set"]
    
    # Convert removal percentage to sparsification ratio
    if sparsified:
        sp_ratio = removal_percentage
    else:
        sp_ratio = 0.0
    
    wavefront_results.append({
        "Matrix Name": matrix_name,
        "Sparsification Ratio": sp_ratio,
        "Wavefront Count": wavefront_count
    })

# Create DataFrame and save
wavefront_df = pd.DataFrame(wavefront_results)

# Remove duplicates by taking the first occurrence of each (Matrix Name, Sparsification Ratio) pair
wavefront_df = wavefront_df.drop_duplicates(subset=["Matrix Name", "Sparsification Ratio"], keep="first")

wavefront_df.to_csv("../../logs/wavefronts.csv", index=False)
print(f"Saved {len(wavefront_df)} wavefront records to wavefronts.csv")
EOF
    
    if [ ! -f "$LOGS_DIR/wavefronts.csv" ]; then
        echo "ERROR: Failed to generate wavefronts.csv"
        exit 1
    fi
    echo "Generated wavefronts.csv"
else
    echo "wavefronts.csv already exists"
fi

echo "Step 5: Running ILU0 algorithm analysis..."
cd "$ALGORITHM_DIR"
python3 alg_ilu0.py

if [ $? -eq 0 ]; then
    echo "ILU0 algorithm analysis completed successfully"
    echo "Results saved in algorithm directory"
else
    echo "ERROR: ILU0 algorithm analysis failed"
    exit 1
fi

echo "Step 6: Generating ILU0 performance summary tables..."
cd "../plot"
python3 generate_summary_tables.py
if [ $? -eq 0 ]; then
    echo "Performance summary tables generated successfully"
else
    echo "WARNING: Failed to generate summary tables"
fi

echo "Step 7: Generating ILU0 correlation plot..."
python3 correlation_ilu0_updated.py
if [ $? -eq 0 ]; then
    echo "ILU0 correlation plot generated successfully"
else
    echo "WARNING: Failed to generate ILU0 correlation plot"
fi

echo "Step 8: Generating ILU0 application speedup plot..."
python3 ilu0_application_speedup.py
if [ $? -eq 0 ]; then
    echo "ILU0 application speedup plot generated successfully"
else
    echo "WARNING: Failed to generate ILU0 application speedup plot"
fi

echo "Step 9: Generating ILU0 factorization speedup plot..."
python3 ilu0_factorization_speedup.py
if [ $? -eq 0 ]; then
    echo "ILU0 factorization speedup plot generated successfully"
else
    echo "WARNING: Failed to generate ILU0 factorization speedup plot"
fi

echo "Step 10: Generating ILU0 speedup distribution histograms..."
python3 << 'EOF'
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

def prepare_algorithm_selected_data(speedup_file, algorithm_file, output_file, method_name):
    """Prepare data with algorithm selected speedups"""
    speedup_data = pd.read_csv(speedup_file)
    
    try:
        algorithm_results = pd.read_csv(algorithm_file)
        
        # Merge algorithm results with speedup data
        merged = pd.merge(
            algorithm_results, 
            speedup_data, 
            left_on=["Matrix Name", "Selected Sparsification Ratio"],
            right_on=["Matrix Name", "Sparsification Ratio"],
            how="inner"
        )
        
        if len(merged) > 0:
            # Create the required columns for histogram plotting
            result_data = merged[["Matrix Name", "Selected Sparsification Ratio"]].copy()
            result_data["Selected Per-iteration Speedup"] = merged["Per-iteration Speedup"]
            result_data["Selected End-to-end Speedup"] = merged["End-to-end Speedup"]
            
            result_data.to_csv(output_file, index=False)
            print(f"Prepared {len(result_data)} algorithm-selected records for {method_name}")
            return result_data
        else:
            print(f"Warning: No algorithm-selected data found for {method_name}")
            return None
    except FileNotFoundError:
        print(f"Warning: Algorithm results file not found for {method_name}")
        return None

def plot_histogram(data, method_name, output_dir):
    """Plot histogram for speedup distribution"""
    speedup_columns = [
        'Selected Per-iteration Speedup',
        'Selected End-to-end Speedup'
    ]

    for speedup_type in speedup_columns:
        if speedup_type not in data.columns:
            print(f"Column '{speedup_type}' not found in {method_name} data. Skipping plot.")
            continue

        speedup_data = data[speedup_type]

        bins = np.arange(0, 5.25, 0.25)

        filtered_speedup_data = speedup_data[(speedup_data >= 0) & (speedup_data <= 5)]

        hist, bin_edges = np.histogram(filtered_speedup_data, bins=bins)
        hist_percentage = hist / hist.sum() * 100  # Normalize to percentages

        plt.figure(figsize=(10, 6))
        plt.bar(
            bin_edges[:-1], hist_percentage, width=0.25, color='#1f77b4', edgecolor='black', align='edge'
        )
        plt.axvline(x=1, color='red', linestyle='--', linewidth=2, label="x=1")

        axis_label = speedup_type.replace("Selected ", f"SPCG-{method_name.upper()} ")
        
        plt.xlabel(axis_label, fontsize=18, fontweight="bold")
        plt.ylabel('Distribution (%)', fontsize=18, fontweight="bold")
        plt.xticks(fontsize=14)
        plt.yticks(fontsize=14)

        ax = plt.gca()
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)

        plt.tight_layout()
        
        # Save plot
        speedup_type_clean = speedup_type.lower().replace(' ', '_').replace('-', '_')
        output_path = os.path.join(output_dir, f"{method_name.lower()}_{speedup_type_clean}_histogram.png")
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"{method_name} {speedup_type} histogram saved to: {output_path}")

# Setup paths
output_dir = "../../../results/plots"
os.makedirs(output_dir, exist_ok=True)

# Prepare and plot ILU0 histograms
print("Processing ILU0 histograms...")
ilu0_data = prepare_algorithm_selected_data(
    "../../../logs/ilu0_speedups.csv",
    "../../../script_src/python_scripts/algorithm/best_oracle_selection_gpu_pi_from_prediction.csv",
    "../../../results/ilu0_histogram_data.csv",
    "ILU0"
)
if ilu0_data is not None:
    plot_histogram(ilu0_data, "ILU0", output_dir)
EOF

if [ $? -eq 0 ]; then
    echo "ILU0 speedup distribution histograms generated successfully"
else
    echo "WARNING: Failed to generate ILU0 speedup distribution histograms"
fi

echo "=== ILU0 Analysis Pipeline Complete ==="
