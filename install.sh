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
    echo "Would you like to set up a PostgreSQL database to write data to? (y/n): "
    read setup_db

    if [ "$setup_db" = "y" ] || [ "$setup_db" = "Y" ]; then
        echo "Enter the external port for PostgreSQL (default: 5432): "
        read db_port
        db_port=${db_port:-5432}

        db_password=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 32)
        echo "$db_password" > "$postgres_folder/postgres_database_password.txt"
        echo "Creating docker-compose.yaml file for PostgreSQL..."
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
        echo "Would you like to start the PostgreSQL container now? (y/n): "
        read start_now
        if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
            sudo docker compose up -d
            echo "PostgreSQL container started."
        fi
    fi
fi

echo "Would you like to set up the dashboard port? (y/n): "
read setup_dashboard_port

if [ "$setup_dashboard_port" = "y" ] || [ "$setup_dashboard_port" = "Y" ]; then
    if ! docker network ls | grep -q "traefik_net"; then
        echo "Creating Docker network traefik_net..."
        sudo docker network create traefik_net
    fi

    if [ -f "$portal_folder/config/.env-superset" ]; then
        echo "Previous Portal Installation Detected."
        echo "Would you like to update the Portal installation? (y/n): "
        read update_portal

        if [ "$update_portal" = "y" ] || [ "$update_portal" = "Y" ]; then
            cd "$portal_folder"
            git pull
        fi
    else
        git clone https://github.com/markm-io/SecureHST_Superset_Repo.git "$portal_folder"
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
WEBDRIVER_BASEURL_USER_FRIENDLY="http://superset_app:8088/"

# SMTP Configuration
SMTP_MAIL_FROM=
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASSWORD=
EOF
        echo "Enter the name of the business (no special characters): "
        read business_name

        secret_key=$(openssl rand -base64 42)
        portal_password=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 32)
        sudo sed -i "s/^APP_NAME=.*/APP_NAME=${business_name}/" "$env_file"
        sudo sed -i "s/^LOGO_RIGHT_TEXT=.*/LOGO_RIGHT_TEXT=${business_name}/" "$env_file"
        sudo sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${secret_key}/" "$env_file"
        sudo sed -i "s/^DATABASE_PASSWORD=.*/DATABASE_PASSWORD=${portal_password}/" "$env_file"
        sudo sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${portal_password}/" "$env_file"

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
            sudo tee -a "$env_file" <<EOF
SMTP_HOST=$smtp_host
SMTP_MAIL_FROM=$smtp_mail_from
SMTP_USER=$smtp_user
SMTP_PASSWORD=$smtp_password
SMTP_PORT=$smtp_port
EOF
        fi

        echo "Would you like to use a custom URL for the Portal (e.g., https://portal.example.com)? (y/n): "
        read use_custom_url
        if [ "$use_custom_url" = "y" ] || [ "$use_custom_url" = "Y" ]; then
            echo "Enter the custom domain URL: "
            read custom_url
            if [[ "$custom_url" != https://* ]]; then
                custom_url="https://${custom_url}"
            fi
            sudo sed -i "s|^WEBDRIVER_BASEURL_USER_FRIENDLY=.*|WEBDRIVER_BASEURL_USER_FRIENDLY=${custom_url}|" "$env_file"
        fi
    fi
fi

echo "Script execution completed."