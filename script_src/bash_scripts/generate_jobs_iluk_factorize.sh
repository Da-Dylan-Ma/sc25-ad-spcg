#!/bin/bash

matrices=(
    "1138_bus" "aft01" "bcsstk15" "bcsstk38" "bibd_81_2" "bundle_adj" "ct20stif" "ex3" "gridgena" "mhd3200b" "nasa2146"
    "parabolic_fem" "s2rmq4m1" "shipsec1" "thermal2" "wathen120" "2cubes_sphere" "Andrews" "bcsstk16" "bcsstm08" "bloweybq"
    "cant" "cvxbqp1" "ex33" "gyro" "mhd4800b" "nasa2910" "pdb1HYS" "s2rmt3m1" "shipsec5" "thermomech_dM" "x104" "af_0_k101"
    "apache1" "bcsstk17" "bcsstm09" "bmw7st_1" "cbuckle" "denormal" "ex9" "gyro_k" "minsurfo" "nasa4704" "PFlow_742"
    "s3dkq4m2" "shipsec8" "thermomech_TC" "af_1_k101" "apache2" "bcsstk18" "bcsstm11" "bmwcra_1" "cfd1" "Dubcova1"
    "Fault_639" "gyro_m" "msc01050" "nasasrb" "plat1919" "s3dkt3m2" "smt" "thermomech_TK" "af_2_k101" "audikw_1"
    "bcsstk21" "bcsstm12" "bodyy4" "cfd2" "Dubcova2" "finan512" "hood" "msc01440" "nd12k" "plbuckle" "s3rmq4m1"
    "StocF-1465" "thread" "af_3_k101" "bcsstk08" "bcsstk23" "bcsstm21" "bodyy5" "Chem97ZtZ" "Dubcova3" "Flan_1565"
    "Hook_1498" "msc04515" "nd24k" "Pres_Poisson" "s3rmt3m1" "sts4098" "tmt_sym" "af_4_k101" "bcsstk09" "bcsstk24"
    "bcsstm23" "bodyy6" "consph" "ecology2" "fv1" "inline_1" "msc10848" "nd3k" "pwtk" "s3rmt3m3" "t2dah_e" "torsion1"
    "af_5_k101" "bcsstk10" "bcsstk25" "bcsstm24" "bone010" "crankseg_1" "Emilia_923" "fv2" "jnlbrng1" "msc23052" "nd6k"
    "qa8fm" "Serena" "t2dal_e" "Trefethen_2000" "af_shell3" "bcsstk11" "bcsstk26" "bcsstm25" "boneS01" "crankseg_2"
    "ex10" "fv3" "Kuu" "msdoor" "obstclae" "Queen_4147" "shallow_water1" "t3dl_e" "Trefethen_20000" "af_shell4" "bcsstk12"
    "bcsstk27" "bcsstm26" "boneS10" "crystm01" "ex10hs" "G2_circuit" "ldoor" "m_t1" "offshore" "raefsky4" "shallow_water2"
    "ted_B" "Trefethen_20000b" "af_shell7" "bcsstk13" "bcsstk28" "bcsstm39" "Bump_2911" "crystm02" "ex13" "G3_circuit"
    "LF10000" "nasa1824" "oilpan" "s1rmq4m1" "ship_001" "ted_B_unscaled" "vanbody" "af_shell8" "bcsstk14" "bcsstk36"
    "BenElechi1" "bundle1" "crystm03" "ex15" "Geo_1438" "LFAT5000" "nasa2146" "olafu" "s1rmt3m1" "ship_003" "thermal1"
    "wathen100" "Muu"
)

for matrix in "${matrices[@]}"; do
    script_name="job_submit_${matrix}.sh"
    cat << EOF > $script_name
#!/bin/bash

#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --export=ALL
#SBATCH --job-name="spd_factor_${matrix}"
#SBATCH --nodes=1
#SBATCH --output="spd_fact_timed_${matrix}.%j.%N.out"
#SBATCH -t 23:59:00

module load StdEnv/2020
module load intel/2022.1.0
module load anaconda3/2021.05

python factorize.py /scratch/k/kazem/dama/data_analysis/matrix/${matrix}/${matrix}.mtx
EOF

    # Make the script executable
    chmod +x $script_name
done

echo "Bash scripts generated successfully"
