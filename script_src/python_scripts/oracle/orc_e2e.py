import pandas as pd
import sys
from scipy.stats import gmean

if len(sys.argv) != 2:
    print("Usage: python select_best_e2e.py [bCaC | bCaX | bXaC]")
    sys.exit(1)

mode = sys.argv[1]
if mode not in {"bCaC", "bCaX", "bXaC"}:
    print("Invalid mode. Choose from: bCaC, bCaX, bXaC")
    sys.exit(1)

# Load CSVs
speedup_df = pd.read_csv("gpu/ilu0_speedups.csv")
raw_df = pd.read_csv("gpu/ilu0_raw.csv")

# Clean and normalize sparsification field name
raw_df = raw_df.rename(columns={"Sparsification Ratio": "Removal Percentage"})

# Set of matrix names in speedup file
matrices_in_speedup = set(speedup_df["Matrix Name"])

# Filter raw_df to only those matrices
raw_df = raw_df[raw_df["Matrix Name"].isin(matrices_in_speedup)]

qualified_matrices = set()

for matrix, group in raw_df.groupby("Matrix Name"):
    has_sp0_under_1000 = ((group["Removal Percentage"] == 0) & (group["Iterations Spent"] < 1000)).any()
    has_spN0_under_1000 = ((group["Removal Percentage"] != 0) & (group["Iterations Spent"] < 1000)).any()

    if mode == "bCaC":
        if has_sp0_under_1000 and has_spN0_under_1000:
            qualified_matrices.add(matrix)
    elif mode == "bCaX":
        if has_sp0_under_1000:
            qualified_matrices.add(matrix)
    elif mode == "bXaC":
        if has_spN0_under_1000:
            qualified_matrices.add(matrix)

# Filter speedup_df
filtered_speedup = speedup_df[speedup_df["Matrix Name"].isin(qualified_matrices)]

# Select best end-to-end speedup per matrix
selected_rows = []
for matrix, group in filtered_speedup.groupby("Matrix Name"):
    best_row = group.loc[group["End-to-end Speedup"].idxmax()]
    selected_rows.append({
        "Matrix Name": matrix,
        "Selected Sparsification Ratio": best_row["Removal Percentage"],
        "Best End-to-end Speedup": best_row["End-to-end Speedup"]
    })

result_df = pd.DataFrame(selected_rows)

# Calculate and print gmean
gmean_value = gmean(result_df["Best End-to-end Speedup"])
print(f"Geometric Mean of Best End-to-end Speedups for {mode}:", gmean_value)

# Export to CSV
output_file = f"oracle_selection_gpu_e2e_{mode}.csv"
result_df.to_csv(output_file, index=False)
