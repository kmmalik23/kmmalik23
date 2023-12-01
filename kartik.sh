#!/bin/bash
# Name: Kartik
# Student number: 200511821

# These are the commands i am gonna use
#   There is some brief description on the commands
# Also used echo intead of regular for variance and ease of work.
# Function to run commands on the target machine using SSH
run_remote_command() {
    # Use SSH to run the provided command on the target machine
    echo "Running remote command on $1: $2"
    ssh -o "StrictHostKeyChecking=no" remote_admin@$1 "$2"
}

# Function to verify if a command executed successfully
verify_command_success() {
    # Check the exit code of the last command
    if [ $? -eq 0 ]; then
        echo "SUCCESS: $1"
    else
        echo "ERROR: $1"
        exit 1
    fi
}

# Function to check if a package is installed and install if necessary
install_package() {
    package_name=$1
    # Use dpkg to check if the package is already installed, if not, install it
    echo "Checking and installing $package_name on $target_ip"
    run_remote_command "$target_ip" "dpkg -l | grep -E '^ii' | grep -q $package_name || sudo apt-get install -y $package_name"
}

# Target1 configuration
target1_ip="172.16.1.10"

run_remote_command "$target1_ip" "sudo hostnamectl set-hostname loghost"
verify_command_success "Setting hostname on target1"

run_remote_command "$target1_ip" "sudo ip addr add 192.168.1.3/24 dev eth0"
verify_command_success "Setting IP address on target1"

run_remote_command "$target1_ip" "echo '192.168.1.4 webhost' | sudo tee -a /etc/hosts"
verify_command_success "Adding webhost entry to /etc/hosts on target1"

# Install and configure UFW on target1
install_package "ufw"
run_remote_command "$target1_ip" "sudo ufw allow from 172.16.1.0/24 to any port 514/udp"
verify_command_success "Configuring UFW on target1"

# Configure rsyslog to listen for UDP connections on target1
run_remote_command "$target1_ip" "sudo sed -i '/imudp/s/^#//g' /etc/rsyslog.conf"
run_remote_command "$target1_ip" "sudo sed -i '/UDPServerRun/s/^#//g' /etc/rsyslog.conf"
verify_command_success "Configuring rsyslog on target1"

run_remote_command "$target1_ip" "sudo systemctl restart rsyslog"
verify_command_success "Restarting rsyslog service on target1"

# Target2 configuration
target2_ip="172.16.1.11"

run_remote_command "$target2_ip" "sudo hostnamectl set-hostname webhost"
verify_command_success "Setting hostname on target2"

run_remote_command "$target2_ip" "sudo ip addr add 192.168.1.4/24 dev eth0"
verify_command_success "Setting IP address on target2"

run_remote_command "$target2_ip" "echo '192.168.1.3 loghost' | sudo tee -a /etc/hosts"
verify_command_success "Adding loghost entry to /etc/hosts on target2"

# Install and configure UFW on target2
install_package "ufw"
run_remote_command "$target2_ip" "sudo ufw allow 80/tcp"
verify_command_success "Configuring UFW on target2"

# Install Apache2 on target2
install_package "apache2"

# Configure rsyslog on webhost to send logs to loghost on target2
run_remote_command "$target2_ip" "echo '. @loghost' | sudo tee -a /etc/rsyslog.conf"
verify_command_success "Configuring rsyslog on target2"

run_remote_command "$target2_ip" "sudo systemctl restart rsyslog"
verify_command_success "Restarting rsyslog service on target2"

# Update /etc/hosts on NMS with target1 and target2 information
echo "Updating /etc/hosts on NMS with target1 and target2 information"
echo "192.168.1.3 loghost" | sudo tee -a /etc/hosts
echo "192.168.1.4 webhost" | sudo tee -a /etc/hosts

# Verify Apache and syslog configurations
echo "Verifying Apache configuration on webhost..."
apache_response=$(curl -s http://webhost)
if [[ "$apache_response" =~ "Apache2 Ubuntu Default Page" ]]; then
    echo "SUCCESS: Apache configuration on webhost is correct."
else
    echo "ERROR: Apache configuration on webhost is not correct."
fi

echo "Verifying syslog configuration on loghost..."
loghost_logs=$(ssh remote_admin@loghost grep webhost /var/log/syslog)
if [[ -n "$loghost_logs" ]]; then
    echo "SUCCESS: Syslog configuration on loghost is correct."
else
    echo "ERROR: Syslog configuration on loghost is not correct."
fi

# Final message
echo "Configuration update succeeded!"
