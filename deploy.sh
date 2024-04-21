#!/bin/bash

# Function to execute a task and introduce a delay
perform_task() {
    echo "==> Performing task: $1"
    sleep 1
}

#Update Linux
sudo apt upgrade -y


# Add Ondřej Surý's PPA for PHP
perform_task "Adding Ondřej Surý's PPA for PHP"
sudo add-apt-repository -y ppa:ondrej/php

# Update package index
perform_task "Updating package index"
sudo apt update

# Install Expect
sudo apt-get install expect -y

# Install Apache
perform_task "Installing Apache"
sudo apt install -y apache2

# Start Apache
perform_task "Starting Apache"
sudo systemctl start apache2

# Enable Apache to start on boot
perform_task "Enabling Apache to start on boot"
sudo systemctl enable apache2

# Install MySQL Server
perform_task "Installing MySQL Server"
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password '
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password '
sudo apt-get -y install mysql-server

# Secure MySQL installation
perform_task "Securing MySQL installation"
expect <<EOF
spawn sudo mysql_secure_installation

expect "Would you like to setup VALIDATE PASSWORD component?"
send "y\r"
expect {
    "Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG" {
        send "1\r"
        exp_continue
    }
    "Remove anonymous users?" {
        send "y\r"
        exp_continue
    }
    "Disallow root login remotely?" {
        send "n\r"
        exp_continue
    }
    "Remove test database and access to it?" {
        send "y\r"
        exp_continue
    }
    "Reload privilege tables now?" {
        send "y\r"
        exp_continue
    }
}
EOF

# Install PHP and necessary modules
perform_task "Installing PHP and necessary modules"
sudo apt install -y php libapache2-mod-php php-mysql php8.2 php8.2-curl php8.2-dom php8.2-xml php8.2-mysql php8.2-sqlite3

# Set Default php8.2
perform_task "Setting php8.2 as default"
sudo update-alternatives --set php /usr/bin/php8.2
sudo a2enmod php8.2

# Restart Apache to apply PHP changes
perform_task "Restarting Apache to apply PHP changes"
sudo systemctl restart apache2

# LAMP stack deployment complete
echo "==> LAMP deployment complete."

# Remove existing Laravel directory if it exists
perform_task "Removing existing Laravel directory"
sudo rm -rf /var/www/html/laravel

# Clone the Laravel repository from GitHub
perform_task "Cloning Laravel repository from GitHub"
sudo git clone https://github.com/laravel/laravel /var/www/html/laravel

# Navigate to the Laravel directory
perform_task "Navigating to the Laravel directory"
cd /var/www/html/laravel

# Install Composer (Dependency Manager for PHP)
perform_task "Installing Composer"
sudo apt install -y composer


# Upgrade Composer to version 2
perform_task "Upgrading Composer to version 2"

# Download Composer installer
perform_task "Downloading Composer installer"
sudo php -r "copy('https://getcomposer.org/installer', 'composer-config.php');"

# Verify the integrity of the downloaded installer
perform_task "Verifying installer integrity"
if sudo php -r "exit(hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') ? 0 : 1;"; then
    echo "Installer verified"
else
    echo "Installer corrupt"
    sudo rm composer-config.php
    exit 1
fi

# Run Composer installer
perform_task "Running Composer installer"
sudo php composer-config.php --install-dir=/usr/bin --filename=composer

# Clean up downloaded files
perform_task "Cleaning up downloaded files"
sudo rm composer-config.php

echo "==> Composer upgrade to version 2 completed successfully."

# Use Composer to install dependencies
perform_task "Installing Laravel dependencies using Composer"
export COMPOSER_ALLOW_SUPERUSER=1
sudo -S <<< "yes" composer install

# Set permissions for Laravel directories
perform_task "Setting permissions for Laravel directories"
sudo chown -R www-data:www-data /var/www/html/laravel/storage
sudo chown -R www-data:www-data /var/www/html/laravel/bootstrap/cache
sudo chmod -R 775 /var/www/html/laravel/storage/logs

# Set up Apache Virtual Host configuration for Laravel
perform_task "Setting up Apache Virtual Host configuration for Laravel"
sudo cp /var/www/html/laravel/.env.example /var/www/html/laravel/.env

# Set correct permissions for .env file
perform_task "Setting correct permissions for .env file"
sudo chown www-data:www-data .env
sudo chmod 640 .env

# Create Apache Virtual Host configuration file
perform_task "Creating Apache Virtual Host configuration file"
sudo tee /etc/apache2/sites-available/php.conf >/dev/null <<EOF
<VirtualHost *:80>
    ServerName 192.168.50.101

    ServerAlias *
    DocumentRoot /var/www/html/laravel/public

    <Directory /var/www/html/laravel>
        AllowOverride All
    </Directory>
</VirtualHost>
EOF

# Generate application key
perform_task "Generating application key"
sudo php artisan key:generate

# Run Laravel migration to create MySQL database tables
perform_task "Running Laravel migration to create MySQL database tables"
sudo php artisan migrate --force

# Set permissions for Laravel database
perform_task "Setting permissions for Laravel Database"
sudo chown -R www-data:www-data /var/www/html/laravel/database/
sudo chmod -R 775 /var/www/html/laravel/database/

echo "==> Laravel setup complete."

# Check if the default Apache site is enabled
if sudo a2query -s 000-default.conf; then
    perform_task "Default Apache site already disabled"
else
    # Disable the default Apache site
    perform_task "Disabling the default Apache site"
    sudo a2dissite 000-default.conf
fi

# Check if the Laravel site is enabled
if sudo a2query -s php.conf; then
    perform_task "Laravel site already enabled"
else
    # Enable the Laravel site
    perform_task "Enabling the Laravel site"
    sudo a2ensite php.conf
fi

# Reload Apache to apply changes
perform_task "Reloading Apache to apply changes"
sudo systemctl reload apache2

echo "==>Laravel application deployment using PHP is now complete!"
