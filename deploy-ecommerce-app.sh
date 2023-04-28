#!/bin/bash

#
# This scripts automates the deployment of e-commmerce application
# Author:
# Email

################################
# Print a given message in color
# Arguments:
# 	Color. e.g. green, red
################################
function print_color(){

	case $1 in
		"green") COLOR="\033[0;32m" ;;
		"red") COLOR="\033[0;31m" ;;
		"*") COLOR="\033[0m" ;;
	esac

	echo -e "${COLOR} $2 ${NC}"
}


################################
# Check the status of a given service.
# Arguments:
# 	Service. e.g. httpd, firewalld
################################
function check_service_status(){
	is_service_active=$(systemctl is-active $1)
	
	if [[ $is_service_active = "active" ]]
	then
		print_color "green" "$1 Service is active"
	else
		print_color "red" "$1 Service is not active"
		exit 1
	fi
}


################################
# Check the port is enabled in a firewall rule
# Arguments:
# 	Port. e.g. 3306, 80
################################
function check_firewalld_rule_configuration(){
	firewalld_ports=$(sudo firewall-cmd --permanent --zone=public | grep ports)

	if [[ firewalld_ports = *$1* ]]
	then
		print_color "green" "Port $1 configured"
	else
		print_color "red" "Port $1 not configured"
		exit 1
	fi
}

# -------------------- Database Configuration ----------------

# Install FirewallD
print_color "green" "Installing firewalld..."
sudo yum install -y firewalld
sudo service firewalld start
sudo systemctl enable firewalld

check_service_status firewalld

# Install MariaDB
print_color "green" "Installing MariaDB..."
sudo yum install -y mariadb-server
sudo service mariadb start
sudo systemctl enable mariadb

check_service_status mariadb

# Add FirewallD rules for Database
print_color "green" "Adding Firewall rules for Database..."
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload

check_firewalld_rule_configuration 3306

# Configure Database
print_color "green" "Configuring Database..."
cat > configure-db.sql <<-EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
# CREATE USER 'ecomuser'@'3.75.142.91' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
# GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'3.75.142.91';
FLUSH PRIVILEGES;
EOF

# Load inventory data in Database
print_color "green" "Loading inventory data in Database..."
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");

EOF

sudo mysql < db-load-script.sql

# check if table were created as expected
mysql_db_results=$(sudo mysql -e "use ecomdb; select * from products;")

if [[ $mysql_db_results = *Laptop* ]]
then
	print_color "green" "Inventory data loaded"
else
	print_color "red" "Inventory data not loaded"
	exit 1
fi


# -------------------- Web Server Configuration ----------------

# Install Apache web server and PHP - required packages
print_color "green" "Configuring Web Server..."
sudo yum install -y httpd php php-mysql

# Configure Firewall rules for web server
print_color "green" "Configuring FirewallD rules for web server..."
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload

check_firewalld_rule_configuration 80

# Change DirectoryIndex index.html to DirectoryIndex index.php to make the php page the default page
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

# Start and enable httpd service
print_color "green" "Starting web server..."
sudo service httpd start
sudo systemctl enable httpd

check_service_status httpd

# Install Git and download the source code repository
print_color "green" "Cloning GIT Repo..."
sudo yum install -y git
git clone https://github.com/alainpedro123/ecommerce-app.git

# Replace datbase IP 
sudo sed -i 's/172.20.1.101/DATABASE_SERVER_IP/g' /var/www/html/index.php


print_color "green" "Deployment complete"
 


