#!/bin/bash

# Enhanced Docker entrypoint for OpenConnect with SSL management

# Create necessary directories
mkdir -p /etc/ocserv/logs
mkdir -p /etc/ocserv/certs
mkdir -p /etc/ocserv/config-per-user
mkdir -p /etc/ocserv/config-per-group

# Copy default config files if they don't exist
if [[ ! -e /etc/ocserv/ocserv.conf ]]; then
	echo "$(date) [info] No ocserv.conf found, copying default configuration"
	rsync -vzr --ignore-existing "/etc/default/ocserv/" "/etc/ocserv/"
fi

if [[ ! -e /etc/ocserv/connect.sh ]]; then
	echo "$(date) [info] Copying default connect.sh script"
	cp "/etc/default/ocserv/connect.sh" "/etc/ocserv/"
fi

if [[ ! -e /etc/ocserv/disconnect.sh ]]; then
	echo "$(date) [info] Copying default disconnect.sh script"
	cp "/etc/default/ocserv/disconnect.sh" "/etc/ocserv/"
fi

# Make scripts executable
chmod a+x /etc/ocserv/*.sh

##### Verify Variables #####
export POWER_USER=$(echo "${POWER_USER}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${POWER_USER}" ]]; then
	echo "$(date) [info] POWER_USER defined as '${POWER_USER}'"
else
	echo "$(date) [warn] POWER_USER not defined,(via -e POWER_USER), defaulting to 'no'"
	export POWER_USER="no"
fi

export LISTEN_PORT=$(echo "${LISTEN_PORT}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${LISTEN_PORT}" ]]; then
	echo "$(date) [info] LISTEN_PORT defined as '${LISTEN_PORT}'"
	echo "$(date) [warn] Make sure you changed the port in container settings to expose the port you selected!"
else
	echo "$(date) [warn] LISTEN_PORT not defined,(via -e LISTEN_PORT), defaulting to '4443'"
	export LISTEN_PORT="4443"
fi

export TUNNEL_MODE=$(echo "${TUNNEL_MODE}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${TUNNEL_MODE}" ]]; then
	echo "$(date) [info] TUNNEL_MODE defined as '${TUNNEL_MODE}'"
else
	echo "$(date) [warn] TUNNEL_MODE not defined,(via -e TUNNEL_MODE), defaulting to 'all'"
	export TUNNEL_MODE="all"
fi

if [[ ${TUNNEL_MODE} == "all" ]]; then
	echo "$(date) [info] Tunnel mode is all, ignoring TUNNEL_ROUTES. If you want to define specific routes, change TUNNEL_MODE to split-include"
elif [[ ${TUNNEL_MODE} == "split-include" ]]; then
	export TUNNEL_ROUTES=$(echo "${TUNNEL_ROUTES}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${TUNNEL_ROUTES}" ]]; then
		echo "$(date) [info] TUNNEL_ROUTES defined as '${TUNNEL_ROUTES}'"
	else
		echo "$(date) [err] TUNNEL_ROUTES not defined (via -e TUNNEL_ROUTES), but TUNNEL_MODE is defined as split-include"
	fi
fi

export DNS_SERVERS=$(echo "${DNS_SERVERS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${DNS_SERVERS}" ]]; then
		echo "$(date) [info] DNS_SERVERS defined as '${DNS_SERVERS}'"
	else
		echo "$(date) [warn] DNS_SERVERS not defined (via -e DNS_SERVERS), defaulting to Google and FreeDNS name servers"
		export DNS_SERVERS="8.8.8.8,37.235.1.174,8.8.4.4,37.235.1.177"
fi

export SPLIT_DNS_DOMAINS=$(echo "${SPLIT_DNS_DOMAINS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${SPLIT_DNS_DOMAINS}" ]]; then
	echo "$(date) [info] SPLIT_DNS_DOMAINS defined as '${SPLIT_DNS_DOMAINS}'"
fi

# SSL Management Variables
export SSL_DOMAIN=$(echo "${SSL_DOMAIN}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${SSL_DOMAIN}" ]]; then
	echo "$(date) [info] SSL_DOMAIN defined as '${SSL_DOMAIN}'"
fi

export ACME_DNS_PROVIDER=$(echo "${ACME_DNS_PROVIDER}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${ACME_DNS_PROVIDER}" ]]; then
	echo "$(date) [info] ACME_DNS_PROVIDER defined as '${ACME_DNS_PROVIDER}'"
fi

export ACME_STANDALONE=$(echo "${ACME_STANDALONE}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ "${ACME_STANDALONE}" == "true" ]]; then
	echo "$(date) [info] ACME_STANDALONE mode enabled"
fi

export DISABLE_SSL_AUTO=$(echo "${DISABLE_SSL_AUTO}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ "${DISABLE_SSL_AUTO}" == "true" ]]; then
	echo "$(date) [info] SSL automatic management disabled"
fi

##### Process Variables #####
if [ ${LISTEN_PORT} != "4443" ]; then
	echo "$(date) [info] Modifying the listening port"
	if [[ ${POWER_USER} == "yes" ]]; then
		echo "$(date) [warn] Power user! Listening ports are not being written to ocserv.conf, you must manually modify the conf file yourself!"
	else
		sed -i "s/^tcp-port.*/tcp-port = ${LISTEN_PORT}/" /etc/ocserv/ocserv.conf
		sed -i "s/^udp-port.*/udp-port = ${LISTEN_PORT}/" /etc/ocserv/ocserv.conf
	fi
