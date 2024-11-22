#!/bin/sh

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
sudo mkdir -p "$postgres_folder"
sudo mkdir -p "$portal_folder"

# Check for existing PostgreSQL installation
if [ -f "$postgres_folder/postgres_database_password.txt" ]; then
    echo "Previous Postgres Installation Detected. Skipping Installation."
else
    # Ask if the user wants to set up a PostgreSQL database
    echo "Would you like to set up a PostgreSQL database to write data to? (y/n): "
    read setup_db

    if [ "$setup_db" = "y" ] || [ "$setup_db" = "Y" ]; then
        # Ask for external port with default 5432
        echo "Enter the external port for PostgreSQL (default: 5432): "
        read db_port
        db_port=${db_port:-5432}

        # Generate a strong 32-character password
        db_password=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 32)
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
        echo "Would you like to start the PostgreSQL container now? (y/n): "
        read start_now
        if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
            sudo docker compose up -d
            echo "PostgreSQL container started."
        else
            echo "You can start the PostgreSQL container later using 'docker compose up -d'."
        fi
    else
        echo "PostgreSQL setup skipped."
    fi
fi

# Ask if the user wants to set up the dashboard port
echo "Would you like to set up the dashboard port? (y/n): "
read setup_dashboard_port

if [ "$setup_dashboard_port" = "y" ] || [ "$setup_dashboard_port" = "Y" ]; then
    # Check for existing Portal installation
    if [ -f "$portal_folder/config/.env-superset" ]; then
        echo "Previous Portal Installation Detected."
        echo "Would you like to update the Portal installation? (y/n): "
        read update_portal

        if [ "$update_portal" = "y" ] || [ "$update_portal" = "Y" ]; then
            echo "Updating the Portal..."
            cd "$portal_folder"
            git pull
            echo "Portal updated successfully."
        else
            echo "Portal update skipped."
        fi
    else
        echo "No previous Portal installation detected. Cloning the Portal repository..."
        git clone https://github.com/markm-io/SecureHST_Superset_Repo.git "$portal_folder"
        echo "Portal repository cloned successfully."

        # Create the .env-superset file with default values
        env_file="$portal_folder/config/.env-superset"
        sudo mkdir -p "$portal_folder/config"
        cat <<EOF > "$env_file"
# Superset Database Variables
DATABASE_DIALECT=postgresql+psycopg2
DATABASE_USER=superset
DATABASE_PASSWORD=change_me
DATABASE_HOST=db
DATABASE_PORT=5432
DATABASE_DB=superset

# Postgres Database Variables
POSTGRES_DB=superset
POSTGRES_USER=superset
POSTGRES_PASSWORD=change_me

# Superset Configuration
APP_NAME=Superset
LOGO_RIGHT_TEXT=SecureHST
SECRET_KEY=change_me_secret_key
SUPERSET_ENV=production
FLASK_DEBUG=false
SUPERSET_LOAD_EXAMPLES=no

# SMTP Configuration
SMTP_MAIL_FROM=
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASSWORD=
EOF
        echo "$env_file created with default values."

        # Ask for the business name
        echo "Enter the name of the business (no special characters): "
        read business_name

        # Generate the SECRET_KEY
        secret_key=$(openssl rand -base64 42)

        # Generate a strong 32-character password
        portal_password=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 32)

        # Update the .env-superset file with user-provided details
        sudo sed -i "s/^APP_NAME=.*/APP_NAME=${business_name}/" "$env_file"
        sudo sed -i "s/^LOGO_RIGHT_TEXT=.*/LOGO_RIGHT_TEXT=${business_name}/" "$env_file"
        sudo sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${secret_key}/" "$env_file"
        sudo sed -i "s/^DATABASE_PASSWORD=.*/DATABASE_PASSWORD=${portal_password}/" "$env_file"
        sudo sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${portal_password}/" "$env_file"
        echo "Configuration updated in $env_file."

        # Ask to set up SMTP settings
        echo "Would you like to set up SMTP settings for sending emails/reports? (y/n): "
        read setup_smtp

        if [ "$setup_smtp" = "y" ] || [ "$setup_smtp" = "Y" ]; then
            echo "Enter the SMTP Host (e.g., smtp.gmail.com): "
            read smtp_host
            echo "Enter the SMTP Mail From (e.g., mail@example.com): "
            read smtp_mail_from
            echo "Enter the SMTP User (e.g., mail@example.com): "
            read smtp_user
            echo "Enter the SMTP Password (hidden): "
            read -s smtp_password
            echo "Enter the SMTP Port (default: 587): "
            read smtp_port
            smtp_port=${smtp_port:-587}

            # Append SMTP settings to the .env-superset file
            echo "SMTP_HOST=$smtp_host" | sudo tee -a "$env_file"
            echo "SMTP_MAIL_FROM=$smtp_mail_from" | sudo tee -a "$env_file"
            echo "SMTP_USER=$smtp_user" | sudo tee -a "$env_file"
            echo "SMTP_PASSWORD=$smtp_password" | sudo tee -a "$env_file"
            echo "SMTP_PORT=$smtp_port" | sudo tee -a "$env_file"
            echo "SMTP settings have been updated in $env_file."
        else
            echo "SMTP setup skipped. Emails/reports may not be sent."
        fi
    fi

    # Ask if the user wants to start the Portal
    echo "Would you like to start the Portal? (y/n): "
    read start_portal

    if [ "$start_portal" = "y" ] || [ "$start_portal" = "Y" ]; then
        echo "Starting the Portal..."
        cd "$portal_folder"
        sudo docker compose up -d
        echo "Portal started successfully."
    else
        echo "Portal start skipped. You can start it later using 'docker compose up -d' in the Portal folder."
    fi
else
    echo "Dashboard setup skipped."
fi

echo "Script execution completed."