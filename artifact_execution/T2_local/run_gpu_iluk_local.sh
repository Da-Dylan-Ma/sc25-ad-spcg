#!/bin/bash

# GPU ILUK Local Execution Script
# This script is equivalent to the cluster version but runs locally

echo "Starting GPU ILUK compilation and local execution..."

# Store the original working directory
ORIGINAL_DIR="${PWD}"

# Set base directory
BASE_DIR="../../gpu_src/iluk_gpu"
MATRIX_DIR="../../matrices"

# Function to compile a directory
compile_directory() {
    local dir_name=$1
    local full_path="${BASE_DIR}/${dir_name}"
    
    echo "=========================================="
    echo "Compiling ${dir_name}..."
    echo "=========================================="
    
    if [ ! -d "${full_path}" ]; then
        echo "Error: Directory ${full_path} does not exist!"
        return 1
    fi
    
    # Create build directory
    mkdir -p "${full_path}/build"
    
    # Navigate to build directory
    cd "${full_path}/build"
    
    # Configure with CMake
    echo "Configuring ${dir_name} with CMake..."
    if ! cmake ..; then
        echo "Error: CMake configuration failed for ${dir_name}"
        return 1
    fi
    
    # Build
    echo "Building ${dir_name}..."
    if ! make; then
        echo "Error: Build failed for ${dir_name}"
        return 1
    fi
    
    echo "Successfully compiled ${dir_name}"
    echo
    
    # Return to original directory
    cd "${ORIGINAL_DIR}"
    
    return 0
}

if ! compile_directory "."; then
    echo "Failed to compile"
    exit 1
fi

echo "=========================================="
echo "GPU ILUK compilations completed successfully!"
echo "=========================================="
echo "Executables created:"
echo "  - ${BASE_DIR}/build/conjugateGradientPrecond"
echo

# Run scipy factorization jobs locally
echo "=========================================="
echo "Running scipy factorization jobs locally..."
echo "=========================================="

matrices=(
    "Chem97ZtZ" "1138_bus" "Dubcova2" "Dubcova3" "G2_circuit" "Kuu" "LF10000" "LFAT5000" 
    "Muu" "Pres_Poisson" "aft01" "apache1" "bcsstk08" "bcsstk09" "bcsstk10" "bcsstk11" 
    "bcsstk12" "bcsstk13" "bcsstk14" "bcsstk15" "bcsstk16" "bcsstk17" "bcsstk18" "bcsstk21" 
    "bcsstk23" "bcsstk25" "bcsstk26" "bcsstk27" "bcsstk28" "bcsstk36" "bcsstk38" "bcsstm08" 
    "bcsstk09" "1138_bus" "bcsstm12" "bcsstm21" "bcsstm23" "bcsstm24" "bcsstm25" "bcsstm26" 
    "bcsstm39" "bloweybq" "bodyy4" "bodyy5" "bodyy6" "bundle1" "cant" "cbuckle" "cfd1" "crystm01" 
    "crystm02" "crystm03" "ct20stif" "cvxbqp1" "denormal" "ex10" "ex10hs" "ex13" "ex15" "ex3" "ex33" 
    "finan512" "fv1" "fv2" "fv3" "gridgena" "gyro" "gyro_k" "gyro_m" "jnlbrng1" "mhd3200b" "mhd4800b" 
    "minsurfo" "msc01050" "msc01440" "msc04515" "msc10848" "msc23052" "nasa1824" "nasa2146" "nasa2910" 
    "nasa4704" "nasasrb" "nd3k" "obstclae" "olafu" "parabolic_fem" "plat1919" "plbuckle" "qa8fm" 
    "raefsky4" "s1rmq4m1" "s1rmt3m1" "s2rmq4m1" "s2rmt3m1" "s3rmq4m1" "s3rmt3m1" "s3rmt3m3" 
    "shallow_water1" "shallow_water2" "sts4098" "t2dah_e" "t2dal_e" "t3dl_e" "ted_B" "ted_B_unscaled" 
    "thermal1" "thermomech_TC" "thermomech_TK" "thermomech_dM" "torsion1" "vanbody" "wathen100" "wathen120"
)

# Navigate to factorization directory
FACTORIZATION_DIR="${BASE_DIR}/../../script_src/python_scripts/prep/iluk_factorization"
if [ ! -d "${FACTORIZATION_DIR}" ]; then
    echo "Error: Factorization directory not found: ${FACTORIZATION_DIR}"
    exit 1
