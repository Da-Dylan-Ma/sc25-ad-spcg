#!/bin/bash

echo "=== CPU Algorithm Analysis Pipeline ==="

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

echo "Step 3: Computing CPU speedups with convergence analysis..."
if [ ! -f "$LOGS_DIR/cpu_speedups.csv" ]; then
    echo "Computing CPU speedups from raw data..."
    python3 << 'EOF'
import pandas as pd
import numpy as np

# Read the raw CPU data
cpu_raw = pd.read_csv("../../logs/cpu_raw.csv")
print(f"Loaded {len(cpu_raw)} rows from cpu_raw.csv")

# Clean up column names and data
cpu_raw.columns = cpu_raw.columns.str.strip()
cpu_raw["Sparsification ratio"] = cpu_raw["Sparsification ratio"].astype(str).str.strip()

# Debug: Print unique sparsification ratios
print("Unique sparsification ratios found:")
for ratio in cpu_raw["Sparsification ratio"].unique():
    print(f"  '{ratio}' (type: {type(ratio)})")

# Group by matrix name to compute speedups and convergence analysis
results = []

for matrix_name in cpu_raw["Matrix Name"].unique():
    matrix_data = cpu_raw[cpu_raw["Matrix Name"] == matrix_name]
    print(f"\nProcessing matrix: {matrix_name}")
    
    # Find the baseline (N/A sparsification ratio)
    # Note: pandas converts "N/A" to "nan" when reading CSV
    baseline = matrix_data[matrix_data["Sparsification ratio"].isin(["N/A", "NA", "n/a", "na", "nan", "NaN"])]
    print(f"  Found {len(baseline)} baseline entries")
    
    if len(baseline) == 0:
        print(f"  ERROR: No baseline found for matrix {matrix_name}")
        print(f"  Available sparsification ratios: {matrix_data['Sparsification ratio'].unique()}")
        continue
    
    baseline_row = baseline.iloc[0]
    baseline_cg_time = baseline_row["CG Time (ms)"]
    baseline_factorization_time = baseline_row["Factorization Time (ms)"]
    baseline_overall_time = baseline_cg_time + baseline_factorization_time
    baseline_iterations = baseline_row["Iterations Spent"]
    
    # Calculate per-iteration time for baseline
    baseline_per_iter_time = baseline_overall_time / baseline_iterations if baseline_iterations > 0 else float('inf')
    
    # Check convergence for baseline (assume converged if iterations < 1000)
    baseline_converged = baseline_iterations < 1000
    
    print(f"  Baseline: iterations={baseline_iterations}, overall_time={baseline_overall_time:.2f}ms, converged={baseline_converged}")
    
    # Process sparsified versions
    sparsified_data = matrix_data[~matrix_data["Sparsification ratio"].isin(["N/A", "NA", "n/a", "na", "nan", "NaN"])]
    print(f"  Found {len(sparsified_data)} sparsified entries")
    
    for _, row in sparsified_data.iterrows():
        sp_ratio_str = row["Sparsification ratio"]
        # Convert string ratio to float (e.g., "0.01" -> 0.01)
        try:
            sp_ratio = float(sp_ratio_str)
        except:
            print(f"    Warning: Cannot convert sparsification ratio '{sp_ratio_str}' to float for {matrix_name}")
            continue
        
        sp_cg_time = row["CG Time (ms)"]
        sp_factorization_time = row["Factorization Time (ms)"]
        sp_overall_time = sp_cg_time + sp_factorization_time
        sp_iterations = row["Iterations Spent"]
        
        # Calculate per-iteration time for sparsified version
        sp_per_iter_time = sp_overall_time / sp_iterations if sp_iterations > 0 else float('inf')
        
        # Calculate speedups
        per_iter_speedup = baseline_per_iter_time / sp_per_iter_time if sp_per_iter_time > 0 else 0
        end_to_end_speedup = baseline_overall_time / sp_overall_time if sp_overall_time > 0 else 0
        
        # Check convergence
        sp_converged = sp_iterations < 1000
        
        print(f"    Ratio {sp_ratio}: per-iter speedup={per_iter_speedup:.3f}, end-to-end speedup={end_to_end_speedup:.3f}")
        
        results.append({
            "Matrix Name": matrix_name,
            "Sparsification Ratio": sp_ratio,
            "Per-iteration Speedup": per_iter_speedup,
            "End-to-end Speedup": end_to_end_speedup,
            "Originally Converging": 1 if baseline_converged else 0,
            "Unaffectedly Converging": 1 if sp_converged else 0
        })

