#!/bin/bash

# Directory containing the job scripts
script_dir="."
submitted_dir="$script_dir/submitted"

# Create a directory called "submitted" if it doesn't exist
mkdir -p "$submitted_dir"

# Initialize counter for job submissions
counter=0
max_jobs=100

# Find all job_submit_<matrix name>.sh files and submit them with sbatch
for script in "$script_dir"/job_submit_*.sh; do
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
done

echo "Submitted $counter job scripts. All moved to '$submitted_dir'!"
