# Create a virtual environment
python3 -m venv ../../venv
source ../../venv/bin/activate
pip install ssgetpy
pip install pandas
pip install scipy
pip install numpy
pip install matplotlib
# pip install seaborn
# pip install scikit-learn
# pip install scikit-image
# pip install scikit-image

# Download the matrices
python3 ../../script_src/python_scripts/prep/matrix_download.py

# Execute MATLAB script for matrix sparsification
echo "Running MATLAB matrix sparsification..."
cd ../../script_src/matlab_scripts

# Run MATLAB script with matrix_market directory in path
matlab -batch "addpath('matrix_market'); matrix_sparsification"

echo "Matrix sparsification completed."