# Create DataFrame and save
if len(results) > 0:
    speedup_df = pd.DataFrame(results)
    speedup_df.to_csv("../../logs/cpu_speedups.csv", index=False)
    print(f"\nSaved {len(speedup_df)} speedup records to cpu_speedups.csv")
    
    # Print convergence statistics
    total_records = len(speedup_df)
    originally_converging = speedup_df["Originally Converging"].sum()
    unaffectedly_converging = speedup_df["Unaffectedly Converging"].sum()
    
    print(f"Convergence Analysis:")
    print(f"  Total records: {total_records}")
    print(f"  Originally converging: {originally_converging} ({100*originally_converging/total_records:.1f}%)")
    print(f"  Unaffectedly converging: {unaffectedly_converging} ({100*unaffectedly_converging/total_records:.1f}%)")
else:
    print("\nERROR: No speedup records generated. Creating empty CSV with headers.")
    empty_df = pd.DataFrame(columns=[
        "Matrix Name", "Sparsification Ratio", "Per-iteration Speedup", 
        "End-to-end Speedup", "Originally Converging", "Unaffectedly Converging"
    ])
    empty_df.to_csv("../../logs/cpu_speedups.csv", index=False)
EOF
    
    if [ ! -f "$LOGS_DIR/cpu_speedups.csv" ]; then
        echo "ERROR: Failed to generate cpu_speedups.csv"
        exit 1
    fi
    echo "Generated cpu_speedups.csv"
else
    echo "cpu_speedups.csv already exists"
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

echo "Step 5: Running CPU algorithm analysis..."
cd "$ALGORITHM_DIR"
python3 alg_cpu.py

if [ $? -eq 0 ]; then
    echo "CPU algorithm analysis completed successfully"
    echo "Results saved in algorithm directory"
else
    echo "ERROR: CPU algorithm analysis failed"
    exit 1
fi

echo "Step 6: Generating CPU speedup distribution histograms..."
cd "../plot"
python3 << 'EOF'
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

def prepare_cpu_data(speedup_file, algorithm_file, output_file):
    """Prepare CPU data with algorithm selected speedups"""
    try:
        algorithm_results = pd.read_csv(algorithm_file)
        
        if len(algorithm_results) > 0:
            # CPU algorithm results already have the correct column names
            # Just rename them to match the expected format
            result_data = algorithm_results.copy()
            result_data["Selected Per-iteration Speedup"] = algorithm_results["Per-iteration Speedup"]
            result_data["Selected End-to-end Speedup"] = algorithm_results["End-to-end Speedup"]
            
            result_data.to_csv(output_file, index=False)
            print(f"Prepared {len(result_data)} algorithm-selected records for CPU")
            return result_data
        else:
            print(f"Warning: No algorithm-selected data found for CPU")
            return None
    except FileNotFoundError:
        print(f"Warning: Algorithm results file not found for CPU")
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

        if method_name.upper() == "CPU":
            axis_label = speedup_type.replace("Selected ", "SPCG-ILU(0) ")
        else:
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

# Prepare and plot CPU histograms
print("Processing CPU histograms...")
cpu_data = prepare_cpu_data(
    "../../../logs/cpu_speedups.csv",
    "../../../script_src/python_scripts/algorithm/best_oracle_selection_gpu_pi_from_prediction_cpu.csv",
    "../../../results/cpu_histogram_data.csv"
)
if cpu_data is not None:
    plot_histogram(cpu_data, "CPU", output_dir)
EOF

if [ $? -eq 0 ]; then
    echo "CPU speedup distribution histograms generated successfully"
else
    echo "WARNING: Failed to generate CPU speedup distribution histograms"
fi

echo "=== CPU Analysis Pipeline Complete ==="
