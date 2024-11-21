#!/bin/bash

# Update package lists
echo "Updating package lists..."
sudo apt-get update -y

# Check if Git is installed
if dpkg -l | grep -q "^ii.*git"; then
    echo "Git is already installed."
else
    echo "Git is not installed. Installing Git..."
    sudo apt-get install git -y
fi

# Check if Docker is installed
if dpkg -l | grep -q "^ii.*docker"; then
    echo "Docker is installed."

    # Check if Docker is active
    if systemctl is-active --quiet docker; then
        echo "Docker is already running."
    else
        echo "Docker is installed but not running. Starting Docker..."
        sudo systemctl start docker
        sudo systemctl enable docker
        echo "Docker has been started and enabled to run at boot."
    fi
else
    echo "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Determine folder locations
postgres_folder=""
portal_folder=""

if [ -d "/mnt/host/c" ]; then
    postgres_folder="/mnt/host/c/Vista/Postgres"
    portal_folder="/mnt/host/c/Vista/Portal"
elif [ -d "/mnt/c" ]; then
    postgres_folder="/mnt/c/Vista/Postgres"
    portal_folder="/mnt/c/Vista/Portal"
else
    postgres_folder="/opt/Vista/Postgres"
    portal_folder="/opt/Vista/Portal"
fi

# Create necessary folders if they don't exist
mkdir -p "$postgres_folder"
mkdir -p "$portal_folder"

# Check for existing PostgreSQL installation
if [ -f "$postgres_folder/postgres_database_password.txt" ]; then
    echo "Previous Postgres Installation Detected. Skipping Installation."
else
    # Ask if the user wants to set up a PostgreSQL database
    read -p "Would you like to set up a PostgreSQL database to write data to? (y/n): " setup_db

    if [[ "$setup_db" == "y" || "$setup_db" == "Y" ]]; then
        # Ask for external port with default 5432
        read -p "Enter the external port for PostgreSQL (default: 5432): " db_port
        db_port=${db_port:-5432}

        # Generate a strong 32-character password
        db_password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
        echo "Generated a strong password for PostgreSQL: $db_password"

        # Save the password to the appropriate folder
        echo "$db_password" > "$postgres_folder/postgres_database_password.txt"
        echo "PostgreSQL password saved to $postgres_folder/postgres_database_password.txt"

        echo "Creating docker-compose.yaml file for PostgreSQL..."

        # Create the docker-compose.yaml file
        cat <<EOF > docker-compose.yaml
services:
  db:
    image: postgres:16-alpine
    ports:
      - ${db_port}:5432
    volumes:
      - ./volumes/db/data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=${db_password}
      - POSTGRES_DB=postgres
      - POSTGRES_USER=postgres
    restart: unless-stopped
networks: {}
EOF

        echo "docker-compose.yaml file created successfully."

        # Optional: Ask if the user wants to start the container
        read -p "Would you like to start the PostgreSQL container now? (y/n): " start_now
        if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
            sudo docker-compose up -d
            echo "PostgreSQL container started."
        else
            echo "You can start the PostgreSQL container later using 'docker-compose up -d'."
        fi
    else
        echo "PostgreSQL setup skipped."
    fi
fi

# Check for existing Portal installation
if [ -f "$portal_folder/docker-compose.yaml" ]; then
    echo "Previous Portal Installation Detected."
    read -p "Would you like to update the Portal installation? (y/n): " update_portal

    if [[ "$update_portal" == "y" || "$update_portal" == "Y" ]]; then
        echo "Updating the Portal..."
        cd "$portal_folder"
        git pull
        sudo docker-compose up -d
        echo "Portal updated successfully."
    else
        echo "Portal update skipped."
    fi
else
    echo "No previous Portal installation detected. Cloning the Portal repository..."
    git clone https://github.com/markm-io/SecureHST_Superset_Repo.git "$portal_folder"
    echo "Portal repository cloned successfully."

    # Ask for the business name
    read -p "Enter the name of the business (no special characters): " business_name

    # Generate the SECRET_KEY
    secret_key=$(openssl rand -base64 42)

    # Generate a strong 32-character password
    portal_password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)

    # Update the config/.env-superset file
    env_file="$portal_folder/config/.env-superset"
    if [ -f "$env_file" ]; then
        sed -i "s/^APP_NAME=.*/APP_NAME=${business_name}/" "$env_file"
        sed -i "s/^LOGO_RIGHT_TEXT=.*/LOGO_RIGHT_TEXT=${business_name}/" "$env_file"
        sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${secret_key}/" "$env_file"
        sed -i "s/^DATABASE_PASSWORD=.*/DATABASE_PASSWORD=${portal_password}/" "$env_file"
        sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${portal_password}/" "$env_file"
        echo "Configuration updated in $env_file."
    else
        echo "Error: $env_file not found."
    fi
fi

echo "Script execution completed."