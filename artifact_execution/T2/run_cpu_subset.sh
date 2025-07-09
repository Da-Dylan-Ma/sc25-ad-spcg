#!/bin/bash

echo "=========================================="
echo "Setting up CPU environment and building..."
echo "=========================================="

# Set the base directory for CPU source (relative to this script)
CPU_SRC_DIR="../../cpu_src"
BUILD_DIR="${CPU_SRC_DIR}/build"

echo "CPU source directory: ${CPU_SRC_DIR}"
echo "Build directory: ${BUILD_DIR}"

if [ ! -d "${BUILD_DIR}" ]; then
    echo "Creating build directory..."
    mkdir -p "${BUILD_DIR}"
fi

cd "${BUILD_DIR}"

echo "=========================================="
echo "Building CPU executable..."
echo "=========================================="

echo "Running CMake configuration..."
cmake "${CPU_SRC_DIR}"

if [ $? -eq 0 ]; then
    echo "CMake configuration successful!"
else
    echo "CMake configuration failed!"
    exit 1
fi

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
echo "Generating CPU job submission scripts..."
echo "=========================================="

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

MATRIX_DIR="../../matrices"

# TODO: Set CPU affinity according to the machine specification, otherwise there could be difference between the reference and the artifact.
CPUSET="0,2,4,6,8,10,12,14"

echo "Generating job scripts for CPU execution..."

for matrix in "${matrices[@]}"; do
    script_name="job_submit_cpu_${matrix}.sh"
    
    echo "Generating script: ${script_name}"
    
    # Generate job script content
    cat << EOF > $script_name
#!/bin/bash

#SBATCH --cpus-per-task=8
#SBATCH --export=ALL
#SBATCH --job-name="cpu_ilu0_${matrix}"
#SBATCH --nodes=1
#SBATCH --output="cpu_ilu0_${matrix}.%j.%N.out"
#SBATCH -t 11:59:00

module load StdEnv/2020
module load intel/2022.1.0
module load anaconda3/2021.05

# Set CPU affinity
CPUSET="${CPUSET}"

# Matrix file paths
matrix_dir="${MATRIX_DIR}/${matrix}"
matrix_A="\${matrix_dir}/${matrix}.mtx"

# Check if matrix directory exists
if [ ! -d "\$matrix_dir" ]; then
    echo "Matrix directory not found: \$matrix_dir"
    exit 1
fi

# Check if base matrix file exists
if [ ! -f "\$matrix_A" ]; then
    echo "Base matrix file not found: \$matrix_A"
    exit 1
fi

# Run with base matrix as both A and B (like reference script)
echo "Running with base matrix as preconditioner..."
taskset -c \$CPUSET ./conjugateGradientPrecond "\$matrix_A" "\$matrix_A" parallel

# Run with perturbed versions as preconditioner
for ratio in 0.01 0.05 0.10; do
    matrix_B="\${matrix_dir}/${matrix}_\$ratio.mtx"
    if [ -f "\$matrix_B" ]; then
        echo "Running with perturbed matrix (\$ratio) as preconditioner..."
        taskset -c \$CPUSET ./conjugateGradientPrecond "\$matrix_A" "\$matrix_B" parallel
    else
        echo "Missing \$matrix_B, skipping..."
    fi
done

echo "Done with ${matrix}"
echo "-----------------------------"
EOF

    chmod +x $script_name
done

echo "Generated ${#matrices[@]} CPU job scripts in ${BUILD_DIR}"

echo "=========================================="
echo "CPU job script generation completed!"
echo "=========================================="
echo "Build information:"
echo "  - Executable: ${BUILD_DIR}/conjugateGradientPrecond"
echo "  - Job scripts: ${BUILD_DIR}/job_submit_cpu_*.sh"
echo "  - Total scripts: ${#matrices[@]}"
echo

echo "=========================================="
echo "Submitting CPU job scripts..."
echo "=========================================="

echo "Submitting job scripts..."

submitted_dir="./submitted"
mkdir -p "$submitted_dir"

counter=0
max_jobs=200

for script in ./job_submit_cpu_*.sh; do
    if [ -f "$script" ]; then
        if [ $counter -ge $max_jobs ]; then
            echo "Reached the limit of $max_jobs job submissions."
            break
        fi
        
        echo "Submitting script: $script"
        sbatch "$script"
        
        mv "$script" "$submitted_dir/"
        
        ((counter++))
    fi
done

echo "Submitted $counter CPU job scripts. All moved to '${BUILD_DIR}/submitted'!"

echo "=========================================="
echo "CPU job submission completed successfully!"
echo "=========================================="
echo "Summary:"
echo "  - Executable built: ${BUILD_DIR}/conjugateGradientPrecond"
echo "  - Jobs submitted: $counter"
echo "  - Submitted scripts moved to: ${BUILD_DIR}/submitted/"
echo "  - CPU affinity: ${CPUSET}"
echo "  - Execution mode: parallel with OpenMP"
echo
