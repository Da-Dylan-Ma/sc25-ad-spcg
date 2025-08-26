#!/bin/bash

echo "=========================================="
echo "Setting up CPU environment and building..."
echo "=========================================="

# Set the base directory for CPU source (relative to this script)
CPU_SRC_DIR="../../cpu_src"
BUILD_DIR="${CPU_SRC_DIR}/build"

echo "CPU source directory: ${CPU_SRC_DIR}"
echo "Build directory: ${BUILD_DIR}"

# Create build directory if it doesn't exist
if [ ! -d "${BUILD_DIR}" ]; then
    echo "Creating build directory..."
    mkdir -p "${BUILD_DIR}"
fi

# Navigate to build directory
cd "${BUILD_DIR}"

echo "=========================================="
echo "Building CPU executable..."
echo "=========================================="

# Configure with CMake
echo "Running CMake configuration..."
cmake "${CPU_SRC_DIR}"

if [ $? -eq 0 ]; then
    echo "CMake configuration successful!"
else
    echo "CMake configuration failed!"
    exit 1
fi

# Build the executable
echo "Building with make..."
make

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Executable created: ${BUILD_DIR}/conjugateGradientPrecond"
else
    echo "Build failed!"
    exit 1
fi

echo "=========================================="
echo "Running CPU jobs locally..."
echo "=========================================="

# Define matrices array (same as cluster scripts)
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

# Set the matrix directory path (relative to the build directory)
MATRIX_DIR="../../matrices"

# TODO: Set CPU affinity according to the machine specification, otherwise there could be difference between the reference and the artifact.
CPUSET="0,2,4,6,8,10,12,14"

echo "Running CPU jobs locally..."

# Create results directory
RESULTS_DIR="./results"
mkdir -p "$RESULTS_DIR"

# Initialize counter for completed jobs
counter=0
total_jobs=${#matrices[@]}

# Loop through each matrix and run the job locally
for matrix in "${matrices[@]}"; do
    ((counter++))
    echo "=========================================="
    echo "Processing matrix ${counter}/${total_jobs}: ${matrix}"
    echo "=========================================="
    
    # Matrix file paths
    matrix_dir="${MATRIX_DIR}/${matrix}"
    matrix_A="${matrix_dir}/${matrix}.mtx"
    
    # Check if matrix directory exists
    if [ ! -d "${matrix_dir}" ]; then
        echo "Matrix directory not found: ${matrix_dir}"
        echo "Skipping ${matrix}..."
        echo "-----------------------------"
        continue
    fi
    
    # Check if base matrix file exists
    if [ ! -f "${matrix_A}" ]; then
        echo "Base matrix file not found: ${matrix_A}"
        echo "Skipping ${matrix}..."
        echo "-----------------------------"
        continue
    fi
    
    # Create output file for this matrix
    output_file="${RESULTS_DIR}/cpu_${matrix}.out"
    
    echo "Running with base matrix as preconditioner..."
    echo "Output will be saved to: ${output_file}"
    
    # Run with base matrix as both A and B (like reference script)
    if command -v taskset >/dev/null 2>&1; then
        taskset -c ${CPUSET} ./conjugateGradientPrecond "${matrix_A}" "${matrix_A}" parallel > "${output_file}" 2>&1
    else
        ./conjugateGradientPrecond "${matrix_A}" "${matrix_A}" parallel > "${output_file}" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        echo "Base matrix run completed successfully"
    else
        echo "Base matrix run failed"
    fi
    
    # Run with perturbed versions as preconditioner
    for ratio in 0.01 0.05 0.10; do
        matrix_B="${matrix_dir}/${matrix}_${ratio}.mtx"
        if [ -f "${matrix_B}" ]; then
            echo "Running with perturbed matrix (${ratio}) as preconditioner..."
            perturbed_output="${RESULTS_DIR}/cpu_${matrix}_${ratio}.out"
            
            if command -v taskset >/dev/null 2>&1; then
                taskset -c ${CPUSET} ./conjugateGradientPrecond "${matrix_A}" "${matrix_B}" parallel > "${perturbed_output}" 2>&1
            else
                ./conjugateGradientPrecond "${matrix_A}" "${matrix_B}" parallel > "${perturbed_output}" 2>&1
            fi
            
            if [ $? -eq 0 ]; then
                echo "Perturbed matrix (${ratio}) run completed successfully"
            else
                echo "Perturbed matrix (${ratio}) run failed"
            fi
        else
            echo "Missing ${matrix_B}, skipping..."
        fi
    done
    
    echo "Completed ${matrix} (${counter}/${total_jobs})"
    echo "-----------------------------"
done

echo "=========================================="
echo "CPU local execution completed!"
echo "=========================================="
echo "Summary:"
echo "  - Executable: ${BUILD_DIR}/conjugateGradientPrecond"
echo "  - Jobs completed: ${counter}/${total_jobs}"
echo "  - Results saved to: ${RESULTS_DIR}/"
echo "  - CPU affinity: ${CPUSET}"
echo "  - Execution mode: parallel with OpenMP"
echo
