#!/bin/bash

# SSL Certificate Manager for OpenConnect Server
# This script manages SSL certificates using acme.sh with Let's Encrypt

OCSERV_CONF="/etc/ocserv/ocserv.conf"
LOG_FILE="/etc/ocserv/logs/ssl-manager.log"
ACME_HOME="/root/.acme.sh"
CERT_DIR="/etc/ocserv/certs"

# Create necessary directories
mkdir -p /etc/ocserv/logs
mkdir -p "$CERT_DIR"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SSL-MANAGER] $1" | tee -a "$LOG_FILE"
}

# Extract domain from ocserv.conf
get_domain_from_config() {
    if [[ -f "$OCSERV_CONF" ]]; then
        local domain=$(grep "^default-domain" "$OCSERV_CONF" | awk '{print $3}' | tr -d ' ')
        if [[ -z "$domain" ]]; then
            domain=$(grep "^#default-domain" "$OCSERV_CONF" | awk '{print $3}' | tr -d ' ')
        fi
        echo "$domain"
    fi
}

# Extract server certificate path from ocserv.conf
get_cert_path_from_config() {
    if [[ -f "$OCSERV_CONF" ]]; then
        local cert_path=$(grep "^server-cert" "$OCSERV_CONF" | awk '{print $3}' | tr -d ' ')
        if [[ -z "$cert_path" ]]; then
            cert_path=$(grep "^#server-cert" "$OCSERV_CONF" | awk '{print $3}' | tr -d ' ')
        fi
        echo "$cert_path"
    fi
}

# Get certificate expiration date
get_cert_expiration() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2
    fi
}

# Check if certificate expires within specified days
cert_expires_soon() {
    local cert_file="$1"
    local days_threshold="$2"
    
    if [[ ! -f "$cert_file" ]]; then
        return 0  # Certificate doesn't exist, needs renewal
    fi
    
    local expiry_date=$(get_cert_expiration "$cert_file")
    if [[ -z "$expiry_date" ]]; then
        return 0  # Can't read expiry date, assume needs renewal
    fi
    
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local threshold_epoch=$((current_epoch + (days_threshold * 24 * 3600)))
    
    if [[ $expiry_epoch -le $threshold_epoch ]]; then
        return 0  # Certificate expires soon
    else
        return 1  # Certificate is still valid
    fi
}

# Issue new certificate using acme.sh
issue_certificate() {
    local domain="$1"
    local webroot="${ACME_WEBROOT:-/etc/ocserv/webroot}"
    
    log_message "Attempting to issue certificate for domain: $domain"
    
    # Create webroot directory if it doesn't exist
    mkdir -p "$webroot"
    
    # Check if we should use DNS challenge or webroot
    if [[ -n "$ACME_DNS_PROVIDER" ]]; then
        log_message "Using DNS challenge with provider: $ACME_DNS_PROVIDER"
        acme.sh --issue --dns "$ACME_DNS_PROVIDER" -d "$domain" --log "$LOG_FILE"
    else
        log_message "Using webroot challenge: $webroot"
        # Start a temporary HTTP server for challenge if needed
        if [[ -n "$ACME_STANDALONE" ]]; then
            acme.sh --issue --standalone -d "$domain" --log "$LOG_FILE"
        else
            acme.sh --issue --webroot "$webroot" -d "$domain" --log "$LOG_FILE"
        fi
    fi
    
    return $?
}

# Install certificate to the correct location
install_certificate() {
    local domain="$1"
    local cert_path="$2"
    local key_path="${cert_path%/*}/server-key.pem"
    
    log_message "Installing certificate for $domain to $cert_path"
    
    # Extract directory from cert_path
    local cert_dir=$(dirname "$cert_path")
    mkdir -p "$cert_dir"
    
    # Install the certificate using acme.sh
    acme.sh --install-cert -d "$domain" \
        --cert-file "$cert_path" \
        --key-file "$key_path" \
        --fullchain-file "$cert_path" \
        --reloadcmd "killall -HUP ocserv 2>/dev/null || true" \
        --log "$LOG_FILE"
    
    if [[ $? -eq 0 ]]; then
        log_message "Certificate installed successfully"
        # Set proper permissions
        chmod 600 "$key_path" 2>/dev/null
        chmod 644 "$cert_path" 2>/dev/null
        return 0
    else
        log_message "Failed to install certificate"
        return 1
    fi
}

