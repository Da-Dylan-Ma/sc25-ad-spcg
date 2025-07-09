#!/bin/bash

# GPU ILU0 Compilation Script
# This script compiles both the nonsp and sp versions of the ILU0 GPU implementation

echo "Starting GPU ILU0 compilation..."

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

# Generate job submission scripts
echo "=========================================="
echo "Generating job submission scripts..."
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

# Function to generate job scripts for a specific directory
generate_job_scripts() {
    local dir_name=$1
    local build_path="${BASE_DIR}/${dir_name}/build"
    
    echo "Generating job scripts for ${dir_name}..."
    
    # Navigate to the build directory
    cd "${build_path}"
    
    # Loop through each matrix and generate the corresponding bash script
    for matrix in "${matrices[@]}"; do
        script_name="job_submit_${matrix}.sh"
        
        # Generate different script content based on directory type
        if [ "$dir_name" = "nonsp" ]; then
            # For nonsp: no sparsification ratio needed
            cat << EOF > $script_name
#!/bin/bash

#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --export=ALL
#SBATCH --job-name="ilu0_${dir_name}_${matrix}"
#SBATCH --nodes=1
#SBATCH --output="ilu0_${dir_name}_${matrix}.%j.%N.out"
#SBATCH -t 11:59:00

module load StdEnv/2020
module load intel/2022.1.0
module load anaconda3/2021.05

# Matrix file path
matrix_file="${MATRIX_DIR}/${matrix}/${matrix}.mtx"

# Check if matrix file exists
if [ -f "\$matrix_file" ]; then
    echo "Processing matrix: \$matrix_file"
    ./conjugateGradientPrecond "\$matrix_file"
else
    echo "Matrix file not found: \$matrix_file"
fi
EOF
        else
            # For sp: use sparsification ratios
            cat << EOF > $script_name
#!/bin/bash

#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --export=ALL
#SBATCH --job-name="ilu0_${dir_name}_${matrix}"
#SBATCH --nodes=1
#SBATCH --output="ilu0_${dir_name}_${matrix}.%j.%N.out"
#SBATCH -t 11:59:00

module load StdEnv/2020
module load intel/2022.1.0
module load anaconda3/2021.05

# Matrix file path
matrix_file="${MATRIX_DIR}/${matrix}/${matrix}.mtx"

# Check if matrix file exists
if [ -f "\$matrix_file" ]; then
    echo "Processing matrix: \$matrix_file"
    ./conjugateGradientPrecond "\$matrix_file" 0.01
    ./conjugateGradientPrecond "\$matrix_file" 0.05
    ./conjugateGradientPrecond "\$matrix_file" 0.1
else
    echo "Matrix file not found: \$matrix_file"
fi
EOF
        fi

        # Make the script executable
        chmod +x $script_name
    done
    
    echo "Generated ${#matrices[@]} job scripts in ${build_path}"
    
    # Return to original directory
    cd - > /dev/null
}

# Generate job scripts for both nonsp and sp versions
generate_job_scripts "nonsp"
generate_job_scripts "sp"

echo "=========================================="
echo "Job script generation completed successfully!"
echo "=========================================="
echo "Job scripts created in:"
echo "  - nonsp: ${BASE_DIR}/nonsp/build/job_submit_*.sh"
echo "  - sp:    ${BASE_DIR}/sp/build/job_submit_*.sh"
echo "Total: ${#matrices[@]} job scripts per directory"
echo

# Submit job scripts
echo "=========================================="
echo "Submitting job scripts..."
echo "=========================================="

# Function to submit job scripts for a specific directory
submit_job_scripts() {
    local dir_name=$1
    local build_path="${BASE_DIR}/${dir_name}/build"
    
    echo "Submitting job scripts for ${dir_name}..."
    
    # Navigate to the build directory
    cd "${build_path}"
    
    # Create a directory called "submitted" if it doesn't exist
    local submitted_dir="./submitted"
    mkdir -p "$submitted_dir"
    
    # Initialize counter for job submissions
    local counter=0
    local max_jobs=200
    
    # Find all job_submit_*.sh files and submit them with sbatch
    for script in ./job_submit_*.sh; do
        if [ -f "$script" ]; then
            if [ $counter -ge $max_jobs ]; then
                echo "Reached the limit of $max_jobs job submissions for ${dir_name}."
                break
            fi
            
            echo "Submitting script: $script"
            sbatch "$script"
            
            # Move the submitted script to the "submitted" directory
            mv "$script" "$submitted_dir/"
            
            # Increment the counter
            ((counter++))
        fi
    done
    
    echo "Submitted $counter job scripts for ${dir_name}. All moved to '${build_path}/submitted'!"
    
    # Return to original directory
    cd - > /dev/null
    
    return $counter
}

# Submit job scripts for both nonsp and sp versions
submit_job_scripts "nonsp"
nonsp_count=$?

submit_job_scripts "sp"
sp_count=$?

total_submitted=$((nonsp_count + sp_count))

echo "=========================================="
echo "Job submission completed successfully!"
echo "=========================================="
echo "Total jobs submitted:"
echo "  - nonsp: $nonsp_count jobs"
echo "  - sp:    $sp_count jobs"
echo "  - Total: $total_submitted jobs"
echo
echo "Submitted scripts moved to:"
echo "  - nonsp: ${BASE_DIR}/nonsp/build/submitted/"
echo "  - sp:    ${BASE_DIR}/sp/build/submitted/"
echo