fi

cd "${FACTORIZATION_DIR}"

# Test run with a single matrix to verify directory structure
echo "Testing with 1138_bus matrix..."
FULL_MATRIX_PATH="${ORIGINAL_DIR}/../../matrices/1138_bus/1138_bus.mtx"
if [ -f "${FULL_MATRIX_PATH}" ]; then
    echo "Running test: python iluk_factorize.py ${FULL_MATRIX_PATH}"
    python3 iluk_factorize.py "${FULL_MATRIX_PATH}"
    echo "Test completed."
    
    # Show created files
    echo "Files created in ../../../../factors/:"
    ls -la "../../../../factors/" 2>/dev/null || echo "No factors directory found"
    echo "Files created in ../../../../factors/timing/:"
    ls -la "../../../../factors/timing/" 2>/dev/null || echo "No timing directory found"
else
    echo "Warning: 1138_bus matrix not found at ${FULL_MATRIX_PATH}"
fi

# Run factorization for all matrices
echo "Running factorization for all matrices..."

for matrix in "${matrices[@]}"; do
    echo "=========================================="
    echo "Processing factorization for: ${matrix}"
    echo "=========================================="
    
    # Matrix file path
    matrix_file="${ORIGINAL_DIR}/../../matrices/${matrix}/${matrix}.mtx"
    
    # Check if matrix file exists
    if [ ! -f "${matrix_file}" ]; then
        echo "Matrix file not found: ${matrix_file}"
        echo "Skipping ${matrix} factorization..."
        echo "-----------------------------"
        continue
    fi
    
    echo "Running factorization for: ${matrix_file}"
    
    # Run factorization
    python3 iluk_factorize.py "${matrix_file}"
    
    if [ $? -eq 0 ]; then
        echo "Factorization completed successfully for ${matrix}"
    else
        echo "Factorization failed for ${matrix}"
    fi
    
    echo "Completed factorization for ${matrix}"
    echo "-----------------------------"
done

echo "=========================================="
echo "Factorization completed successfully!"
echo "=========================================="

# Organize the generated factors (equivalent to cluster script)
echo "=========================================="
echo "Organizing generated factors..."
echo "=========================================="

FACTORS_DIR="../../../../factors"
if [ -d "$FACTORS_DIR" ]; then
    cd "$FACTORS_DIR"
    
    for l_file in *_l_*.mtx; do
        # Skip if no files match the pattern
        if [ ! -f "$l_file" ]; then
            continue
        fi
        
        u_file="${l_file/_l_/_u_}"
        
        if [ -f "$u_file" ]; then
            # Extract matrix name from the L file
            # Pattern: exp_tag_matrix_name_l_fill_factor_sp_percentage.mtx
            # Handle matrix names with underscores (like 1138_bus)
            if [[ "$l_file" =~ ^spilu_sp_(.*)_l_[^_]*_[^_]*_[^_]*\.mtx$ ]]; then
                matrix_name="${BASH_REMATCH[1]}"
            elif [[ "$l_file" =~ ^spilu_nonsp_(.*)_l_[^_]*_[^_]*_[^_]*\.mtx$ ]]; then
                matrix_name="${BASH_REMATCH[1]}"
            else
                matrix_name=""
            fi
            
            if [ -n "$matrix_name" ]; then
                # Create directory name with full parameter info
                # Extract fill factor, sparsification flag, and percentage from filename
                if [[ "$l_file" =~ ^spilu_(sp|nonsp)_(.*)_l_([^_]*)_([^_]*)_([^_]*)\.mtx$ ]]; then
                    sp_flag="${BASH_REMATCH[1]}"
                    fill_factor="${BASH_REMATCH[3]}"
                    sparse_flag="${BASH_REMATCH[4]}"
                    percentage="${BASH_REMATCH[5]}"
                    
                    # Create descriptive directory name
                    dir_name="${matrix_name}_ff${fill_factor}_sp${sparse_flag}_p${percentage}"
                    
                    mkdir -p "$dir_name"
                    
                    mv "$l_file" "$dir_name/"
                    mv "$u_file" "$dir_name/"
                    
                    echo "Organized factors for $matrix_name: $dir_name"
                else
                    # Fallback to simple matrix name if parsing fails
                    mkdir -p "$matrix_name"
                    
                    mv "$l_file" "$matrix_name/"
                    mv "$u_file" "$matrix_name/"
                    
                    echo "Organized factors for $matrix_name (fallback): $l_file and $u_file"
                fi
            else
                echo "Could not extract matrix name from $l_file"
            fi
        fi
    done
    
    # Return to the previous directory
    cd - > /dev/null