# Update ocserv.conf with new certificate paths
update_ocserv_config() {
    local cert_path="$1"
    local key_path="${cert_path%/*}/server-key.pem"
    
    log_message "Updating ocserv.conf with certificate paths"
    
    # Update server-cert line
    if grep -q "^server-cert" "$OCSERV_CONF"; then
        sed -i "s|^server-cert.*|server-cert = $cert_path|" "$OCSERV_CONF"
    else
        echo "server-cert = $cert_path" >> "$OCSERV_CONF"
    fi
    
    # Update server-key line
    if grep -q "^server-key" "$OCSERV_CONF"; then
        sed -i "s|^server-key.*|server-key = $key_path|" "$OCSERV_CONF"
    else
        echo "server-key = $key_path" >> "$OCSERV_CONF"
    fi
    
    log_message "Configuration updated"
}

# Main certificate management function
manage_certificate() {
    local force_renewal="$1"
    
    log_message "Starting certificate management check"
    
    # Get domain and certificate path from config
    local domain=$(get_domain_from_config)
    local cert_path=$(get_cert_path_from_config)
    
    # Use defaults if not found in config
    if [[ -z "$domain" ]]; then
        domain="${SSL_DOMAIN:-vpn.example.com}"
        log_message "Using default domain: $domain"
    else
        log_message "Found domain in config: $domain"
    fi
    
    if [[ -z "$cert_path" ]]; then
        cert_path="/etc/ocserv/certs/server-cert.pem"
        log_message "Using default certificate path: $cert_path"
    else
        log_message "Found certificate path in config: $cert_path"
    fi
    
    # Check if certificate needs renewal
    local needs_renewal=false
    
    if [[ "$force_renewal" == "force" ]]; then
        log_message "Force renewal requested"
        needs_renewal=true
    elif cert_expires_soon "$cert_path" 15; then
        local expiry_date=$(get_cert_expiration "$cert_path")
        log_message "Certificate expires soon: $expiry_date"
        needs_renewal=true
    else
        local expiry_date=$(get_cert_expiration "$cert_path")
        log_message "Certificate is valid until: $expiry_date"
    fi
    
    if [[ "$needs_renewal" == "true" ]]; then
        log_message "Certificate renewal needed"
        
        # Issue new certificate
        if issue_certificate "$domain"; then
            log_message "Certificate issued successfully"
            
            # Install certificate
            if install_certificate "$domain" "$cert_path"; then
                log_message "Certificate installation completed"
                
                # Update configuration
                update_ocserv_config "$cert_path"
                
                # Reload ocserv if it's running
                if pgrep ocserv > /dev/null; then
                    log_message "Reloading ocserv configuration"
                    killall -HUP ocserv 2>/dev/null || true
                fi
                
                log_message "Certificate management completed successfully"
            else
                log_message "Certificate installation failed"
                return 1
            fi
        else
            log_message "Certificate issuance failed"
            return 1
        fi
    else
        log_message "No certificate renewal needed"
    fi
    
    return 0
}

# Generate self-signed certificate as fallback
generate_self_signed() {
    local domain="$1"
    local cert_path="$2"
    local key_path="${cert_path%/*}/server-key.pem"
    local cert_dir=$(dirname "$cert_path")
    
    log_message "Generating self-signed certificate as fallback"
    
    mkdir -p "$cert_dir"
    
    # Generate private key
    openssl genrsa -out "$key_path" 2048 2>/dev/null
    
    # Generate certificate
    openssl req -new -x509 -key "$key_path" -out "$cert_path" -days 365 \
        -subj "/CN=$domain/O=OpenConnect-Server/C=US" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        chmod 600 "$key_path"
        chmod 644 "$cert_path"
        log_message "Self-signed certificate generated successfully"
        return 0
    else
        log_message "Failed to generate self-signed certificate"
        return 1
    fi
}

# Main execution
main() {
    local action="${1:-check}"
    
    case "$action" in
        "check")
            manage_certificate
            ;;
        "force")
            manage_certificate "force"
            ;;
        "self-signed")
            local domain=$(get_domain_from_config)
            local cert_path=$(get_cert_path_from_config)
            domain="${domain:-${SSL_DOMAIN:-vpn.example.com}}"
            cert_path="${cert_path:-/etc/ocserv/certs/server-cert.pem}"
            generate_self_signed "$domain" "$cert_path"
            ;;
        *)
            echo "Usage: $0 [check|force|self-signed]"
            echo "  check       - Check and renew certificates if needed (default)"
            echo "  force       - Force certificate renewal"
            echo "  self-signed - Generate self-signed certificate"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"