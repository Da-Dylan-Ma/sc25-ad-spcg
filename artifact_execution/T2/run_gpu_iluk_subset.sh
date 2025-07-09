#!/bin/bash

# GPU ILUK Compilation Script

echo "Starting GPU ILUK compilation..."

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
    cd - > /dev/null
    
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

# Generate job submission scripts for scipy factorization
echo "=========================================="
echo "Generating job submission scripts for scipy factorization..."
echo "=========================================="

matrices=(
    "Chem97ZtZ" "1138_bus" "Dubcova2" "Dubcova3" "G2_circuit" "Kuu" "LF10000" "LFAT5000" 
    "Muu" "Pres_Poisson" "aft01" "apache1" "bcsstk08" "bcsstk09" "bcsstk10" "bcsstk11" 
    "bcsstk12" "bcsstk13" "bcsstk14" "bcsstk15" "bcsstk16" "bcsstk17" "bcsstk18" "bcsstk21" 
    "bcsstk23" "bcsstk25" "bcsstk26" "bcsstk27" "bcsstk28" "bcsstk36" "bcsstk38" "bcsstm08" 
    "bcsstm09" "1138_bus" "bcsstm12" "bcsstm21" "bcsstm23" "bcsstm24" "bcsstm25" "bcsstm26" 
    "bcsstm39" "bloweybq" "bodyy4" "bodyy5" "bodyy6" "bundle1" "cant" "cbuckle" "cfd1" "crystm01" 
    "crystm02" "crystm03" "ct20stif" "cvxbqp1" "denormal" "ex10" "ex10hs" "ex13" "ex15" "ex3" "ex33" 
    "finan512" "fv1" "fv2" "fv3" "gridgena" "gyro" "gyro_k" "gyro_m" "jnlbrng1" "mhd3200b" "mhd4800b" 
    "minsurfo" "msc01050" "msc01440" "msc04515" "msc10848" "msc23052" "nasa1824" "nasa2146" "nasa2910" 
    "nasa4704" "nasasrb" "nd3k" "obstclae" "olafu" "parabolic_fem" "plat1919" "plbuckle" "qa8fm" 
    "raefsky4" "s1rmq4m1" "s1rmt3m1" "s2rmq4m1" "s2rmt3m1" "s3rmq4m1" "s3rmt3m1" "s3rmt3m3" 
    "shallow_water1" "shallow_water2" "sts4098" "t2dah_e" "t2dal_e" "t3dl_e" "ted_B" "ted_B_unscaled" 
    "thermal1" "thermomech_TC" "thermomech_TK" "thermomech_dM" "torsion1" "vanbody" "wathen100" "wathen120"
)

# Create job scripts for scipy factorization
cd "${BASE_DIR}/../../script_src/python_scripts/prep/iluk_factorization"

# Test run with a single matrix to verify directory structure
echo "Testing with 1138_bus matrix..."
FULL_MATRIX_PATH="${PWD}/../../../../matrices/1138_bus/1138_bus.mtx"
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

for matrix in "${matrices[@]}"; do
    script_name="job_submit_scipy_${matrix}.sh"
    cat << EOF > $script_name
#!/bin/bash

#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --export=ALL
#SBATCH --job-name="scipy_factor_${matrix}"
#SBATCH --nodes=1
#SBATCH --output="scipy_fact_${matrix}.%j.%N.out"
#SBATCH -t 23:59:00

module load StdEnv/2020
module load intel/2022.1.0
module load anaconda3/2021.05

python3 iluk_factorize.py ../../../../matrices/${matrix}/${matrix}.mtx
EOF

    # Make the script executable
    chmod +x $script_name
done

echo "Generated ${#matrices[@]} job scripts for scipy factorization"
echo "Current directory: $(pwd)"
echo "SciPy job scripts generated in: $(pwd)"
echo "SciPy job script names: job_submit_scipy_*.sh"

# Submit scipy factorization job scripts
echo "Submitting scipy factorization job scripts..."

# Create submitted directory
submitted_dir="./submitted"
mkdir -p "$submitted_dir"

# Initialize counter
count=0
max_jobs=200

# Submit scipy job scripts
for script in ./job_submit_scipy_*.sh; do
    if [ -f "$script" ] && [ $count -lt $max_jobs ]; then
        echo "Submitting script: $script"
        sbatch "$script"
        
        # Move the submitted script to the 'submitted' directory
        mv "$script" "$submitted_dir"
        echo "Moved script to: $submitted_dir"
        
        ((count++))
    elif [ $count -ge $max_jobs ]; then
        echo "Reached the limit of $max_jobs job submissions."
        break
    fi
done

echo "Submitted $count scipy factorization job scripts and moved them to $submitted_dir."

# Organize the generated factors
FACTORS_DIR="../../../../factors"
if [ -d "$FACTORS_DIR" ]; then
    cd "$FACTORS_DIR"
    
    for l_file in *_l_*.mtx; do
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
              
              # Create descriptive directory name (skip sp_flag since it's redundant with sparse_flag)
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

# Generate job submission scripts for GPU ILUK
echo "=========================================="
echo "Generating GPU ILUK job submission scripts..."
echo "=========================================="

