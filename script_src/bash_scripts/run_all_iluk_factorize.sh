#!/bin/bash

# Directory containing the job scripts
script_dir="."
submitted_dir="./submitted"

# Create the submitted directory if it doesn't exist
if [ ! -d "$submitted_dir" ]; then
    mkdir -p "$submitted_dir"
    echo "Created directory: $submitted_dir"
fi

# Initialize a counter
count=0

# Find all job_submit_<matrix name>.sh files and submit up to 50 with sbatch
for script in "$script_dir"/job_submit_*.sh; do
    if [ $count -lt 80 ]; then
        echo "Submitting script: $script"
        sbatch "$script"
        
        # Move the submitted script to the 'submitted' directory
        mv "$script" "$submitted_dir"
        echo "Moved script to: $submitted_dir"
        
        ((count++))
    else
        echo "Reached the limit of 80 job submissions."
        break
    fi
done

echo "Submitted $count job scripts and moved them to $submitted_dir."
