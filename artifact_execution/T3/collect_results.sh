#!/bin/bash

# Collect exported logs from T2

echo "=========================================="
echo "Collecting results from T2 executions..."
echo "=========================================="

mkdir -p ../../logs

extract_matrix_name() {
    local path="$1"
    local filename=$(basename "$path")
    local matrix_name=${filename%.mtx}
    echo "$matrix_name"
}

echo "=========================================="
echo "1. Collecting GPU ILU0 results..."
echo "=========================================="

ILU0_OUTPUT="../../logs/ilu0_raw.csv"
echo "Matrix Name,Sparsification Ratio,Rows,Cols,Nonzeros,Final Residual,Iterations Spent,Overall Time (ms),Preconditioning Time (ms)" > "$ILU0_OUTPUT"

# Collect from nonsp (sparsification ratio = 0)
echo "Collecting from GPU ILU0 NONSP results..."
NONSP_BUILD_DIR="../../gpu_src/ilu0_gpu/nonsp/build"
if [ -d "$NONSP_BUILD_DIR" ]; then
    ABS_ILU0_OUTPUT="$(realpath "$ILU0_OUTPUT")"
    
    cd "$NONSP_BUILD_DIR"
    
    if [ -f "results_summary_float.csv" ]; then
        echo "Found results_summary_float.csv in nonsp build directory"
        tail -n +2 "results_summary_float.csv" | while IFS=',' read -r matrix_name rows cols nonzeros final_residual iterations overall_time precond_time pcg_time; do
            echo "$matrix_name,0,$rows,$cols,$nonzeros,$final_residual,$iterations,$overall_time,$precond_time" >> "$ABS_ILU0_OUTPUT"
        done
    else
        echo "Warning: results_summary_float.csv not found in nonsp build directory"
    fi
    
    cd - > /dev/null
else
    echo "Warning: NONSP build directory not found: $NONSP_BUILD_DIR"
fi

# Collect from sp (sparsification ratio from the CSV)
echo "Collecting from GPU ILU0 SP results..."
SP_BUILD_DIR="../../gpu_src/ilu0_gpu/sp/build"
if [ -d "$SP_BUILD_DIR" ]; then
    ABS_ILU0_OUTPUT="$(realpath "$ILU0_OUTPUT")"
    
    cd "$SP_BUILD_DIR"
    
    if [ -f "results_summary.csv" ]; then
        echo "Found results_summary.csv in sp build directory"
        tail -n +2 "results_summary.csv" | while IFS=',' read -r matrix_name spar_ratio rows cols nonzeros final_residual iterations overall_time precond_time; do
            echo "$matrix_name,$spar_ratio,$rows,$cols,$nonzeros,$final_residual,$iterations,$overall_time,$precond_time" >> "$ABS_ILU0_OUTPUT"
        done
    else
        echo "Warning: results_summary.csv not found in sp build directory"
    fi
    
    cd - > /dev/null
else
    echo "Warning: SP build directory not found: $SP_BUILD_DIR"
fi

echo "GPU ILU0 results collected in: $ILU0_OUTPUT"

echo "=========================================="
echo "2. Collecting GPU ILUK results..."
echo "=========================================="

# Initialize GPU ILUK output file
ILUK_OUTPUT="../../logs/iluk_raw.csv"
echo "Matrix Name,Fill Factor,Sparsification Ratio,Rows,Cols,Nonzeros,Final Residual,Iterations Spent,PCG Time (ms)" > "$ILUK_OUTPUT"

# Collect from ILUK build directories
echo "Collecting from GPU ILUK results..."
ILUK_BUILD_DIR="../../gpu_src/iluk_gpu/build"
if [ -d "$ILUK_BUILD_DIR" ]; then
    ABS_ILUK_OUTPUT="$(realpath "$ILUK_OUTPUT")"
    
    cd "$ILUK_BUILD_DIR"
    
    if [ -f "results_summary.csv" ]; then
        echo "Found results_summary.csv in ILUK build directory"
        tail -n +2 "results_summary.csv" | while IFS=',' read -r matrix_name parent_dir rows cols nonzeros final_residual iterations pcg_time; do
            fill_factor="N/A"
            spar_ratio="0.0"
            
            if [[ "$parent_dir" =~ ff([0-9]+) ]]; then
                fill_factor="${BASH_REMATCH[1]}"
            fi
            
            if [[ "$parent_dir" =~ spTrue.*p([0-9]+\.?[0-9]*) ]]; then
                spar_ratio="${BASH_REMATCH[1]}"
            elif [[ "$parent_dir" =~ spFalse ]]; then
                spar_ratio="0.0"
            fi
            
            echo "$matrix_name,$fill_factor,$spar_ratio,$rows,$cols,$nonzeros,$final_residual,$iterations,$pcg_time" >> "$ABS_ILUK_OUTPUT"
        done
    else
        echo "Warning: results_summary.csv not found in ILUK build directory"
    fi
    
    cd - > /dev/null
else
    echo "Warning: ILUK build directory not found: $ILUK_BUILD_DIR"
fi

echo "GPU ILUK results collected in: $ILUK_OUTPUT"

echo "=========================================="
echo "3. Collecting CPU results..."
echo "=========================================="

# Initialize CPU output file  
CPU_OUTPUT="../../logs/cpu_raw.csv"
echo "Matrix Name,Sparsification ratio,Rows,Cols,Nonzeros,Final Residual,Iterations Spent,CG Time (ms),Factorization Time (ms),Parallelism" > "$CPU_OUTPUT"

# Collect from CPU build directory
echo "Collecting from CPU results..."
CPU_BUILD_DIR="../../cpu_src/build"
if [ -d "$CPU_BUILD_DIR" ]; then
    ABS_CPU_OUTPUT="$(realpath "$CPU_OUTPUT")"
    
    cd "$CPU_BUILD_DIR"
    
    for csv_file in cpu_results_*.csv; do
        if [ -f "$csv_file" ]; then
            echo "Processing CPU result file: $csv_file"
            tail -n +2 "$csv_file" >> "$ABS_CPU_OUTPUT"
        fi
    done
    
    cd - > /dev/null
else
    echo "Warning: CPU build directory not found: $CPU_BUILD_DIR"
fi

echo "CPU results collected in: $CPU_OUTPUT"

echo "=========================================="
echo "4. Results Summary"
echo "=========================================="

echo "Collection completed! Results saved to:"
echo "  - GPU ILU0: $(realpath "$ILU0_OUTPUT")"
echo "  - GPU ILUK: $(realpath "$ILUK_OUTPUT")"  
echo "  - CPU:      $(realpath "$CPU_OUTPUT")"
echo

if [ -f "$ILU0_OUTPUT" ]; then
    ilu0_count=$(($(wc -l < "$ILU0_OUTPUT") - 1))
    echo "GPU ILU0 entries: $ilu0_count"
fi

if [ -f "$ILUK_OUTPUT" ]; then
    iluk_count=$(($(wc -l < "$ILUK_OUTPUT") - 1))
    echo "GPU ILUK entries: $iluk_count"
fi

if [ -f "$CPU_OUTPUT" ]; then
    cpu_count=$(($(wc -l < "$CPU_OUTPUT") - 1))
    echo "CPU entries: $cpu_count"
fi

echo
echo "Note: If any counts are 0, check that the corresponding job scripts"
echo "have been executed and the result files are in the expected locations."
echo "=========================================="