else
    echo "Factors directory not found at $FACTORS_DIR"
fi

# Run GPU jobs locally (equivalent to cluster job submission)
echo "=========================================="
echo "Running GPU ILUK jobs locally..."
echo "=========================================="

# Return to original directory and then navigate to build directory for GPU execution
cd "${ORIGINAL_DIR}"
cd "${BASE_DIR}/build"

# Create results directory
GPU_RESULTS_DIR="./results"
mkdir -p "$GPU_RESULTS_DIR"

# Initialize counter for completed GPU jobs
gpu_counter=0
total_gpu_jobs=${#matrices[@]}

# Loop through each matrix and run the GPU job locally
for matrix in "${matrices[@]}"; do
    ((gpu_counter++))
    echo "=========================================="
    echo "Processing GPU job ${gpu_counter}/${total_gpu_jobs}: ${matrix}"
    echo "=========================================="
    
    # Matrix file path
    matrix_file="${ORIGINAL_DIR}/../../matrices/${matrix}/${matrix}.mtx"
    factors_dir="${ORIGINAL_DIR}/../../factors"
    
    # Check if matrix file exists
    if [ ! -f "${matrix_file}" ]; then
        echo "Matrix file not found: ${matrix_file}"
        echo "Skipping ${matrix} GPU job..."
        echo "-----------------------------"
        continue
    fi
    
    echo "Processing matrix: ${matrix_file}"
    
    # Check if factors directory exists
    if [ ! -d "${factors_dir}" ]; then
        echo "Factors directory not found: ${factors_dir}"
        echo "Skipping ${matrix} GPU job..."
        echo "-----------------------------"
        continue
    fi
    
    # Look for directories that start with the matrix name
    matrix_processed=false
    for factor_dir in ${factors_dir}/${matrix}_*; do
        if [ -d "$factor_dir" ]; then
            echo "Processing factor directory: $factor_dir"
            
            # Find L and U factor files in this directory
            l_factor=$(find "$factor_dir" -name "*_l_*.mtx" | head -1)
            u_factor=$(find "$factor_dir" -name "*_u_*.mtx" | head -1)
            
            if [ -f "$l_factor" ] && [ -f "$u_factor" ]; then
                echo "Found factors: L=$l_factor, U=$u_factor"
                
                # Create output file for this matrix and factor combination
                factor_dir_name=$(basename "$factor_dir")
                output_file="${GPU_RESULTS_DIR}/iluk_${matrix}_${factor_dir_name}.out"
                
                echo "Running: ./conjugateGradientPrecond ${matrix_file} ${l_factor} ${u_factor}"
                echo "Output will be saved to: ${output_file}"
                
                # Run the GPU job
                ./conjugateGradientPrecond "${matrix_file}" "${l_factor}" "${u_factor}" > "${output_file}" 2>&1
                
                if [ $? -eq 0 ]; then
                    echo "GPU ILUK job completed successfully for ${matrix} with ${factor_dir_name}"
                    matrix_processed=true
                else
                    echo "GPU ILUK job failed for ${matrix} with ${factor_dir_name}"
                fi
            else
                echo "Warning: Could not find L and/or U factor files in $factor_dir"
                echo "L factor: $l_factor"
                echo "U factor: $u_factor"
            fi
        fi
    done
    
    if [ "$matrix_processed" = false ]; then
        echo "No valid factor combinations found for ${matrix}"
    fi
    
    echo "Completed GPU job for ${matrix} (${gpu_counter}/${total_gpu_jobs})"
    echo "-----------------------------"
done

echo "=========================================="
echo "GPU ILUK local execution completed successfully!"
echo "=========================================="
echo "Summary:"
echo "  - Executable: ${BASE_DIR}/build/conjugateGradientPrecond"
echo "  - GPU jobs completed: ${gpu_counter}/${total_gpu_jobs}"
echo "  - Results saved to: ${GPU_RESULTS_DIR}/"
echo

# Return to original directory
cd "${ORIGINAL_DIR}"
