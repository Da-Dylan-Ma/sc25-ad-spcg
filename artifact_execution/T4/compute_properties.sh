# Execute MATLAB script for computations
echo "Running MATLAB matrix property computations..."
cd ../../script_src/matlab_scripts

# Run MATLAB script with matrix_market directory in path
matlab -batch "addpath('matrix_market'); matrix_sparsification_analysis"

echo "Matrix property computation completed."
