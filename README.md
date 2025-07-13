# SPCG Artifact Reproduction Pipeline

This artifact contains the complete pipeline for evaluating sparse matrix computation algorithms on GPU and CPU platforms.

## Prerequisites

Download the Singularity container from Zenodo and refer to the AD description:
```
https://zenodo.org/records/15285967
```

## Execution Instructions

All scripts are SLURM scripts to submit jobs to cluster. To run the complete artifact pipeline, navigate to the `artifact_execution` directory and execute the tasks T1 through T5 **strictly in sequence**:

```bash
cd artifact_execution
```

### Task Execution Order

**Important**: Each task must be completed before proceeding to the next. Do not run tasks in parallel or out of order.

1. **T1 - Data Preparation**
   ```bash
   cd T1
   ./run_preparation.sh
   cd ..
   ```

2. **T2 - GPU Computations**
   ```bash
   cd T2
   ./run_gpu_iluk.sh
   cd ..
   ```

3. **T3 - Results Collection**
   ```bash
   cd T3
   ./collect_results.sh
   cd ..
   ```

4. **T4 - Matrix Properties**
   ```bash
   cd T4
   ./compute_properties.sh
   cd ..
   ```

5. **T5 - Algorithm Analysis**
   ```bash
   cd T5
   ./analyze_ilu0_results.sh
   ./analyze_iluk_results.sh
   ./analyze_cpu_results.sh
   ```

## Output

Results and visualizations will be generated in the `results/` directory. Intermediate raw data will be saved in the `logs/` directory. The T5 analysis produces performance tables, correlation plots, histograms, and application-specific analysis charts.

## Notes

- Ensure each task completes successfully before proceeding to the next
- Task T(x) must be executed after the completion of task T(x-1)
- Total execution time may vary depending on system specifications 