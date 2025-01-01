#!/bin/bash

# Loop through all subdirectories in the echidna folder
for dir in echidna/*/ ; do
    if [ -d "$dir" ]; then
        echo "Running Echidna tests in $dir"
        # Find all matching test-*.sol files in the current directory
        for test_file in "$dir"test-*.sol; do
            # Check if the file exists (in case the glob doesn't match any files)
            if [ -f "$test_file" ]; then
                echidna-test "$test_file" --config "${dir}config.yaml"
            else
                echo "No test files found in $dir"
            fi
        done
    fi
done
