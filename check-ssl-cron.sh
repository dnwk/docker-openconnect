#!/bin/bash

# Cron script to periodically check SSL certificates
# This script is called by cron every 12 hours

LOG_FILE="/etc/ocserv/logs/ssl-check.log"

# Create log directory if it doesn't exist
mkdir -p /etc/ocserv/logs

# Log the start of the check
echo "$(date '+%Y-%m-%d %H:%M:%S') [CRON-CHECK] Starting periodic SSL certificate check" >> "$LOG_FILE"

# Run the SSL manager
/usr/local/bin/ssl-manager.sh check

# Log the completion
echo "$(date '+%Y-%m-%d %H:%M:%S') [CRON-CHECK] Periodic SSL certificate check completed" >> "$LOG_FILE"