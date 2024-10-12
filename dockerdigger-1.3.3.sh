#!/bin/bash

# Check if the correct number of arguments is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <search_string> [--download] [--single-dir <directory>]"
    exit 1
fi

# Capture the search string
search_string=$1
shift  # Shift to process flags

download_files=false
single_dir=false
download_dir="/home/dockerdigger"

# Process flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --download) download_files=true ;;
        --single-dir) 
            single_dir=true
            shift
            if [[ -n "$1" ]]; then
                target_dir="$1"
                mkdir -p "$target_dir"
            else
                echo "Error: --single-dir requires a directory name."
                exit 1
            fi
            ;;
        *) 
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
    shift
done

# Create the main download directory if it doesn't exist
mkdir -p "$download_dir"

# Get all container IDs
container_ids=$(docker ps -aq)

# Loop through each container ID
for container_id in $container_ids; do
    echo "Searching in container: $container_id"
    
    # Use grep to find matching files, excluding .bash_history
    matching_files=$(sudo docker exec "$container_id" grep -rl --exclude-dir=dev --exclude-dir=sys --exclude-dir=proc --exclude=".bash_history" "$search_string" /)

    # Check if there are any matching files
    if [ -n "$matching_files" ]; then
        echo "Found matching files in container $container_id:"
        echo "$matching_files"
        
        if [ "$download_files" = true ]; then
            if [ "$single_dir" = true ]; then
                # Download all matching files to the specified single directory
                for file in $matching_files; do
                    echo "Downloading $file from container $container_id to $target_dir..."
                    sudo docker cp "$container_id:$file" "$target_dir/"
                done
            else
                # Create a directory for downloads specific to the container and search string
                container_download_dir="$download_dir/$container_id/$search_string"
                mkdir -p "$container_download_dir"

                # Download each matching file to the container-specific directory
                for file in $matching_files; do
                    echo "Downloading $file from container $container_id..."
                    sudo docker cp "$container_id:$file" "$container_download_dir/"
                done
            fi
        fi
    else
        echo "No matching files found in container $container_id."
    fi
done