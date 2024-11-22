#!/bin/bash

# Set the expected commit SHA
SCRIPT_COMMIT_SHA="712a5f4c646f37c67e9a966112cb8d2641f89ef4"

# Determine the portal folder based on the available paths
if [ -d "/mnt/host/c" ]; then
    portal_folder="/mnt/host/c/Vista/Portal"
elif [ -d "/mnt/c" ]; then
    portal_folder="/mnt/c/Vista/Portal"
else
    portal_folder="/opt/Vista/Portal"
fi

# Ensure the portal folder exists
if [ ! -d "$portal_folder" ]; then
    echo "Creating portal folder: $portal_folder"
    mkdir -p "$portal_folder"
fi

# Define the URLs of the scripts and raw content
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/markm-io/portal_install_script/main/install.sh"
SETUP_SCRIPT_URL="https://raw.githubusercontent.com/markm-io/portal_install_script/main/setup.sh"
COMMIT_CHECK_URL="https://api.github.com/repos/markm-io/portal_install_script/commits/main"
LOCAL_FILE="$portal_folder/install.sh"

echo "Checking the commit SHA of the remote setup.sh script..."
# Fetch the commit SHA of the remote setup.sh
remote_commit_sha=$(curl -s "$COMMIT_CHECK_URL" | grep -oP '(?<="sha": ")[^"]+' | head -1)

# Check if the SHA matches the expected value
if [ "$remote_commit_sha" != "$SCRIPT_COMMIT_SHA" ]; then
    echo "Warning: The remote script's commit SHA does not match the expected value!"
    echo "Expected: $SCRIPT_COMMIT_SHA"
    echo "Found:    $remote_commit_sha"
    echo "Downloading the updated setup.sh script and running it..."

    # Download the new setup.sh script
    updated_setup_file="$portal_folder/setup.sh"
    curl -o "$updated_setup_file" -L "$SETUP_SCRIPT_URL"

    # Check if the download was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download the updated setup.sh from $SETUP_SCRIPT_URL"
        exit 1
    fi

    echo "Making the updated setup.sh executable..."
    chmod +x "$updated_setup_file"

    echo "Running the updated setup.sh script..."
    sudo "$updated_setup_file"
    exit 0
else
    echo "Commit SHA matches. Proceeding with the current script."
fi

echo "Downloading the installation script..."
# Download the installation script
curl -o "$LOCAL_FILE" -L "$INSTALL_SCRIPT_URL"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to download the script from $INSTALL_SCRIPT_URL"
    exit 1
fi

echo "Making the script executable..."
# Make the script executable
chmod +x "$LOCAL_FILE"

echo "Running the script with sudo..."
# Run the script with sudo
sudo "$LOCAL_FILE"

# Display banner to remind user to run the script manually if needed
echo "============================================================"
echo " The script has been saved to: $LOCAL_FILE"
echo " To run it manually, use the command:"
echo ""
echo "   ./$LOCAL_FILE"
echo ""
echo "============================================================"

echo "Setup complete."