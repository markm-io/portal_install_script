#!/bin/bash

# Determine the portal folder based on the available paths
if [ -d "/mnt/host/c" ]; then
    postgres_folder="/mnt/host/c/Vista/Portal"
elif [ -d "/mnt/c" ]; then
    postgres_folder="/mnt/c/Vista/Portal"
else
    postgres_folder="/opt/Vista/Portal"
fi

# Ensure the portal folder exists
if [ ! -d "$postgres_folder" ]; then
    echo "Creating portal folder: $postgres_folder"
    mkdir -p "$postgres_folder"
fi

# Define the URL of the script to be downloaded
SCRIPT_URL="https://raw.githubusercontent.com/markm-io/portal_install_script/main/install.sh"
LOCAL_FILE="$postgres_folder/install.sh"

echo "Downloading the installation script..."
# Download the script
curl -o "$LOCAL_FILE" -L "$SCRIPT_URL"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to download the script from $SCRIPT_URL"
    exit 1
fi

echo "Making the script executable..."
# Make the script executable
chmod +x "$LOCAL_FILE"

echo "Running the script with sudo..."
# Run the script with sudo
sudo "$LOCAL_FILE"

# Cleanup (optional, comment out if you want to keep the script)
# echo "Cleaning up..."
# rm -f "$LOCAL_FILE"

echo "Setup complete."