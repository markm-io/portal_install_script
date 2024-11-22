#!/bin/bash

SCRIPT_COMMIT_SHA="default_value"

# Determine the portal folder based on the available paths
if [ -d "/mnt/host/c" ]; then
    vista_folder="/mnt/host/c/Vista"
elif [ -d "/mnt/c" ]; then
    vista_folder="/mnt/c/Vista"
else
    vista_folder="/opt/Vista"
fi

# Ensure the portal folder exists
if [ ! -d "$vista_folder" ]; then
    echo "Creating portal folder: $vista_folder"
    mkdir -p "$vista_folder"
fi

# Define the URL of the script to be downloaded
SCRIPT_URL="https://raw.githubusercontent.com/markm-io/portal_install_script/main/install.sh"
LOCAL_FILE="$vista_folder/install.sh"

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

# echo "Running the script with sudo..."
# Run the script with sudo
# sudo "$LOCAL_FILE"

# Display banner to remind user to run the script manually if needed
echo "============================================================"
echo " The script has been saved to: $LOCAL_FILE"
echo " Run it with the command:"
echo ""
echo "   .$LOCAL_FILE"
echo ""
echo "============================================================"

# Cleanup (optional, comment out if you want to keep the script)
# echo "Cleaning up..."
# rm -f "$LOCAL_FILE"

echo "Setup complete."