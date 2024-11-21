#!/bin/bash

# Update package lists
echo "Updating package lists..."
sudo apt-get update -y

# Check if Git is installed
if ! command -v git &> /dev/null
then
    echo "Git is not installed. Installing Git..."
    sudo apt-get install git -y
else
    echo "Git is already installed. Updating Git..."
    sudo apt-get install --only-upgrade git -y
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
else
    echo "Docker is already installed."
fi

# Check if /mnt/host/c or /mnt/c exists
if [ -d "/mnt/host/c" ] || [ -d "/mnt/c" ]; then
    echo "Either /mnt/host/c or /mnt/c exists. Creating required folders..."
    mkdir -p /mnt/host/c/Vista/Portal 2>/dev/null
    mkdir -p /mnt/host/c/Vista/Postgres 2>/dev/null
    mkdir -p /mnt/c/Vista/Portal 2>/dev/null
    mkdir -p /mnt/c/Vista/Postgres 2>/dev/null
else
    echo "Neither /mnt/host/c nor /mnt/c exists. Creating folders in /opt instead..."
    sudo mkdir -p /opt/Vista/Portal
    sudo mkdir -p /opt/Vista/Postgres
fi

echo "Script execution completed."