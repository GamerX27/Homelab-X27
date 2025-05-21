#!/bin/bash

# Script to set up automated distro updates and optional reboot on large updates
# Requires sudo permissions

# Prompt the user for scheduling preferences
echo "Set up your automated distro update and reboot schedule."
echo "Enter the day of the week to run the update (1 for Monday to 7 for Sunday):"
read -r day

# Map day input to cron-compatible values (1 = Monday, so we need 7 for Sunday)
if [ "$day" -eq 7 ]; then
    cron_day=6
else
    cron_day=$((day - 1))
fi

echo "Enter the time for the update (in 24-hour format, e.g., 03:30 for 3:30 AM):"
read -r update_time

update_hour=${update_time%:*}
update_minute=${update_time#*:}

echo "Enter the time to check for a reboot (in 24-hour format, e.g., 06:00 for 6:00 AM):"
read -r reboot_time

reboot_hour=${reboot_time%:*}
reboot_minute=${reboot_time#*:}

# Paths
update_script="/usr/local/bin/distro-update.sh"
reboot_script="/usr/local/bin/reboot-check.sh"
log_file="/var/log/distro_update.log"
reboot_marker="/tmp/reboot_required"

# Create the update script
cat <<EOL | sudo tee $update_script
#!/bin/bash

LOG_FILE="$log_file"
REBOOT_MARKER="$reboot_marker"

# Update the system
echo "Starting system update at \$(date)" > "\$LOG_FILE"
if sudo apt update && sudo apt -y full-upgrade >> "\$LOG_FILE" 2>&1; then
    echo "Update completed successfully at \$(date)" >> "\$LOG_FILE"
else
    echo "Update failed at \$(date)" >> "\$LOG_FILE"
    exit 1
fi

# Clean up unnecessary dependencies and cached files
echo "Cleaning up unused dependencies and cache at \$(date)" >> "\$LOG_FILE"
sudo apt -y autoremove >> "\$LOG_FILE" 2>&1
sudo apt -y autoclean >> "\$LOG_FILE" 2>&1
echo "Cleanup completed at \$(date)" >> "\$LOG_FILE"

# Check if a reboot is required
if grep -q "linux-image" "\$LOG_FILE" || grep -q "requires a restart" "\$LOG_FILE"; then
    touch "\$REBOOT_MARKER"
    echo "Reboot required due to major update at \$(date)" >> "\$LOG_FILE"
else
    echo "No reboot required at \$(date)" >> "\$LOG_FILE"
fi
EOL

# Make the update script executable
sudo chmod +x $update_script

# Create the reboot script
cat <<EOL | sudo tee $reboot_script
#!/bin/bash

REBOOT_MARKER="$reboot_marker"

# Check if reboot is required
if [ -f "\$REBOOT_MARKER" ]; then
    echo "Rebooting system at \$(date)" >> "$log_file"
    rm -f "\$REBOOT_MARKER"
    sudo reboot
fi
EOL

# Make the reboot script executable
sudo chmod +x $reboot_script

# Set up crontab entries
sudo crontab -l > /tmp/current_cron || echo "" > /tmp/current_cron
echo "$update_minute $update_hour * * $cron_day $update_script" >> /tmp/current_cron
echo "$reboot_minute $reboot_hour * * $cron_day $reboot_script" >> /tmp/current_cron
sudo crontab /tmp/current_cron
rm /tmp/current_cron

# Confirm success
echo "Automated update and reboot schedule has been set up."
echo "Update will run at $update_hour:$update_minute on day $day."
echo "Reboot check will run at $reboot_hour:$reboot_minute on day $day."