fi

if [[ ${TUNNEL_MODE} == "all" ]]; then
	echo "$(date) [info] Tunneling all traffic through VPN"
	if [[ ${POWER_USER} == "yes" ]]; then
		echo "$(date) [warn] Power user! Routes are not being written to ocserv.conf, you must manually modify the conf file yourself!"
	else
		sed -i '/^route=/d' /etc/ocserv/ocserv.conf
	fi
elif [[ ${TUNNEL_MODE} == "split-include" ]]; then
	echo "$(date) [info] Tunneling routes $TUNNEL_ROUTES through VPN"
	if [[ ${POWER_USER} == "yes" ]]; then
		echo "$(date) [warn] Power user! Routes are not being written to ocserv.conf, you must manually modify the conf file yourself!"
	else
		sed -i '/^route=/d' /etc/ocserv/ocserv.conf
		IFS=',' read -ra tunnel_route_list <<< "${TUNNEL_ROUTES}"
		for tunnel_route_item in "${tunnel_route_list[@]}"; do
			tunnel_route_item=$(echo "${tunnel_route_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
			IFS='/' read -ra ip_subnet_list <<< "${tunnel_route_item}"
			STRLENGTH=$(echo -n ${ip_subnet_list[1]} | wc -m)
			if [[ $STRLENGTH > "2" ]]; then
				echo "$(date) [info] Full subnet mask detected in route ${tunnel_route_item}"
				IP=$(sipcalc ${ip_subnet_list[0]} ${ip_subnet_list[1]} | awk '/Host address/ {print $4; exit}')
				NETMASK=$(sipcalc ${ip_subnet_list[0]} ${ip_subnet_list[1]} | awk '/Network mask/ {print $4; exit}')
			else
				echo "$(date) [info] CIDR subnet mask detected in route ${tunnel_route_item}"
				IP=$(ipcalc -b ${tunnel_route_item} | awk '/Address/ {print $2}')
				NETMASK=$(ipcalc -b ${tunnel_route_item} | awk '/Netmask/ {print $2}')
			fi
			TUNDUP=$(cat /etc/ocserv/ocserv.conf | grep "route=${IP}/${NETMASK}")
			if [[ -z "$TUNDUP" ]]; then
				echo "$(date) [info] Adding route=$IP/$NETMASK to ocserv.conf"
				echo "route=$IP/$NETMASK" >> /etc/ocserv/ocserv.conf
			fi
		done
	fi
fi

# Add DNS_SERVERS to ocserv conf
if [[ ${POWER_USER} == "yes" ]]; then
	echo "$(date) [warn] Power user! DNS servers are not being written to ocserv.conf, you must manually modify the conf file yourself!"
else
	sed -i '/^dns =/d' /etc/ocserv/ocserv.conf
	IFS=',' read -ra name_server_list <<< "${DNS_SERVERS}"
	for name_server_item in "${name_server_list[@]}"; do
		DNSDUP=$(cat /etc/ocserv/ocserv.conf | grep "dns = ${name_server_item}")
		if [[ -z "$DNSDUP" ]]; then
			name_server_item=$(echo "${name_server_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
			echo "$(date) [info] Adding dns = ${name_server_item} to ocserv.conf"
			echo "dns = ${name_server_item}" >> /etc/ocserv/ocserv.conf
		fi
	done
fi

# Process SPLIT_DNS env var
if [[ ! -z "${SPLIT_DNS_DOMAINS}" ]]; then
	if [[ ${POWER_USER} == "yes" ]]; then
		echo "$(date) [warn] Power user! Split-DNS domains are not being written to ocserv.conf, you must manually modify the conf file yourself!"
	else
		sed -i '/^split-dns =/d' /etc/ocserv/ocserv.conf
		IFS=',' read -ra split_domain_list <<< "${SPLIT_DNS_DOMAINS}"
		for split_domain_item in "${split_domain_list[@]}"; do
			DOMDUP=$(cat /etc/ocserv/ocserv.conf | grep "split-dns = ${split_domain_item}")
			if [[ -z "$DOMDUP" ]]; then
				split_domain_item=$(echo "${split_domain_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
				echo "$(date) [info] Adding split-dns = ${split_domain_item} to ocserv.conf"
				echo "split-dns = ${split_domain_item}" >> /etc/ocserv/ocserv.conf
			fi
		done
	fi
fi

##### SSL Certificate Management #####
if [[ "${DISABLE_SSL_AUTO}" != "true" ]]; then
	echo "$(date) [info] Starting SSL certificate management"
	
	# Check if we have existing certificates
	CERT_PATH=$(grep "^server-cert" /etc/ocserv/ocserv.conf | awk '{print $3}' || echo "/etc/ocserv/certs/server-cert.pem")
	
	if [[ ! -f "$CERT_PATH" ]]; then
		echo "$(date) [info] No existing certificate found, attempting to obtain SSL certificate"
		
		# Try to get SSL certificate first
		if /usr/local/bin/ssl-manager.sh check; then
			echo "$(date) [info] SSL certificate obtained successfully"
		else
			echo "$(date) [warn] Failed to obtain SSL certificate, generating self-signed certificate"
			/usr/local/bin/ssl-manager.sh self-signed
		fi
	else
		echo "$(date) [info] Checking existing SSL certificate"
		/usr/local/bin/ssl-manager.sh check
	fi
else
	echo "$(date) [info] SSL automatic management is disabled"
	
	# Check if certificates exist, if not create self-signed
	CERT_PATH=$(grep "^server-cert" /etc/ocserv/ocserv.conf | awk '{print $3}' || echo "/etc/ocserv/certs/server-cert.pem")
	if [[ ! -f "$CERT_PATH" ]]; then
		echo "$(date) [info] No certificates found, generating self-signed certificate"
		/usr/local/bin/ssl-manager.sh self-signed
	fi
fi

##### Start Cron for SSL Certificate Monitoring #####
if [[ "${DISABLE_SSL_AUTO}" != "true" ]]; then
	echo "$(date) [info] Starting cron for SSL certificate monitoring"
	crond -b -l 8
else
	echo "$(date) [info] SSL monitoring disabled, not starting cron"
fi

# Ensure the ocpasswd file exists
if [[ ! -f /etc/ocserv/ocpasswd ]]; then
	echo "$(date) [info] Creating empty ocpasswd file"
	touch /etc/ocserv/ocpasswd
	chmod 600 /etc/ocserv/ocpasswd
fi

# Open ipv4 ip forward
sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Set proper permissions
chmod -R 755 /etc/ocserv
chmod 600 /etc/ocserv/certs/* 2>/dev/null || true
chmod 644 /etc/ocserv/certs/*.pem 2>/dev/null || true

echo "$(date) [info] OpenConnect Server initialization completed"

# Run OpenConnect Server
exec "$@"