# Function to generate job scripts for ILUK (assumes we're already in the correct directory)
generate_iluk_job_scripts() {
    echo "Generating ILUK job scripts in: $(pwd)"
    
    # Loop through each matrix and generate the corresponding bash script
    for matrix in "${matrices[@]}"; do
        script_name="job_submit_gpu_${matrix}.sh"
        
        cat << EOF > $script_name
#!/bin/bash

#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --export=ALL
#SBATCH --job-name="gpu_iluk_${matrix}"
#SBATCH --nodes=1
#SBATCH --output="gpu_iluk_${matrix}.%j.%N.out"
#SBATCH -t 11:59:00

module load StdEnv/2020
module load intel/2022.1.0
module load anaconda3/2021.05

# Matrix file path (from gpu_src/iluk_gpu/build to artifact/matrices)
matrix_file="../../../matrices/${matrix}/${matrix}.mtx"
factors_dir="../../../factors"

# Check if matrix file exists
if [ ! -f "\$matrix_file" ]; then
    echo "Matrix file not found: \$matrix_file"
    exit 1
fi

echo "Processing matrix: \$matrix_file"

# Find all factor directories for this matrix
if [ ! -d "\$factors_dir" ]; then
    echo "Factors directory not found: \$factors_dir"
    exit 1
fi

# Look for directories that start with the matrix name
for factor_dir in \$factors_dir/${matrix}_*; do
    if [ -d "\$factor_dir" ]; then
        echo "Processing factor directory: \$factor_dir"
        
        # Find L and U factor files in this directory
        l_factor=\$(find "\$factor_dir" -name "*_l_*.mtx" | head -1)
        u_factor=\$(find "\$factor_dir" -name "*_u_*.mtx" | head -1)
        
        if [ -f "\$l_factor" ] && [ -f "\$u_factor" ]; then
            echo "Running: ./conjugateGradientPrecond \$matrix_file \$l_factor \$u_factor"
            ./conjugateGradientPrecond "\$matrix_file" "\$l_factor" "\$u_factor"
        else
            echo "Warning: Could not find L and/or U factor files in \$factor_dir"
            echo "L factor: \$l_factor"
            echo "U factor: \$u_factor"
        fi
    fi
done

echo "Completed processing all factor combinations for ${matrix}"
EOF

        # Make the script executable
        chmod +x $script_name
    done
    
    echo "Generated ${#matrices[@]} GPU ILUK job scripts"
    echo "GPU job script names: job_submit_gpu_*.sh"
}

# Navigate to GPU build directory and generate ILUK job scripts
# From iluk_factorization/ we need to go: ../ -> prep/, ../ -> python_scripts/, ../ -> script_src/, ../ -> artifact/, gpu_src/iluk_gpu/
adjusted_base_dir="../../../../gpu_src/iluk_gpu"
build_path="${adjusted_base_dir}/build"

echo "Current directory before navigation: $(pwd)"
echo "Target build path: ${build_path}"

if [ -d "${build_path}" ]; then
    cd "${build_path}"
    echo "Successfully navigated to: $(pwd)"
    
    # Generate ILUK job scripts
    generate_iluk_job_scripts
    
    # Return to original directory
    cd - > /dev/null
    echo "Returned to: $(pwd)"
else
    echo "Error: Build directory ${build_path} does not exist!"
    echo "Skipping GPU job script generation."
fi

echo "=========================================="
echo "ILUK job script generation completed successfully!"
echo "=========================================="
echo "Job scripts created in: ${build_path}/job_submit_gpu_*.sh"
echo "Total: ${#matrices[@]} job scripts"
echo

# Submit ILUK job scripts
echo "=========================================="
echo "Submitting ILUK job scripts..."
echo "=========================================="

# Function to submit ILUK job scripts (assumes we're already in the correct directory)
submit_iluk_job_scripts() {
    echo "Submitting ILUK job scripts from: $(pwd)"
    
    # Create a directory called "submitted" if it doesn't exist
    local submitted_dir="./submitted"
    mkdir -p "$submitted_dir"
    
    # Initialize counter for job submissions
    local counter=0
    local max_jobs=200
    
    # Find all job_submit_gpu_*.sh files and submit them with sbatch
    for script in ./job_submit_gpu_*.sh; do
        if [ -f "$script" ]; then
            if [ $counter -ge $max_jobs ]; then
                echo "Reached the limit of $max_jobs job submissions."
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
    
    echo "Submitted $counter ILUK job scripts. All moved to './submitted'!"
    
    return $counter
}

# Navigate to GPU build directory and submit ILUK job scripts
echo "Current directory before navigation for submission: $(pwd)"
echo "Target build path for submission: ${build_path}"

if [ -d "${build_path}" ]; then
    cd "${build_path}"
    echo "Successfully navigated to: $(pwd)"
    
    # Submit ILUK job scripts
    submit_iluk_job_scripts
    iluk_count=$?
    
    # Return to original directory
    cd - > /dev/null
    echo "Returned to: $(pwd)"
else
    echo "Error: Build directory ${build_path} does not exist!"
    echo "Skipping GPU job script submission."
    iluk_count=0
fi
# iluk_count=0

echo "=========================================="
echo "Job submission completed successfully!"
echo "=========================================="
echo "Total ILUK jobs submitted: $iluk_count"
echo
echo "Submitted scripts moved to: ${build_path}/submitted/"
echo
