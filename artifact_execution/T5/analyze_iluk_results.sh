#!/bin/bash

echo "=== ILUK Algorithm Analysis Pipeline ==="

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

echo "Step 3: Appending factorization times to ILUK raw data..."
if [ ! -f "$LOGS_DIR/iluk_raw_with_factorization.csv" ]; then
    echo "Appending factorization times from timing files..."
    python3 << 'EOF'
import pandas as pd
import glob
import os

# Read the raw ILUK data
iluk_raw = pd.read_csv("../../logs/iluk_raw.csv")
print(f"Loaded {len(iluk_raw)} rows from iluk_raw.csv")

# Find all timing files
timing_files = glob.glob("../../factors/timing/*_timing.csv")
print(f"Found {len(timing_files)} timing files")

if len(timing_files) == 0:
    print("ERROR: No timing files found")
    exit(1)

# Read and combine all timing data
all_timing_data = []
for file_path in timing_files:
    try:
        df = pd.read_csv(file_path)
        all_timing_data.append(df)
    except Exception as e:
        print(f"Error reading {file_path}: {e}")

timing_df = pd.concat(all_timing_data, ignore_index=True)
print(f"Combined {len(timing_df)} timing records")

# Create mapping for factorization times
factorization_times = {}
for _, row in timing_df.iterrows():
    matrix_name = row["Matrix Name"]
    fill_factor = row["Fill Factor"]
    sparsified = row["Sparsified"]
    removal_percentage = row["Removal Percentage"]
    factorization_time_s = row["Time (s)"]
    
    # Convert to sparsification ratio
    sp_ratio = removal_percentage if sparsified else 0.0
    
    key = (matrix_name, fill_factor, sp_ratio)
    factorization_times[key] = factorization_time_s * 1000  # Convert to ms

print(f"Created {len(factorization_times)} factorization time mappings")

# Append factorization times to ILUK raw data
results = []
for _, row in iluk_raw.iterrows():
    matrix_name = row["Matrix Name"]
    fill_factor = row["Fill Factor"]
    sp_ratio = row["Sparsification Ratio"]
    pcg_time_ms = row["PCG Time (ms)"]
    
    key = (matrix_name, fill_factor, sp_ratio)
    factorization_time_ms = factorization_times.get(key, 0)
    
    if factorization_time_ms == 0:
        print(f"Warning: No factorization time found for {matrix_name}, ff={fill_factor}, sp={sp_ratio}")
    
    # Calculate overall time
    overall_time_ms = factorization_time_ms + pcg_time_ms
    
    # Create new row with all original columns plus factorization and overall time
    new_row = row.to_dict()
    new_row["Factorization Time (ms)"] = factorization_time_ms
    new_row["Overall Time (ms)"] = overall_time_ms
    
    results.append(new_row)

# Create new DataFrame with appended data
enhanced_df = pd.DataFrame(results)
enhanced_df.to_csv("../../logs/iluk_raw_with_factorization.csv", index=False)
print(f"Saved enhanced ILUK data with {len(enhanced_df)} rows")
EOF
    
    if [ ! -f "$LOGS_DIR/iluk_raw_with_factorization.csv" ]; then
        echo "ERROR: Failed to create iluk_raw_with_factorization.csv"
        exit 1
    fi
    echo "Generated iluk_raw_with_factorization.csv"
else
    echo "iluk_raw_with_factorization.csv already exists"
fi

echo "Step 4: Creating ILUK best fill factor data and speedups..."
if [ ! -f "$LOGS_DIR/iluk_speedups_best_fill_factor.csv" ]; then
    echo "Computing ILUK speedups with best fill factor selection..."
    python3 << 'EOF'
import pandas as pd
import numpy as np

# Read the enhanced ILUK data
iluk_df = pd.read_csv("../../logs/iluk_raw_with_factorization.csv")
print(f"Loaded {len(iluk_df)} rows from iluk_raw_with_factorization.csv")

# Group by matrix name and sparsification ratio to select best fill factor
best_fill_results = []
speedup_results = []

for matrix_name in iluk_df["Matrix Name"].unique():
    matrix_data = iluk_df[iluk_df["Matrix Name"] == matrix_name]
    
    for sp_ratio in matrix_data["Sparsification Ratio"].unique():
        ratio_data = matrix_data[matrix_data["Sparsification Ratio"] == sp_ratio]
        
        # Select best fill factor (lowest overall time)
        best_row = ratio_data.loc[ratio_data["Overall Time (ms)"].idxmin()]
        best_fill_results.append(best_row.to_dict())

# Create best fill factor DataFrame
best_fill_df = pd.DataFrame(best_fill_results)
best_fill_df.to_csv("../../logs/iluk_raw_best_fill_factor.csv", index=False)
print(f"Saved best fill factor data with {len(best_fill_df)} rows")

# Now compute speedups using best fill factor data
for matrix_name in best_fill_df["Matrix Name"].unique():
    matrix_data = best_fill_df[best_fill_df["Matrix Name"] == matrix_name]
    
    # Find baseline (sparsification ratio = 0)
    baseline = matrix_data[matrix_data["Sparsification Ratio"] == 0.0]
    if len(baseline) == 0:
        print(f"Warning: No baseline found for matrix {matrix_name}")
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
        
        speedup_results.append({
            "Matrix Name": matrix_name,
            "Sparsification Ratio": sp_ratio,
            "Per-iteration Speedup": per_iter_speedup,
            "End-to-end Speedup": end_to_end_speedup
        })

# Create speedup DataFrame
speedup_df = pd.DataFrame(speedup_results)
speedup_df.to_csv("../../logs/iluk_speedups_best_fill_factor.csv", index=False)
print(f"Saved {len(speedup_df)} speedup records to iluk_speedups_best_fill_factor.csv")
EOF
    
    if [ ! -f "$LOGS_DIR/iluk_speedups_best_fill_factor.csv" ]; then
        echo "ERROR: Failed to generate ILUK speedup files"
        exit 1
    fi
    echo "Generated ILUK speedup and best fill factor files"
else
    echo "ILUK speedup files already exist"
fi

echo "Step 5: Creating wavefronts data..."
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

echo "Step 6: Running ILUK algorithm analysis..."
cd "$ALGORITHM_DIR"
python3 alg_iluk.py

if [ $? -eq 0 ]; then
    echo "ILUK algorithm analysis completed successfully"
    echo "Results saved in algorithm directory"
else
    echo "ERROR: ILUK algorithm analysis failed"
    exit 1
fi

echo "Step 7: Generating ILUK correlation plot..."
cd "../plot"
python3 correlation_iluk_updated.py
if [ $? -eq 0 ]; then
    echo "ILUK correlation plot generated successfully"
else
    echo "WARNING: Failed to generate ILUK correlation plot"
fi

echo "Step 8: Generating ILUK speedup distribution histograms..."
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

# Prepare and plot ILUK histograms
print("Processing ILUK histograms...")
iluk_data = prepare_algorithm_selected_data(
    "../../../logs/iluk_speedups_best_fill_factor.csv",
    "../../../script_src/python_scripts/algorithm/best_oracle_selection_gpu_pi_from_prediction.csv",
    "../../../results/iluk_histogram_data.csv",
    "ILUK"
)
if iluk_data is not None:
    plot_histogram(iluk_data, "ILUK", output_dir)
EOF

if [ $? -eq 0 ]; then
    echo "ILUK speedup distribution histograms generated successfully"
else
    echo "WARNING: Failed to generate ILUK speedup distribution histograms"
fi

echo "=== ILUK Analysis Pipeline Complete ==="
