#!/bin/bash

# GPU ILU0 Local Execution Script
# This script compiles and runs both the nonsp and sp versions of the ILU0 GPU implementation locally

echo "Starting GPU ILU0 compilation and local execution..."

# Set base directory
BASE_DIR="../../gpu_src/ilu0_gpu"

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
    cd - > /dev/null
    
    return 0
}

# Compile nonsp version
if ! compile_directory "nonsp"; then
    echo "Failed to compile nonsp version"
    exit 1
fi

# Compile sp version  
if ! compile_directory "sp"; then
    echo "Failed to compile sp version"
    exit 1
fi

echo "=========================================="
echo "All GPU ILU0 compilations completed successfully!"
echo "=========================================="
echo "Executables created:"
echo "  - nonsp: ${BASE_DIR}/nonsp/build/conjugateGradientPrecond"
echo "  - sp:    ${BASE_DIR}/sp/build/conjugateGradientPrecond"
echo

# Run jobs locally
echo "=========================================="
echo "Running GPU ILU0 jobs locally..."
echo "=========================================="

# Define matrices array (from generate_jobs.sh)
matrices=(
    "Chem97ZtZ" "Dubcova1" "Dubcova2" "Dubcova3" "G2_circuit" "Kuu" "LF10000" "LFAT5000" 
    "Muu" "Pres_Poisson" "aft01" "apache1" "bcsstk08" "bcsstk09" "bcsstk10" "bcsstk11" 
    "bcsstk12" "bcsstk13" "bcsstk14" "bcsstk15" "bcsstk16" "bcsstk17" "bcsstk18" "bcsstk21" 
    "bcsstk23" "bcsstk25" "bcsstk26" "bcsstk27" "bcsstk28" "bcsstk36" "bcsstk38" "bcsstm08" 
    "bcsstm09" "bcsstm11" "bcsstm12" "bcsstm21" "bcsstm23" "bcsstm24" "bcsstm25" "bcsstm26" 
    "bcsstm39" "bloweybq" "bodyy4" "bodyy5" "bodyy6" "bundle1" "cant" "cbuckle" "cfd1" "crystm01" 
    "crystm02" "crystm03" "ct20stif" "cvxbqp1" "denormal" "ex10" "ex10hs" "ex13" "ex15" "ex3" "ex33" 
    "finan512" "fv1" "fv2" "fv3" "gridgena" "gyro" "gyro_k" "gyro_m" "jnlbrng1" "mhd3200b" "mhd4800b" 
    "minsurfo" "msc01050" "msc01440" "msc04515" "msc10848" "msc23052" "nasa1824" "nasa2146" "nasa2910" 
    "nasa4704" "nasasrb" "nd3k" "obstclae" "olafu" "parabolic_fem" "plat1919" "plbuckle" "qa8fm" 
    "raefsky4" "s1rmq4m1" "s1rmt3m1" "s2rmq4m1" "s2rmt3m1" "s3rmq4m1" "s3rmt3m1" "s3rmt3m3" 
    "shallow_water1" "shallow_water2" "sts4098" "t2dah_e" "t2dal_e" "t3dl_e" "ted_B" "ted_B_unscaled" 
    "thermal1" "thermomech_TC" "thermomech_TK" "thermomech_dM" "torsion1" "vanbody" "wathen100" "wathen120"
)

# Set the matrix directory path (relative to the build directories)
MATRIX_DIR="../../../../matrices"

# Function to run jobs locally for a specific directory
run_jobs_locally() {
    local dir_name=$1
    local build_path="${BASE_DIR}/${dir_name}/build"
    
    echo "Running jobs locally for ${dir_name}..."
    
    # Navigate to the build directory
    cd "${build_path}"
    
    # Create results directory
    local results_dir="./results"
    mkdir -p "$results_dir"
    
    # Initialize counter for completed jobs
    local counter=0
    local total_jobs=${#matrices[@]}
    
    # Loop through each matrix and run the job locally
    for matrix in "${matrices[@]}"; do
        ((counter++))
        echo "=========================================="
        echo "Processing matrix ${counter}/${total_jobs}: ${matrix} (${dir_name})"
        echo "=========================================="
        
        # Matrix file path
        matrix_file="${MATRIX_DIR}/${matrix}/${matrix}.mtx"
        
        # Check if matrix file exists
        if [ ! -f "${matrix_file}" ]; then
            echo "Matrix file not found: ${matrix_file}"
            echo "Skipping ${matrix}..."
            echo "-----------------------------"
            continue
        fi
        
        echo "Processing matrix: ${matrix_file}"
        
        if [ "$dir_name" = "nonsp" ]; then
            # For nonsp: no sparsification ratio needed
            output_file="${results_dir}/ilu0_${dir_name}_${matrix}.out"
            echo "Running nonsp version, output to: ${output_file}"
            
            ./conjugateGradientPrecond "${matrix_file}" > "${output_file}" 2>&1
            
            if [ $? -eq 0 ]; then
                echo "Nonsp run completed successfully"
            else
                echo "Nonsp run failed"
            fi
        else
            # For sp: use sparsification ratios
            echo "Running sp version with different sparsification ratios..."
            
            for ratio in 0.01 0.05 0.1; do
                output_file="${results_dir}/ilu0_${dir_name}_${matrix}_${ratio}.out"
                echo "Running with ratio ${ratio}, output to: ${output_file}"
                
                ./conjugateGradientPrecond "${matrix_file}" "${ratio}" > "${output_file}" 2>&1
                
                if [ $? -eq 0 ]; then
                    echo "SP run with ratio ${ratio} completed successfully"
                else
                    echo "SP run with ratio ${ratio} failed"
                fi
            done
        fi
        
        echo "Completed ${matrix} (${counter}/${total_jobs}) for ${dir_name}"
        echo "-----------------------------"
    done
    
    echo "Completed all jobs for ${dir_name}. Results saved to: ${results_dir}/"
    
    # Return to original directory
    cd - > /dev/null
    
    return $counter
}

# Run jobs locally for both nonsp and sp versions
run_jobs_locally "nonsp"
nonsp_count=$?

run_jobs_locally "sp"
sp_count=$?

total_completed=$((nonsp_count + sp_count))

echo "=========================================="
echo "GPU ILU0 local execution completed successfully!"
echo "=========================================="
echo "Total jobs completed:"
echo "  - nonsp: $nonsp_count jobs"
echo "  - sp:    $sp_count jobs"
echo "  - Total: $total_completed jobs"
echo
echo "Results saved to:"
echo "  - nonsp: ${BASE_DIR}/nonsp/build/results/"
echo "  - sp:    ${BASE_DIR}/sp/build/results/"
echo
