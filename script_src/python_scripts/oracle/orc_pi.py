import pandas as pd
from scipy.stats import gmean

# Load the speedup CSV
df = pd.read_csv("gpu/ilu0_speedups.csv")

# Group by matrix name
grouped = df.groupby("Matrix Name")

selected_rows = []

for matrix, group in grouped:
    best_row = group.loc[group["Per-iteration Speedup"].idxmax()]
    selected_rows.append({
        "Matrix Name": matrix,
        "Selected Sparsification Ratio": best_row["Removal Percentage"],
        "Best Per-iteration Speedup": best_row["Per-iteration Speedup"]
    })

# Create DataFrame
result_df = pd.DataFrame(selected_rows)

# Calculate and print gmean
gmean_value = gmean(result_df["Best Per-iteration Speedup"])
print("Geometric Mean of Best Per-iteration Speedups:", gmean_value)

# Export to CSV
result_df.to_csv("oracle_selection_gpu_pi.csv", index=False)
